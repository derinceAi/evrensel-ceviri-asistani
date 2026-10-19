/// Web gibi dart:io olmayan platformlar için boş uygulama.
class LinuxSesOkuyucu {
  static Future<bool> kullanilabilirMi() async => false;
  static Future<void> konus(String metin, String dilKisa) async {}
  static Future<void> durdur() async {}
}
