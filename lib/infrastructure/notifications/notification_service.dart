import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/models/user_settings.dart';
import '../../domain/services/reminder_planner.dart';

/// Thin adapter over flutter_local_notifications. All scheduling decisions are
/// made by [ReminderPlanner]; this class only talks to the OS.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelDefault = AndroidNotificationChannel(
    'hydration_reminders',
    'Water reminders',
    description: 'Reminders to drink water on your schedule',
    importance: Importance.high,
  );
  static const _channelSilent = AndroidNotificationChannel(
    'hydration_reminders_silent',
    'Water reminders (silent)',
    description: 'Reminders without sound, vibration only',
    importance: Importance.high,
    playSound: false,
    enableVibration: true,
  );

  /// iOS keeps at most 64 pending local notifications; leave headroom.
  static int get maxPending => Platform.isIOS ? 60 : 400;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await refreshTimeZone();

    const darwin = DarwinInitializationSettings(
      // Ask in context from the Home banner, not on first launch.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_water'),
          iOS: darwin,
        ),
      );
    } on PlatformException catch (e) {
      // The monochrome icon is added by tool/setup_platforms.dart. If that step
      // was skipped, fall back to the launcher icon rather than crash.
      debugPrint('Notification icon missing, using launcher icon: ${e.message}');
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
        ),
      );
    }

    final android = _android;
    if (android != null) {
      await android.createNotificationChannel(_channelDefault);
      await android.createNotificationChannel(_channelSilent);
    }
    _initialized = true;
  }

  /// Points the timezone package at the device's current zone. Call again on
  /// app resume so travel across zones keeps reminders at local times.
  Future<void> refreshTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      // flutter_timezone 4+ returns a TimezoneInfo, older versions a String.
      // Accept both so a package bump cannot break reminder scheduling.
      final Object result = await FlutterTimezone.getLocalTimezone();
      final name = result is String ? result : (result as dynamic).identifier as String;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('Could not resolve local time zone, using UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<bool> areEnabled() async {
    if (Platform.isAndroid) return await _android?.areNotificationsEnabled() ?? false;
    if (Platform.isIOS) return (await _ios?.checkPermissions())?.isEnabled ?? false;
    return false;
  }

  /// Shows the OS permission prompt. Returns whether notifications are allowed.
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) return await _android?.requestNotificationsPermission() ?? false;
    if (Platform.isIOS) {
      return await _ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return false;
  }

  Future<void> openSystemSettings() => _plugin.openAppNotificationSettings();

  /// Replaces every pending notification with [plan].
  Future<void> apply(ReminderPlan plan, ReminderSound sound) async {
    await _plugin.cancelAll();
    final details = _details(sound);
    for (final n in plan.notifications) {
      final copy = _copyFor(n);
      await _plugin.zonedSchedule(
        id: n.id,
        title: copy.$1,
        body: copy.$2,
        scheduledDate: tz.TZDateTime.from(n.firstFire, tz.local),
        notificationDetails: details,
        // Inexact keeps us clear of the SCHEDULE_EXACT_ALARM permission. Android
        // may shift delivery by a few minutes to save battery, fine for hydration.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'reminder:${n.reminderId}',
      );
    }
  }

  NotificationDetails _details(ReminderSound sound) {
    final channel = sound == ReminderSound.silent ? _channelSilent : _channelDefault;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: sound != ReminderSound.silent,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: sound != ReminderSound.silent,
      ),
    );
  }

  static const _reminderCopy = <(String, String)>[
    ('Time for some water', 'A glass now keeps your energy steady.'),
    ('Hydration check', 'Take a few sips and log it.'),
    ('Drink up', 'Your next glass is due. Tap to log it.'),
    ('Water break', 'Stretch, sip, and keep going.'),
  ];

  static const _followUpCopy = <(String, String)>[
    ('Missed your last glass?', 'Have a drink now and log it to stay on track.'),
    ('Still thirsty?', 'Nothing logged since your last reminder.'),
  ];

  /// Deterministic copy so the same slot always says the same thing.
  static (String, String) _copyFor(PlannedNotification n) {
    final list = n.kind == PlannedKind.reminder ? _reminderCopy : _followUpCopy;
    return list[(n.reminderId + n.slotWeekday) % list.length];
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
}
