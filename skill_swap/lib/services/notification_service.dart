import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'skill_swap_channel',
    'Pesan & Notifikasi Skill Swap',
    description: 'Notifikasi pesan chat dan aktivitas Skill Swap',
    importance: Importance.high,
  );

  static Future<void> init() async {
    await _localNotif
        .resolvePlatformSpecificImplementation
            <AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit),
    );

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Pesan masuk saat app sedang dibuka (foreground) -> tampilkan notifikasi manual
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotif.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon',
            ),
          ),
        );
      }
    });
  }

  /// Dipanggil setelah login berhasil, buat simpan token HP ke server
  static Future<void> registerToken(int userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiService.updateFcmToken(userId: userId, fcmToken: token);
      }
    } catch (e) {
      print("Gagal daftar token notifikasi: $e");
    }
  }
}