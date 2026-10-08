// Opens every main screen at a large system text size with the real
// fonts and fails on any layout overflow ("yellow and black stripes").

import 'package:flutter/material.dart';
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

import 'screenshots/fakes.dart';
import 'screenshots/fonts.dart';

const _textScale = 1.5;

Future<void> _open(WidgetTester tester, Widget home, {String? tab}) async {
  tester.view.physicalSize = const Size(1080, 2340); // 360 x 780, a small phone
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(_textScale)),
      child: child!,
    ),
    home: home,
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (tab != null) {
    await tester.tap(find.text(tab));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  // With --dart-define=SHOW_LAYOUT_ERRORS=true the framework prints the
  // full report (which widget overflowed, and where) instead
  if (!const bool.fromEnvironment('SHOW_LAYOUT_ERRORS')) {
    expect(tester.takeException(), isNull);
  }
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    installFakes();
  });

  testWidgets('login', (t) => _open(t, const LoginScreen()));
  testWidgets('today', (t) => _open(t, const MainTabNavigator()));
  testWidgets('learn', (t) => _open(t, const MainTabNavigator(), tab: 'Learn'));
  testWidgets('community', (t) => _open(t, const MainTabNavigator(), tab: 'Community'));
  testWidgets('community join', (t) {
    installFakes(joinedCommunity: false);
    return _open(t, const MainTabNavigator(), tab: 'Community');
  });
  testWidgets('blocker off banner', (t) {
    installFakes(blockerEnabled: false);
    return _open(t, const MainTabNavigator());
  });
  testWidgets('article', (t) => _open(t, ArticleScreen(article: FakeContentService.article)));
  testWidgets('video', (t) => _open(t, VideoScreen(video: FakeContentService.videos[0], startAt: 140)));
  testWidgets('post', (t) => _open(t, PostScreen(post: FakeCommunityService.posts[0], canComment: true)));
  testWidgets('settings', (t) => _open(t, const SettingsScreen()));
  testWidgets('app locks', (t) => _open(t, const AppLockSettingsScreen()));
  testWidgets('goal', (t) => _open(t, const GoalManagementScreen()));
}
