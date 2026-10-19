/// Web gibi dart:io olmayan platformlar için boş uygulama.
class GoogleSesTanima {
  static bool get anahtarVar => false;
  static Future<bool> kullanilabilirMi() async => false;
  static Future<String> dinleVeTani(String dilKodu) async => '';
  static Future<void> durdur() async {}
}
