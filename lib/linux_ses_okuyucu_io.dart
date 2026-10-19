import 'dart:io';

/// Linux için sistem TTS motorlarını (espeak-ng / espeak / spd-say) kullanan
/// sesli okuyucu. Kurulum: `sudo apt install espeak-ng` veya `speech-dispatcher`.
class LinuxSesOkuyucu {
  static Process? _aktifSurec;
  static String? _motor; // önbelleğe alınmış motor adı

  static Future<String?> _motorBul() async {
    if (_motor != null) return _motor;
    for (final aday in const ['espeak-ng', 'espeak', 'spd-say']) {
      try {
        final sonuc = await Process.run('which', [aday]);
        if (sonuc.exitCode == 0) {
          _motor = aday;
          return aday;
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<bool> kullanilabilirMi() async {
    if (!Platform.isLinux) return false;
    return await _motorBul() != null;
  }

  /// Metni okur ve okuma bitene kadar bekler (ping-pong akışı için gerekli).
  static Future<void> konus(String metin, String dilKisa) async {
    final motor = await _motorBul();
    if (motor == null || metin.trim().isEmpty) return;
    await durdur();

    final List<String> argumanlar = motor == 'spd-say'
        ? ['-w', '-l', dilKisa, '-r', '-10', metin]
        : ['-v', dilKisa, '-s', '150', metin];

    _aktifSurec = await Process.start(motor, argumanlar);
    await _aktifSurec!.exitCode;
    _aktifSurec = null;
  }

  static Future<void> durdur() async {
    _aktifSurec?.kill();
    _aktifSurec = null;
    if (_motor == 'spd-say') {
      try {
        await Process.run('spd-say', ['-C']);
      } catch (_) {}
    }
  }
}
