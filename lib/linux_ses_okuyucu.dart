// Platforma göre doğru uygulamayı seçer (Web'de dart:io yoktur).
export 'linux_ses_okuyucu_stub.dart'
    if (dart.library.io) 'linux_ses_okuyucu_io.dart';
