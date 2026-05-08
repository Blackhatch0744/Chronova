import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  static Future<String?> getDeviceToken() async {
    await FirebaseMessaging.instance.requestPermission();
    return FirebaseMessaging.instance.getToken();
  }

  static void listenForTokenRefresh(void Function(String token) onRefresh) {
    FirebaseMessaging.instance.onTokenRefresh.listen(onRefresh);
  }
}