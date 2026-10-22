import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'ui/shell/home_shell.dart';

class WaterTrackerApp extends StatelessWidget {
  const WaterTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drink Water Reminder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeShell(),
    );
  }
}

/// Shown only if local storage cannot be opened at launch.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'The app could not open its storage. Restart the app. If this keeps happening, '
              'free up some space on your phone and try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
