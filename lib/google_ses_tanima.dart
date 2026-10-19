// Platforma göre doğru uygulamayı seçer (Web'de dart:io yoktur).
export 'google_ses_tanima_stub.dart'
    if (dart.library.io) 'google_ses_tanima_io.dart';
