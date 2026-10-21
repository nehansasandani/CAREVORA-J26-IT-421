import 'url_launcher_stub.dart'
    if (dart.library.html) 'url_launcher_web.dart';

class UrlLauncherService {
  UrlLauncherService._();

  static void launchTel(String phoneNumber) {
    launchTelUrl(phoneNumber);
  }

  static void launchWhatsApp(String phoneNumber, [String? message]) {
    launchWhatsAppUrl(phoneNumber, message);
  }
}
