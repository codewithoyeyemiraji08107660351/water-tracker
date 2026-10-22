import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'infrastructure/notifications/notification_service.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final (AppDatabase, SharedPreferences) storage;
  try {
    storage = await (AppDatabase.open(), SharedPreferences.getInstance()).wait;
  } catch (e, st) {
    debugPrint('Startup failed: $e\n$st');
    runApp(const StartupErrorApp());
    return;
  }
  final (database, prefs) = storage;

  final notifications = NotificationService();
  try {
    await notifications.init();
  } catch (e, st) {
    // The app still works for tracking; reminders resume after the next successful init.
    debugPrint('Notification init failed: $e\n$st');
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const WaterTrackerApp(),
    ),
  );
}
