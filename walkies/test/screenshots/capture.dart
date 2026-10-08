// Renders each main screen with sample data and writes phone-sized PNGs
// to docs/screenshots/. Not part of the normal test run:
//
//   flutter test test/screenshots/capture.dart
//
// Images can't be fetched in tests, so content without a cover shows the
// app's generated artwork (as it would in the app before images are added).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/main.dart';
import 'package:walkies/screens/app_lock_settings_screen.dart';
import 'package:walkies/screens/community/post_screen.dart';
import 'package:walkies/screens/education/article_screen.dart';
import 'package:walkies/screens/education/video_screen.dart';
import 'package:walkies/screens/goal_management_screen.dart';
import 'package:walkies/screens/login_screen.dart';
import 'package:walkies/screens/settings_screen.dart';
import 'package:walkies/theme/app_theme.dart';

import 'fakes.dart';
import 'fonts.dart';

const outputDir = String.fromEnvironment('OUT', defaultValue: 'docs/screenshots');

/// Writes every "golden" instead of comparing it.
class _ScreenshotWriter extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    await update(golden, imageBytes);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final file = File('$outputDir/${golden.path}');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(imageBytes);
  }
}

Future<void> _shot(WidgetTester tester, String name, Widget home) async {
  tester.view.physicalSize = const Size(786, 1704); // 393 x 852 at 2x
  tester.view.devicePixelRatio = 2;
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: home,
  ));
  await _settle(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$name.png'));
}

/// pumpAndSettle never settles with spinners on screen, so pump a while
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Tests draw shadows as solid blocks by default; render them properly,
/// restoring the default before the test ends (the framework checks it).
void shotTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

void main() {
  setUpAll(() async {
    goldenFileComparator = _ScreenshotWriter();
    await loadAppFonts();
  });

  setUp(() {
    final today = DateTime.now();
    String key(int daysAgo) {
      final d = today.subtract(Duration(days: daysAgo));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    SharedPreferences.setMockInitialValues({
      // Goal met on each of the last four days
      'streak_days_met_v1':
          '{"${key(1)}":true,"${key(2)}":true,"${key(3)}":true,"${key(4)}":true,"${key(5)}":false,"${key(6)}":false}',
    });
    installFakes();
  });

  shotTest('login', (tester) async {
    await _shot(tester, '01_login', const LoginScreen());
  });

  shotTest('home', (tester) async {
    await _shot(tester, '02_home', const MainTabNavigator());
  });

  shotTest('education', (tester) async {
    await _shot(tester, '03_education', const MainTabNavigator());
    await tester.tap(find.text('Learn'));
    await _settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('03_education.png'));
  });

  shotTest('article', (tester) async {
    await _shot(tester, '04_article', ArticleScreen(article: FakeContentService.article));
  });

  shotTest('video', (tester) async {
    await _shot(tester, '05_video', VideoScreen(video: FakeContentService.videos[0], startAt: 140));
  });

  shotTest('community', (tester) async {
    await _shot(tester, '06_community', const MainTabNavigator());
    await tester.tap(find.text('Community'));
    await _settle(tester);
    await tester.tap(find.text('Walking wins'));
    await _settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('06_community.png'));
  });

  shotTest('community join', (tester) async {
    installFakes(joinedCommunity: false);
    await _shot(tester, '07_community_join', const MainTabNavigator());
    await tester.tap(find.text('Community'));
    await _settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('07_community_join.png'));
  });

  shotTest('post', (tester) async {
    await _shot(tester, '08_post',
        PostScreen(post: FakeCommunityService.posts[0], canComment: true));
  });

  shotTest('settings', (tester) async {
    await _shot(tester, '09_settings', const SettingsScreen());
  });

  shotTest('app locks', (tester) async {
    await _shot(tester, '10_app_locks', const AppLockSettingsScreen());
  });

  shotTest('goal', (tester) async {
    await _shot(tester, '11_goal', const GoalManagementScreen());
  });
}
