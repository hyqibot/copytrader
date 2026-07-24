import 'dart:math' as math;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 系统通知栏（本地通知）。依赖 App 保持 WebSocket 在线；进程被杀后无法收到。
class TradeNotifications {
  TradeNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static var _ready = false;
  static var _id = 1000;

  static const _channelId = 'trade_exec';
  static const _channelName = '跟单执行通知';

  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: '策略开始执行时的实时提醒',
        importance: Importance.high,
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _ready = true;
  }

  static Future<void> showTradeAlert({
    required String title,
    required String body,
  }) async {
    if (!_ready) {
      try {
        await init();
      } catch (_) {
        return;
      }
    }
    _id = (_id + 1) % 100000;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '策略开始执行时的实时提醒',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
        ticker: title,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: body.length > 40 ? '${body.substring(0, 40)}…' : body,
      ),
    );
    await _plugin.show(
      _id,
      title,
      body.substring(0, math.min(body.length, 240)),
      details,
    );
  }
}
