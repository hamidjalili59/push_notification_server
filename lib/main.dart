import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

int notifid = 0;
WebSocketChannel? channel;
int reconnectAttempt = 0; // شمارش تعداد تلاش‌های ناموفق
Timer? reconnectTimer; // تایمر برای تلاش‌های مجدد

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    Timer.periodic(const Duration(minutes: 5), (timer) {
      service.setForegroundNotificationInfo(
        title: "Flutter Background Service",
        content: "Listening for notifications...",
      );
    });
  }

  connectToWebSocket(); // تلاش برای اتصال به وب‌سوکت

  // تایمر برای ارسال درخواست keep-alive به سرور
  Timer.periodic(const Duration(minutes: 2), (timer) async {
    if (channel == null) {
      print('WebSocket is null, trying to reconnect...');
      startReconnectProcess(); // تلاش برای اتصال مجدد در صورت نبودن کانال
    } else {
      try {
        channel!.sink.add('ping'); // ارسال پیام keep-alive به سرور
      } catch (e) {
        print('Error sending ping: $e');
        startReconnectProcess(); // تلاش برای اتصال مجدد در صورت بروز خطا
      }
    }
  });
}

// تابع اتصال به وب‌سوکت
void connectToWebSocket() {
  try {
    channel = WebSocketChannel.connect(
      Uri.parse('wss://wstest.liara.run/ws'),
    );

    channel!.stream.listen(
      (message) {
        showNotification("Hamid You Have New Messages", message);
      },
      onDone: () {
        print('Connection closed! Reconnecting...');
        startReconnectProcess(); // تلاش برای اتصال مجدد در صورت بسته شدن اتصال
      },
      onError: (error) {
        print('Error: $error');
        startReconnectProcess(); // تلاش برای اتصال مجدد در صورت بروز خطا
      },
    );
    print('Connected to WebSocket');
    reconnectAttempt =
        0; // در صورت موفقیت‌آمیز بودن اتصال، تعداد تلاش‌ها را صفر می‌کنیم
    reconnectTimer?.cancel(); // تایمر اتصال مجدد را متوقف می‌کنیم
  } catch (e) {
    print('Failed to connect: $e');
    startReconnectProcess(); // تلاش برای اتصال مجدد در صورت بروز خطا
  }
}

// تابع شروع فرآیند اتصال مجدد با backoff
void startReconnectProcess() {
  if (reconnectTimer != null && reconnectTimer!.isActive) {
    return; // اگر تایمر اتصال مجدد فعال است، منتظر بمانیم و تلاش جدید نکنیم
  }

  reconnectAttempt++;
  int delayInSeconds = (2 ^ reconnectAttempt)
      .clamp(2, 64); // افزایش تصاعدی فاصله بین تلاش‌ها (تا حداکثر 64 ثانیه)

  print('Reconnecting in $delayInSeconds seconds...');

  reconnectTimer = Timer(Duration(seconds: delayInSeconds), () {
    connectToWebSocket(); // تلاش برای اتصال مجدد
  });
}

// کلاس MyApp
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("WebSocket Push Notification"),
        ),
        body: const Center(
          child: Text("Listening for push notifications..."),
        ),
      ),
    );
  }
}

// مقداردهی سرویس پس‌زمینه
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

// تابع مربوط به iOS (اجرا در پس‌زمینه)
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

// تنظیمات نمایش نوتیفیکیشن
void showNotification(String title, String body) async {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'my_notification_channel9010',
    'Push Notifications',
    channelDescription:
        'This channel is used for push notifications from the server',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  notifid++;
  await flutterLocalNotificationsPlugin.show(
    notifid,
    title,
    body,
    platformChannelSpecifics,
    payload: 'item x',
  );
}
