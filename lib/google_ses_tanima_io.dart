import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:record/record.dart';

/// Google Cloud Speech-to-Text (REST v1) tabanlı ses tanıma.
///  - Linux  : birincil motor. Kayıt `rec` (sox) veya `arecord` ile.
///  - Windows: yerel ses tanıma sorun çıkarırsa YEDEK motor. Kayıt `record` paketi ile.
///
/// API anahtarı koda GÖMÜLMEZ, derlemede verilir:
///   flutter run --dart-define=GOOGLE_STT_API_KEY=xxxx
class GoogleSesTanima {
  static const String _apiKey =
      String.fromEnvironment('GOOGLE_STT_API_KEY', defaultValue: '');
  static const int _ornekleme = 16000;
  static const int _maksSure = 15; // saniye

  // Windows sessizlik algılama ayarları (dBFS)
  static const double _konusmaEsigi = -38;
  static const Duration _sessizlikSuresi = Duration(milliseconds: 1500);
  static const Duration _konusmaBeklemeSuresi = Duration(seconds: 8);

  static Process? _kayitSureci;
  static AudioRecorder? _kaydedici;
  static Completer<void>? _windowsKayitBitti;
  static bool _iptal = false;
  static String? _linuxKayitci;

  static bool get anahtarVar => _apiKey.isNotEmpty;

  static Future<String?> _linuxKayitciBul() async {
    if (_linuxKayitci != null) return _linuxKayitci;
    for (final aday in const ['rec', 'arecord']) {
      try {
        final r = await Process.run('which', [aday]);
        if (r.exitCode == 0) return _linuxKayitci = aday;
      } catch (_) {}
    }
    return null;
  }

  static Future<bool> kullanilabilirMi() async {
    if (!anahtarVar) return false;
    if (Platform.isLinux) return await _linuxKayitciBul() != null;
    if (Platform.isWindows) {
      try {
        return await AudioRecorder().hasPermission();
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Konuşmayı kaydeder, Google'a gönderir ve metni döndürür.
  /// Konuşma yoksa / iptal edildiyse boş metin döner.
  static Future<String> dinleVeTani(String dilKodu) async {
    if (!anahtarVar) return '';
    _iptal = false;

    final dosya = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}ceviri_kayit_${DateTime.now().millisecondsSinceEpoch}.wav');

    try {
      if (Platform.isWindows) {
        await _windowsKaydet(dosya.path);
      } else if (Platform.isLinux) {
        await _linuxKaydet(dosya.path);
      } else {
        return '';
      }

      if (_iptal || !await dosya.exists()) return '';
      final bytes = await dosya.readAsBytes();
      if (bytes.length < 8000) return ''; // ~0.25 sn'den kısa: boş say

      return await _googleaGonder(bytes, dilKodu);
    } finally {
      try {
        if (await dosya.exists()) await dosya.delete();
      } catch (_) {}
    }
  }

  static Future<void> _linuxKaydet(String yol) async {
    final kayitci = await _linuxKayitciBul();
    if (kayitci == null) return;
    final List<String> argumanlar = kayitci == 'rec'
        ? [
            '-q', '-r', '$_ornekleme', '-c', '1', '-b', '16', yol,
            // Ses başlayınca kayda başla, 1.5 sn sessizlikte dur
            'silence', '1', '0.1', '2%', '1', '1.5', '2%',
            'trim', '0', '$_maksSure',
          ]
        : [
            '-q', '-f', 'S16_LE', '-r', '$_ornekleme', '-c', '1',
            '-d', '$_maksSure', yol,
          ];
    _kayitSureci = await Process.start(kayitci, argumanlar);
    await _kayitSureci!.exitCode;
    _kayitSureci = null;
  }

  /// Windows: genlik (amplitude) takibiyle basit konuşma algılama.
  /// Konuşma başladıktan sonra 1.5 sn sessizlik olursa kayıt durur.
  static Future<void> _windowsKaydet(String yol) async {
    final kaydedici = AudioRecorder();
    _kaydedici = kaydedici;
    final bitti = Completer<void>();
    _windowsKayitBitti = bitti;

    await kaydedici.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: _ornekleme,
        numChannels: 1,
      ),
      path: yol,
    );

    final baslangic = DateTime.now();
    DateTime? sonKonusma;
    bool konusmaBasladi = false;

    final abonelik = kaydedici
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen((genlik) {
      final simdi = DateTime.now();
      if (genlik.current > _konusmaEsigi) {
        konusmaBasladi = true;
        sonKonusma = simdi;
      }
      final gecen = simdi.difference(baslangic);
      final bool sessizlikteBitti = konusmaBasladi &&
          sonKonusma != null &&
          simdi.difference(sonKonusma!) > _sessizlikSuresi;
      final bool hicKonusulmadi =
          !konusmaBasladi && gecen > _konusmaBeklemeSuresi;
      if (sessizlikteBitti ||
          hicKonusulmadi ||
          gecen.inSeconds >= _maksSure) {
        if (hicKonusulmadi) _iptal = true; // boş kaydı göndermeye gerek yok
        if (!bitti.isCompleted) bitti.complete();
      }
    });

    await bitti.future;
    await abonelik.cancel();
    try {
      await kaydedici.stop();
    } catch (_) {}
    await kaydedici.dispose();
    _kaydedici = null;
    _windowsKayitBitti = null;
  }

  static Future<String> _googleaGonder(List<int> wav, String dilKodu) async {
    final istemci = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.https(
          'speech.googleapis.com', '/v1/speech:recognize', {'key': _apiKey});
      final istek = await istemci.postUrl(uri);
      istek.headers.contentType = ContentType.json;
      istek.write(jsonEncode({
        'config': {
          'encoding': 'LINEAR16',
          'sampleRateHertz': _ornekleme,
          'languageCode': dilKodu,
          'enableAutomaticPunctuation': true,
        },
        'audio': {'content': base64Encode(wav)},
      }));
      final yanit = await istek.close();
      final govde = await yanit.transform(utf8.decoder).join();

      if (yanit.statusCode != 200) {
        throw HttpException('Google STT hata ${yanit.statusCode}: $govde');
      }
      final json = jsonDecode(govde) as Map<String, dynamic>;
      final sonuclar = json['results'] as List<dynamic>? ?? const [];
      return sonuclar
          .map((s) => (s['alternatives'] as List).first['transcript'] as String)
          .join(' ')
          .trim();
    } finally {
      istemci.close(force: true);
    }
  }

  static Future<void> durdur() async {
    _iptal = true;
    _kayitSureci?.kill();
    _kayitSureci = null;
    final bitti = _windowsKayitBitti;
    if (bitti != null && !bitti.isCompleted) bitti.complete();
    if (_kaydedici != null && bitti == null) {
      try {
        await _kaydedici!.stop();
      } catch (_) {}
    }
  }
}
