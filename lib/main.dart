import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:permission_handler/permission_handler.dart';
import 'platform_destegi.dart';
import 'linux_ses_okuyucu.dart';
import 'google_ses_tanima.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (PlatformDestegi.reklamDestekli) {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('AdMob başlatılamadı: $e');
    }
  }
  final prefs = await SharedPreferences.getInstance();
  final String? kullaniciTipi = prefs.getString('kullanici_tipi');

  runApp(EvrenselCeviriApp(initialKullaniciTipi: kullaniciTipi));
}

/// Tıklama hissiyatı veren fiziksel görünümlü animasyonlu buton bileşeni
class AnimatedPressableButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isFullWidth;

  const AnimatedPressableButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isFullWidth = false,
  });

  @override
  State<AnimatedPressableButton> createState() =>
      _AnimatedPressableButtonState();
}

class _AnimatedPressableButtonState extends State<AnimatedPressableButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onPressed();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: widget.isFullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color,
                Color.lerp(widget.color, Colors.black, 0.22)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize:
                widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EvrenselCeviriApp extends StatefulWidget {
  final String? initialKullaniciTipi;

  const EvrenselCeviriApp({super.key, this.initialKullaniciTipi});

  @override
  State<EvrenselCeviriApp> createState() => _EvrenselCeviriAppState();
}

class _EvrenselCeviriAppState extends State<EvrenselCeviriApp> {
  String? _kullaniciTipi;

  @override
  void initState() {
    super.initState();
    _kullaniciTipi = widget.initialKullaniciTipi;
  }

  void _onPlanSelected(String tip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kullanici_tipi', tip);
    setState(() {
      _kullaniciTipi = tip;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evrensel Sesli Çeviri Asistanı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E88E5),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: _kullaniciTipi == null
          ? OnboardingScreen(onPlanSelected: _onPlanSelected)
          : AnaCeviriEkrani(
              kullaniciTipi: _kullaniciTipi!,
              onPlanChanged: _onPlanSelected,
            ),
    );
  }
}

/// ADIM 2.1: ONBOARDING VE FREEMIUM MİMARİ EKRANI
class OnboardingScreen extends StatefulWidget {
  final ValueChanged<String> onPlanSelected;

  const OnboardingScreen({super.key, required this.onPlanSelected});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isProcessingPurchase = false;

  bool get _isMobileStoreSupported => PlatformDestegi.magazaDestekli;

  @override
  void initState() {
    super.initState();
    if (_isMobileStoreSupported) {
      try {
        final Stream<List<PurchaseDetails>> purchaseUpdated =
            InAppPurchase.instance.purchaseStream;
        _subscription = purchaseUpdated.listen(
          (purchaseDetailsList) {
            for (final purchaseDetails in purchaseDetailsList) {
              if (purchaseDetails.status == PurchaseStatus.purchased ||
                  purchaseDetails.status == PurchaseStatus.restored) {
                widget.onPlanSelected('premium');
              }
              if (purchaseDetails.pendingCompletePurchase) {
                InAppPurchase.instance.completePurchase(purchaseDetails);
              }
            }
          },
          onError: (_) {},
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handlePremiumPurchase() async {
    setState(() => _isProcessingPurchase = true);
    if (_isMobileStoreSupported) {
      try {
        final InAppPurchase iap = InAppPurchase.instance;
        final bool available = await iap.isAvailable();
        if (available) {
          const Set<String> kIds = <String>{'premium_unlimited_plan'};
          final ProductDetailsResponse response =
              await iap.queryProductDetails(kIds);
          if (response.productDetails.isNotEmpty) {
            final PurchaseParam purchaseParam =
                PurchaseParam(productDetails: response.productDetails.first);
            await iap.buyNonConsumable(purchaseParam: purchaseParam);
            setState(() => _isProcessingPurchase = false);
            return;
          }
        }
      } catch (_) {
        // Mağaza yapılandırılmamışsa veya emülatördeyse simülasyon akışına geç
      }
    }
    setState(() => _isProcessingPurchase = false);
    widget.onPlanSelected('premium');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.blueAccent.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.translate_rounded,
                  size: 72,
                  color: Colors.lightBlueAccent,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Evrensel Sesli Çeviri Asistanı',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Otonom sıra yönetimli (Ping-Pong), fiziksel USB tuş ve Akıllı Saat destekli kesintisiz sesli çeviri deneyimine hoş geldiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              AnimatedPressableButton(
                label: 'Ücretsiz Kullan (Reklamlı)',
                icon: Icons.play_circle_outline_rounded,
                color: const Color(0xFF3B82F6),
                isFullWidth: true,
                onPressed: () => widget.onPlanSelected('reklamli'),
              ),
              const SizedBox(height: 18),
              _isProcessingPurchase
                  ? const CircularProgressIndicator()
                  : AnimatedPressableButton(
                      label: 'Premium Satın Al (Reklamsız)',
                      icon: Icons.workspace_premium_rounded,
                      color: const Color(0xFFD97706),
                      isFullWidth: true,
                      onPressed: _handlePremiumPurchase,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ADIM 2.2, 2.3, 2.4: ANA ÇEVİRİ EKRANI, ÇİFT TETİKLEYİCİ VE OTONOM MOTOR
class AnaCeviriEkrani extends StatefulWidget {
  final String kullaniciTipi;
  final ValueChanged<String> onPlanChanged;

  const AnaCeviriEkrani({
    super.key,
    required this.kullaniciTipi,
    required this.onPlanChanged,
  });

  @override
  State<AnaCeviriEkrani> createState() => _AnaCeviriEkraniState();
}

class _AnaCeviriEkraniState extends State<AnaCeviriEkrani> {
  // Dil Listesi ve Eşleştirmeleri
  static const Map<String, Map<String, String>> _supportedLanguages = {
    'tr-TR': {'name': 'Türkçe (tr-TR)', 'short': 'tr'},
    'en-US': {'name': 'İngilizce (en-US)', 'short': 'en'},
    'ru-RU': {'name': 'Rusça (ru-RU)', 'short': 'ru'},
    'de-DE': {'name': 'Almanca (de-DE)', 'short': 'de'},
    'ar-SA': {'name': 'Arapça (ar-SA)', 'short': 'ar'},
    'fr-FR': {'name': 'Fransızca (fr-FR)', 'short': 'fr'},
  };

  String _person1Lang = 'tr-TR';
  String _person2Lang = 'en-US';

  // Otonom Ping-Pong Durum Değişkenleri (Adım 2.4)
  bool isConversationActive = false;
  bool isPerson1Turn = true;
  bool isSpeaking = false;
  bool hasFinalResult = false;

  String _durumMetni = 'Bekleniyor...';
  String _dinlenenMetin = '';
  String _cevrilenMetin = '';

  // Motor Nesneleri
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final GoogleTranslator _translator = GoogleTranslator();
  final FlutterTts _flutterTts = FlutterTts();
  bool _speechInitialized = false;
  bool _retryScheduled = false;

  // Google STT yedeği (Linux'ta birincil, Windows'ta yerel motor arızasında)
  bool _googleYedekModu = false;
  bool _googleZorla = false; // kullanıcı ayarı (kalıcı)
  static const String _googleZorlaAnahtari = 'google_stt_zorla';
  int _ardisikHata = 0;
  static const int _yedekHataEsigi = 3;
  bool get _googleKullan =>
      PlatformDestegi.isLinux || _googleYedekModu || _googleZorla;

  // Odak ve Kanal
  final FocusNode _keyboardFocusNode = FocusNode();
  static const MethodChannel _saatChannel =
      MethodChannel('com.evrensel.ceviri_asistani/saat');

  // AdMob Banner
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _initEngines();
    _setupWearOsChannel();
    if (widget.kullaniciTipi == 'reklamli') {
      _loadBannerAd();
    }
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _bannerAd?.dispose();
    _sttDurdur();
    _ttsDurdur();
    super.dispose();
  }

  /// Platform desteklemiyorsa sessizce geçen güvenli durdurma çağrıları
  Future<void> _ttsDurdur() async {
    if (PlatformDestegi.isLinux) {
      await LinuxSesOkuyucu.durdur();
      return;
    }
    if (!PlatformDestegi.sesliOkumaDestekli) return;
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  Future<void> _sttDurdur() async {
    if (_googleKullan) {
      await GoogleSesTanima.durdur();
      if (PlatformDestegi.isLinux) return;
    }
    if (!PlatformDestegi.sesTanimaDestekli) return;
    try {
      await _speechToText.stop();
    } catch (_) {}
  }

  Future<bool> _sttBaslat() async {
    if (_googleKullan) {
      return GoogleSesTanima.kullanilabilirMi();
    }
    if (!PlatformDestegi.sesTanimaDestekli) return false;
    bool basarili = false;
    try {
      basarili = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
    } catch (e) {
      debugPrint('Ses tanıma başlatılamadı: $e');
    }
    if (!basarili && PlatformDestegi.googleYedekKullanilabilir) {
      _googleYedegeGec('Windows ses tanıma başlatılamadı');
      return GoogleSesTanima.kullanilabilirMi();
    }
    return basarili;
  }

  /// Windows yerel motorundan Google Cloud STT'ye geçer.
  void _googleYedegeGec(String sebep) {
    if (_googleYedekModu) return;
    debugPrint('Google STT yedeğine geçiliyor: $sebep');
    _googleYedekModu = true;
    _ardisikHata = 0;
    try {
      _speechToText.cancel();
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('$sebep → Google ses tanıma yedeğine geçildi'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Ayarlardan "Google ses tanımayı zorla" anahtarını değiştirir.
  Future<void> _googleZorlaDegistir() async {
    HapticFeedback.mediumImpact();
    final bool yeniDeger = !_googleZorla;
    await _stopConversation();
    try {
      _speechToText.cancel();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_googleZorlaAnahtari, yeniDeger);

    setState(() {
      _googleZorla = yeniDeger;
      if (!yeniDeger) _googleYedekModu = false; // yerel motoru tekrar dene
      _ardisikHata = 0;
    });
    _speechInitialized = await _sttBaslat();

    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(yeniDeger
            ? 'Google ses tanıma zorunlu olarak kullanılacak'
            : 'Windows yerel ses tanıması kullanılacak (Google yedekte)'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _initEngines() async {
    if (PlatformDestegi.googleYedekKullanilabilir) {
      final prefs = await SharedPreferences.getInstance();
      _googleZorla = prefs.getBool(_googleZorlaAnahtari) ?? false;
    }
    if (PlatformDestegi.izinYoneticisiDestekli) {
      try {
        await Permission.microphone.request();
        if (PlatformDestegi.isIOS) {
          await Permission.speech.request();
        }
      } catch (e) {
        debugPrint('İzin isteği başarısız: $e');
      }
    }

    if (PlatformDestegi.sesliOkumaDestekli) {
      try {
        await _flutterTts.awaitSpeakCompletion(true);
      } catch (e) {
        debugPrint('TTS başlatılamadı: $e');
      }
    }

    _speechInitialized = await _sttBaslat();
    if (mounted) {
      setState(() {
        if (!PlatformDestegi.sesTanimaDestekli) {
          _durumMetni =
              '${PlatformDestegi.platformAdi} üzerinde sesli çeviri desteklenmiyor';
        }
      });
    }
  }

  void _loadBannerAd() {
    if (!PlatformDestegi.reklamDestekli) return;
    _bannerAd = BannerAd(
      adUnitId: PlatformDestegi.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() => _isBannerLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
        },
      ),
    )..load();
  }

  void _setupWearOsChannel() {
    if (!PlatformDestegi.saatKanaliDestekli) return;
    _saatChannel.setMethodCallHandler((MethodCall call) async {
      final String message =
          call.arguments is String ? call.arguments as String : call.method;
      _handleIncomingWearMessage(message);
    });
  }

  void _handleIncomingWearMessage(String path) {
    if (path == '/komut/kisi1') {
      _startPerson1();
    } else if (path == '/komut/kisi2') {
      _startPerson2();
    } else if (path == '/komut/durdur') {
      _stopConversation();
    } else if (path.startsWith('/dil/kisi1/')) {
      final String langCode = path.replaceFirst('/dil/kisi1/', '').trim();
      final String? normalized = _normalizeLangCode(langCode);
      if (normalized != null) {
        setState(() {
          _person1Lang = normalized;
        });
      }
    } else if (path.startsWith('/dil/kisi2/')) {
      final String langCode = path.replaceFirst('/dil/kisi2/', '').trim();
      final String? normalized = _normalizeLangCode(langCode);
      if (normalized != null) {
        setState(() {
          _person2Lang = normalized;
        });
      }
    }
  }

  String? _normalizeLangCode(String code) {
    if (_supportedLanguages.containsKey(code)) return code;
    for (final entry in _supportedLanguages.entries) {
      if (entry.value['short'] == code.toLowerCase()) {
        return entry.key;
      }
    }
    return null;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f13) {
        _startPerson1();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.f14) {
        _startPerson2();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.f15) {
        _stopConversation();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _startPerson1() async {
    await _ttsDurdur();
    await _sttDurdur();
    setState(() {
      isConversationActive = true;
      isPerson1Turn = true;
      isSpeaking = false;
      hasFinalResult = false;
    });
    await _startListening();
  }

  Future<void> _startPerson2() async {
    await _ttsDurdur();
    await _sttDurdur();
    setState(() {
      isConversationActive = true;
      isPerson1Turn = false;
      isSpeaking = false;
      hasFinalResult = false;
    });
    await _startListening();
  }

  Future<void> _stopConversation() async {
    setState(() {
      isConversationActive = false;
      isSpeaking = false;
      hasFinalResult = false;
      _durumMetni = 'Bekleniyor...';
      _dinlenenMetin = '';
      _cevrilenMetin = '';
    });
    await _sttDurdur();
    await _ttsDurdur();
  }

  Future<void> _startListening() async {
    if (!isConversationActive || isSpeaking) return;

    if (!PlatformDestegi.sesTanimaDestekli) {
      setState(() {
        isConversationActive = false;
        _durumMetni = PlatformDestegi.isLinux
            ? 'Google STT API anahtarı tanımlı değil (GOOGLE_STT_API_KEY)'
            : '${PlatformDestegi.platformAdi} üzerinde ses tanıma desteklenmiyor';
      });
      return;
    }

    if (!_speechInitialized) {
      _speechInitialized = await _sttBaslat();
    }

    if (!_speechInitialized) {
      setState(() {
        _durumMetni = PlatformDestegi.isLinux
            ? 'Kayıt aracı bulunamadı (sudo apt install sox)'
            : 'Mikrofon başlatılamadı (İzinleri kontrol edin)';
      });
      return;
    }

    final String activeLocale = isPerson1Turn ? _person1Lang : _person2Lang;
    final String activePersonLabel = isPerson1Turn ? '1. Kişi' : '2. Kişi';

    setState(() {
      hasFinalResult = false;
      _durumMetni = '$activePersonLabel Dinleniyor...';
    });

    if (_googleKullan) {
      await _googleDinle(activeLocale);
      return;
    }

    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    try {
      await _speechToText.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: activeLocale,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: false,
        ),
        onResult: _onSpeechResult,
      );
    } catch (e) {
      debugPrint('Yerel dinleme hatası: $e');
      if (PlatformDestegi.googleYedekKullanilabilir) {
        _googleYedegeGec('Windows ses tanıma hata verdi');
        await _googleDinle(activeLocale);
      }
    }
  }

  /// Google Cloud STT: kaydet → tanı → çevir ve oku (otonom ping-pong)
  Future<void> _googleDinle(String locale) async {
    String metin = '';
    try {
      metin = await GoogleSesTanima.dinleVeTani(locale);
    } catch (e) {
      debugPrint('Google STT hatası: $e');
      if (mounted && isConversationActive) {
        setState(() => _durumMetni = 'Ses tanıma hatası, tekrar deneniyor...');
      }
      await Future.delayed(const Duration(seconds: 2));
    }

    if (!mounted || !isConversationActive || isSpeaking) return;

    if (metin.isEmpty) {
      hasFinalResult = false;
      _scheduleSilentRestart();
      return;
    }

    setState(() {
      _dinlenenMetin = metin;
      hasFinalResult = true;
    });
    await _translateAndSpeak(metin);
  }

  Future<void> _onSpeechResult(SpeechRecognitionResult result) async {
    if (!isConversationActive || isSpeaking) return;

    setState(() {
      _dinlenenMetin = result.recognizedWords;
    });

    if (result.finalResult) {
      final String spokenText = result.recognizedWords.trim();
      if (spokenText.isEmpty) {
        hasFinalResult = false;
        _scheduleSilentRestart();
        return;
      }

      hasFinalResult = true;
      _ardisikHata = 0;
      await _speechToText.stop();
      await _translateAndSpeak(spokenText);
    }
  }

  Future<void> _translateAndSpeak(String sourceText) async {
    if (!isConversationActive) return;

    final String fromShort =
        _supportedLanguages[isPerson1Turn ? _person1Lang : _person2Lang]!['short']!;
    final String toLangFull = isPerson1Turn ? _person2Lang : _person1Lang;
    final String toShort = _supportedLanguages[toLangFull]!['short']!;
    final String targetPersonLabel = isPerson1Turn ? '2. Kişiye' : '1. Kişiye';

    setState(() {
      _durumMetni = 'Çevriliyor...';
    });

    String translatedText = sourceText;
    try {
      final Translation translation = await _translator.translate(
        sourceText,
        from: fromShort,
        to: toShort,
      );
      translatedText = translation.text;
    } catch (e) {
      translatedText = sourceText;
    }

    if (!isConversationActive) return;

    setState(() {
      _cevrilenMetin = translatedText;
      isSpeaking = true;
      _durumMetni = '$targetPersonLabel Okunuyor...';
    });

    if (PlatformDestegi.isLinux) {
      try {
        await LinuxSesOkuyucu.konus(translatedText, toShort);
      } catch (e) {
        debugPrint('Linux sesli okuma hatası: $e');
      }
    } else if (PlatformDestegi.sesliOkumaDestekli) {
      try {
        await _flutterTts.setLanguage(toLangFull);
        await _flutterTts.setSpeechRate(0.5);
        await _flutterTts.setPitch(1.0);
        await _flutterTts.speak(translatedText);
      } catch (e) {
        debugPrint('Sesli okuma hatası: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      isSpeaking = false;
    });

    if (isConversationActive) {
      setState(() {
        isPerson1Turn = !isPerson1Turn;
        hasFinalResult = false;
      });
      await _startListening();
    }
  }

  void _onSpeechStatus(String status) {
    if (!isConversationActive || isSpeaking || _googleKullan) return;

    if ((status == 'done' || status == 'notListening') && !hasFinalResult) {
      _scheduleSilentRestart();
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!isConversationActive || isSpeaking || _googleKullan) return;

    // Sessizlik kaynaklı hatalar normaldir, arıza sayılmaz
    const sessizlikHatalari = {'error_no_match', 'error_speech_timeout'};
    if (PlatformDestegi.googleYedekKullanilabilir &&
        !sessizlikHatalari.contains(error.errorMsg)) {
      _ardisikHata++;
      if (_ardisikHata >= _yedekHataEsigi) {
        _googleYedegeGec('Windows ses tanıma art arda hata verdi');
      }
    }

    if (!hasFinalResult) {
      _scheduleSilentRestart();
    }
  }

  void _scheduleSilentRestart() {
    if (_retryScheduled || !isConversationActive || isSpeaking) return;
    _retryScheduled = true;

    Future.delayed(const Duration(milliseconds: 500), () async {
      _retryScheduled = false;
      if (mounted && isConversationActive && !isSpeaking && !hasFinalResult) {
        await _startListening();
      }
    });
  }

  Color _getStatusColor() {
    if (!isConversationActive) return const Color(0xFF334155);
    if (isSpeaking) return const Color(0xFF7C3AED);
    if (_durumMetni.contains('Çevriliyor')) return const Color(0xFFD97706);
    return isPerson1Turn ? const Color(0xFF0284C7) : const Color(0xFF059669);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Evrensel Sesli Çeviri Asistanı',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          actions: [
            if (PlatformDestegi.googleYedekKullanilabilir)
              Tooltip(
                message: _googleKullan
                    ? 'Google ses tanıma aktif (değiştirmek için tıkla)'
                    : 'Windows ses tanıma aktif (Google\'ı zorlamak için tıkla)',
                child: _GoogleZorlaDugmesi(
                  aktif: _googleZorla,
                  yedekAktif: _googleYedekModu && !_googleZorla,
                  onTap: _googleZorlaDegistir,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Chip(
                label: Text(
                  widget.kullaniciTipi == 'premium' ? 'PREMIUM' : 'ÜCRETSİZ',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: widget.kullaniciTipi == 'premium'
                    ? Colors.amber.withValues(alpha: 0.25)
                    : Colors.blueGrey.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildLanguageDropdownCard(
                              title: '1. Kişinin Dili',
                              value: _person1Lang,
                              accentColor: const Color(0xFF38BDF8),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _person1Lang = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildLanguageDropdownCard(
                              title: '2. Kişinin Dili',
                              value: _person2Lang,
                              accentColor: const Color(0xFF34D399),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _person2Lang = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor().withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              !isConversationActive
                                  ? Icons.mic_off_rounded
                                  : isSpeaking
                                      ? Icons.volume_up_rounded
                                      : Icons.mic_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _durumMetni,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (isConversationActive) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Aktif Sıra: ${isPerson1Turn ? "1. Kişi (${_supportedLanguages[_person1Lang]!['name']})" : "2. Kişi (${_supportedLanguages[_person2Lang]!['name']})"}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildTextDisplayCard(
                        title: 'Dinlenen Metin',
                        content: _dinlenenMetin.isEmpty
                            ? 'Henüz ses algılanmadı...'
                            : _dinlenenMetin,
                        icon: Icons.hearing_rounded,
                        accentColor: Colors.lightBlueAccent,
                      ),
                      const SizedBox(height: 14),
                      _buildTextDisplayCard(
                        title: 'Çevrilen Metin',
                        content: _cevrilenMetin.isEmpty
                            ? 'Çeviri bekleniyor...'
                            : _cevrilenMetin,
                        icon: Icons.translate_rounded,
                        accentColor: const Color(0xFF34D399),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedPressableButton(
                              label: '1. Kişi Başla',
                              icon: Icons.record_voice_over_rounded,
                              color: const Color(0xFF0284C7),
                              onPressed: _startPerson1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AnimatedPressableButton(
                              label: '2. Kişi Başla',
                              icon: Icons.voice_chat_rounded,
                              color: const Color(0xFF059669),
                              onPressed: _startPerson2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedPressableButton(
                        label: 'Durdur / Sıfırla',
                        icon: Icons.stop_circle_rounded,
                        color: const Color(0xFFDC2626),
                        isFullWidth: true,
                        onPressed: _stopConversation,
                      ),
                    ],
                  ),
                ),
              ),
              Visibility(
                visible: widget.kullaniciTipi == 'reklamli',
                replacement: const SizedBox.shrink(),
                child: Container(
                  width: double.infinity,
                  height: 60,
                  color: const Color(0xFF090D16),
                  alignment: Alignment.center,
                  child: _isBannerLoaded && _bannerAd != null
                      ? SizedBox(
                          width: _bannerAd!.size.width.toDouble(),
                          height: _bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        )
                      : const Text(
                          'Reklam Alanı (AdMob Test Banner)',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageDropdownCard({
    required String title,
    required String value,
    required Color accentColor,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              items: _supportedLanguages.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value['name']!,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextDisplayCard({
    required String title,
    required String content,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// AppBar'daki "Google ses tanımayı zorla" anahtarı.
/// Basınca küçülür, durum değişince renk ve ikon animasyonla geçer.
class _GoogleZorlaDugmesi extends StatefulWidget {
  final bool aktif; // kullanıcı zorladı
  final bool yedekAktif; // otomatik yedeğe geçildi
  final VoidCallback onTap;

  const _GoogleZorlaDugmesi({
    required this.aktif,
    required this.yedekAktif,
    required this.onTap,
  });

  @override
  State<_GoogleZorlaDugmesi> createState() => _GoogleZorlaDugmesiState();
}

class _GoogleZorlaDugmesiState extends State<_GoogleZorlaDugmesi> {
  bool _basili = false;

  @override
  Widget build(BuildContext context) {
    final Color renk = widget.aktif
        ? const Color(0xFF22C55E)
        : widget.yedekAktif
            ? const Color(0xFFF59E0B)
            : const Color(0xFF64748B);
    final String etiket = widget.aktif
        ? 'GOOGLE'
        : widget.yedekAktif
            ? 'YEDEK'
            : 'YEREL';

    return GestureDetector(
      onTapDown: (_) => setState(() => _basili = true),
      onTapUp: (_) {
        setState(() => _basili = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _basili = false),
      child: AnimatedScale(
        scale: _basili ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: renk.withValues(alpha: _basili ? 0.35 : 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: renk, width: 1.4),
            boxShadow: _basili
                ? []
                : [
                    BoxShadow(
                      color: renk.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    RotationTransition(turns: anim, child: child),
                child: Icon(
                  widget.aktif ? Icons.cloud_done_rounded : Icons.mic_rounded,
                  key: ValueKey(etiket),
                  color: renk,
                  size: 18,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                etiket,
                style: TextStyle(
                  color: renk,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



