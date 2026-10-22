// Applies the native setup that scheduled notifications need, after
// `flutter create` has generated the android/ and ios/ folders.
//
// Run from the project root:
//   dart run tool/setup_platforms.dart
//
// Safe to run more than once: every step checks before it changes anything.
// ignore_for_file: avoid_print

import 'dart:io';

const _agpMin = '8.11.1';
const _gradleMin = '8.13';
const _desugar = 'com.android.tools:desugar_jdk_libs:2.1.4';
const _appLabel = 'Drink Water';

final _problems = <String>[];
final _done = <String>[];

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    _fail('Run this from the project folder (the one with pubspec.yaml).');
  }
  if (!Directory('android').existsSync() || !Directory('ios').existsSync()) {
    _fail('android/ or ios/ is missing. Run first:\n'
        '  flutter create --platforms=android,ios --org com.yourcompany .');
  }

  _patchManifest();
  _patchAppGradle();
  _patchSettingsGradle();
  _patchGradleWrapper();
  _writeNotificationIcon();
  _patchAppDelegate();

  print('');
  for (final d in _done) {
    print('  done  $d');
  }
  if (_problems.isEmpty) {
    print('\nPlatform setup complete.');
  } else {
    print('\nNeeds a manual look:');
    for (final p in _problems) {
      print('  !     $p');
    }
    exitCode = 1;
  }
}

// ---------------------------------------------------------------------------
// Android
// ---------------------------------------------------------------------------

void _patchManifest() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) return _problems.add('AndroidManifest.xml not found.');
  var xml = file.readAsStringSync();
  final original = xml;

  const permissions = [
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.VIBRATE',
  ];
  final missing = permissions.where((p) => !xml.contains(p)).toList();
  if (missing.isNotEmpty) {
    final lines = missing.map((p) => '    <uses-permission android:name="$p" />').join('\n');
    final appTag = xml.indexOf('<application');
    if (appTag < 0) return _problems.add('No <application> tag in AndroidManifest.xml.');
    xml = '${xml.substring(0, appTag)}${lines.trimLeft()}\n    ${xml.substring(appTag)}';
  }

  if (!xml.contains('ScheduledNotificationBootReceiver')) {
    const receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
''';
    final close = xml.lastIndexOf('</application>');
    if (close < 0) return _problems.add('No </application> tag in AndroidManifest.xml.');
    xml = '${xml.substring(0, close)}$receivers    ${xml.substring(close)}';
  }

  xml = xml.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="$_appLabel"');

  if (xml != original) {
    file.writeAsStringSync(xml);
    _done.add('AndroidManifest.xml: notification permissions, boot receivers, app name');
  } else {
    _done.add('AndroidManifest.xml already set up');
  }
}

void _patchAppGradle() {
  final kts = File('android/app/build.gradle.kts');
  if (!kts.existsSync()) {
    return _problems.add('android/app/build.gradle.kts not found. This script expects a Flutter 3.38+ '
        'project (Kotlin DSL). Add core library desugaring by hand: see README.');
  }
  var src = kts.readAsStringSync();
  final original = src;

  final compileOptions = RegExp(r'compileOptions\s*\{[^}]*\}');
  const newOptions = 'compileOptions {\n'
      '        isCoreLibraryDesugaringEnabled = true\n'
      '        sourceCompatibility = JavaVersion.VERSION_17\n'
      '        targetCompatibility = JavaVersion.VERSION_17\n'
      '    }';
  if (compileOptions.hasMatch(src)) {
    src = src.replaceFirst(compileOptions, newOptions);
  } else {
    final androidBlock = src.indexOf('android {');
    if (androidBlock < 0) return _problems.add('No android { } block in app/build.gradle.kts.');
    final insertAt = androidBlock + 'android {'.length;
    src = '${src.substring(0, insertAt)}\n    $newOptions\n${src.substring(insertAt)}';
  }

  src = src.replaceAll('JavaVersion.VERSION_11', 'JavaVersion.VERSION_17').replaceAll('JVM_11', 'JVM_17');
  src = src.replaceFirst(
    RegExp(r'compileSdk\s*=\s*flutter\.compileSdkVersion'),
    'compileSdk = maxOf(flutter.compileSdkVersion, 36)',
  );

  if (!src.contains('coreLibraryDesugaring(')) {
    src = '${src.trimRight()}\n\ndependencies {\n    coreLibraryDesugaring("$_desugar")\n}\n';
  }

  if (src != original) {
    kts.writeAsStringSync(src);
    _done.add('app/build.gradle.kts: desugaring, Java 17, compileSdk 36+');
  } else {
    _done.add('app/build.gradle.kts already set up');
  }
}

void _patchSettingsGradle() {
  final file = File('android/settings.gradle.kts');
  if (!file.existsSync()) return _problems.add('android/settings.gradle.kts not found.');
  final src = file.readAsStringSync();
  final re = RegExp(r'id\("com\.android\.application"\)\s+version\s+"([^"]+)"');
  final m = re.firstMatch(src);
  if (m == null) return _problems.add('Could not find the Android Gradle Plugin version in settings.gradle.kts.');
  if (_versionLess(m.group(1)!, _agpMin)) {
    file.writeAsStringSync(src.replaceFirst(re, 'id("com.android.application") version "$_agpMin"'));
    _done.add('Android Gradle Plugin ${m.group(1)} -> $_agpMin');
  } else {
    _done.add('Android Gradle Plugin ${m.group(1)} is new enough');
  }
}

void _patchGradleWrapper() {
  final file = File('android/gradle/wrapper/gradle-wrapper.properties');
  if (!file.existsSync()) return _problems.add('gradle-wrapper.properties not found.');
  final src = file.readAsStringSync();
  final re = RegExp(r'gradle-(\d+(?:\.\d+)+)-(all|bin)\.zip');
  final m = re.firstMatch(src);
  if (m == null) return _problems.add('Could not read the Gradle version in gradle-wrapper.properties.');
  if (_versionLess(m.group(1)!, _gradleMin)) {
    file.writeAsStringSync(src.replaceFirst(re, 'gradle-$_gradleMin-${m.group(2)}.zip'));
    _done.add('Gradle ${m.group(1)} -> $_gradleMin');
  } else {
    _done.add('Gradle ${m.group(1)} is new enough');
  }
}

void _writeNotificationIcon() {
  final file = File('android/app/src/main/res/drawable/ic_stat_water.xml');
  if (file.existsSync()) return _done.add('Notification icon already present');
  file
    ..createSync(recursive: true)
    ..writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<!-- Monochrome status-bar icon for reminders (Android tints it). -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,2C12,2 5,10.2 5,14.5C5,18.6 8.1,22 12,22C15.9,22 19,18.6 19,14.5C19,10.2 12,2 12,2Z" />
</vector>
''');
  _done.add('Notification icon ic_stat_water.xml');
}

// ---------------------------------------------------------------------------
// iOS
// ---------------------------------------------------------------------------

void _patchAppDelegate() {
  final file = File('ios/Runner/AppDelegate.swift');
  if (!file.existsSync()) return _problems.add('ios/Runner/AppDelegate.swift not found.');
  var src = file.readAsStringSync();
  if (src.contains('UNUserNotificationCenter.current().delegate')) {
    return _done.add('AppDelegate.swift already set up');
  }

  if (!src.contains('import UserNotifications')) {
    src = src.replaceFirst('import Flutter', 'import Flutter\nimport UserNotifications');
  }
  const marker = 'return super.application(';
  final at = src.indexOf(marker);
  if (at < 0) {
    return _problems.add('Could not find "$marker" in AppDelegate.swift. Add this line inside '
        'didFinishLaunchingWithOptions:\n'
        '      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate');
  }
  final lineStart = src.lastIndexOf('\n', at) + 1;
  final indent = src.substring(lineStart, at);
  src = '${src.substring(0, lineStart)}'
      '${indent}UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate\n'
      '${src.substring(lineStart)}';
  file.writeAsStringSync(src);
  _done.add('AppDelegate.swift: foreground notification delegate');
}

// ---------------------------------------------------------------------------

bool _versionLess(String a, String b) {
  List<int> parse(String v) => v.split('.').map((p) => int.tryParse(p.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
  final pa = parse(a);
  final pb = parse(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y;
  }
  return false;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
