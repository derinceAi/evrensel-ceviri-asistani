import 'package:flutter/foundation.dart';
import 'google_ses_tanima.dart';

/// Çoklu platform güvenlik/yetenek kontrolü.
/// Android, iOS, Web, Windows, macOS ve Linux için hangi eklentinin
/// güvenle çağrılabileceğini tek noktadan belirler.
class PlatformDestegi {
  PlatformDestegi._();

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  static bool get isMobile => isAndroid || isIOS;

  /// AdMob ve uygulama içi satın alma yalnızca mobil mağazalarda çalışır.
  static bool get reklamDestekli => isMobile;
  static bool get magazaDestekli => isMobile;

  /// permission_handler: Android/iOS (Windows'ta kısıtlı, macOS/Linux yok).
  static bool get izinYoneticisiDestekli => isMobile;

  /// speech_to_text: Android, iOS, macOS, Web, Windows.
  /// Linux: Google Cloud STT (GOOGLE_STT_API_KEY dart-define ile verilmeli).
  static bool get sesTanimaDestekli => !isLinux || GoogleSesTanima.anahtarVar;

  /// Windows'ta yerel ses tanıma arızalanırsa Google STT yedeği kullanılabilir mi?
  static bool get googleYedekKullanilabilir =>
      isWindows && GoogleSesTanima.anahtarVar;

  /// flutter_tts: Android, iOS, macOS, Web, Windows.
  /// Linux: espeak-ng / spd-say sistem motoru.
  static bool get sesliOkumaDestekli => true;

  /// Wear OS saat kanalı yalnızca Android'de anlamlıdır.
  static bool get saatKanaliDestekli => isAndroid;

  static String get platformAdi {
    if (kIsWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isMacOS) return 'macOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    return 'Bilinmeyen';
  }
}
