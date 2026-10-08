// Fake services with realistic sample data, so screens can be rendered
// without Supabase, sensors or platform plugins.

import 'dart:async';

import 'package:walkies/models/app_lock.dart';
import 'package:walkies/models/community.dart';
import 'package:walkies/models/content.dart';
import 'package:walkies/models/daily_steps.dart';
import 'package:walkies/models/installed_app.dart';
import 'package:walkies/models/step_goal.dart';
import 'package:walkies/services/app_locker_service.dart';
import 'package:walkies/services/community_service.dart';
import 'package:walkies/services/content_service.dart';
import 'package:walkies/services/notification_service.dart';
import 'package:walkies/services/permissions_service.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/supabase_service.dart';

const me = 'user-me';
final now = DateTime.now();

class FakeSupabaseService extends SupabaseService {
  FakeSupabaseService() : super.forTesting();

  @override
  String? get currentUserId => me;
  @override
  String? get currentUserEmail => 'jamie@example.com';
  @override
  Future<String?> getPreferredName() async => 'Jamie';
  @override
  Future<void> ensureUserProfile() async {}
  @override
  Future<StepGoal?> getStepGoal() async =>
      StepGoal(id: 'g', userId: me, dailySteps: 7000, createdAt: now);
  @override
  Future<DailySteps?> getTodaySteps() async => DailySteps(
      id: 't', userId: me, steps: 4850, date: now, createdAt: now);
  @override
  Future<List<DailySteps>> getStepsHistory(int days) async => [];
  @override
  Future<List<AppLock>> getLockedApps() async => [
        for (final p in ['com.instagram.android', 'com.zhiliaoapp.musically'])
          AppLock(
            id: p,
            userId: me,
            appPackageName: p,
            appName: p,
            isLocked: true,
            createdAt: now,
          ),
      ];
}

class FakeStepTrackingService extends StepTrackingService {
  FakeStepTrackingService() : super.forTesting();

  @override
  Future<void> initialize() async {}
  @override
  Future<void> refreshForToday() async {}
  @override
  Future<void> flushToCloud() async {}
  @override
  int get todaySteps => 4850;
  @override
  Stream<int> get todayStepsStream => const Stream.empty();
  @override
  String? get initializationError => null;
}

class FakeAppLockerService extends AppLockerService {
  FakeAppLockerService({this.blockerEnabled = true, this.nativeSteps})
      : super.forTesting();

  final bool blockerEnabled;
  final int? nativeSteps;

  @override
  Future<int?> getNativeTodaySteps() async => nativeSteps;

  static final _apps = [
    InstalledApp(packageName: 'com.instagram.android', appName: 'Instagram'),
    InstalledApp(packageName: 'com.zhiliaoapp.musically', appName: 'TikTok'),
    InstalledApp(packageName: 'com.facebook.katana', appName: 'Facebook'),
    InstalledApp(packageName: 'com.reddit.frontpage', appName: 'Reddit'),
    InstalledApp(packageName: 'com.google.android.youtube', appName: 'YouTube'),
    InstalledApp(packageName: 'com.whatsapp', appName: 'WhatsApp'),
  ];

  @override
  Future<List<InstalledApp>> getInstalledApps({Set<String>? packages}) async =>
      _apps;
  @override
  Future<List<InstalledApp>> getSocialMediaApps({
    Set<String> alsoInclude = const {},
  }) async =>
      _apps;
  @override
  Future<bool> isAppLockingEnabled() async => blockerEnabled;
  @override
  Future<void> syncNativeStepGoalPrefs({
    required int dailyGoal,
    required int todaySteps,
  }) async {}
  @override
  Future<void> syncLockedAppsToAccessibilityService() async {}
  @override
  Future<int?> getStepsRemaining() async => 2150;
  @override
  Future<bool> wasLockedAppOpenedBeforeGoalToday() async => false;
}

class FakeNotificationService extends NotificationService {
  FakeNotificationService() : super.forTesting();

  @override
  Future<void> initialize() async {}
}

class FakePermissionsService extends PermissionsService {
  FakePermissionsService() : super.forTesting();

  @override
  Future<bool> requestNotificationPermission() async => true;
}

class FakeContentService extends ContentService {
  FakeContentService() : super.forTesting();

  static final categories = [
    ContentCategory(id: 'c1', name: 'Movement'),
    ContentCategory(id: 'c2', name: 'Menstrual health'),
    ContentCategory(id: 'c3', name: 'Menopause'),
    ContentCategory(id: 'c4', name: 'Mental wellbeing'),
  ];

  static final news = Article(
    id: 'n1',
    kind: 'news',
    title: 'Menopause checks to become part of routine NHS health checks',
    summary:
        'Women in England will be asked about menopause symptoms at their '
        'NHS Health Check, as part of a plan to spot problems earlier.',
    body: '''
The government says menopause will become a standard part of the NHS Health Check offered to adults aged 40 to 74.

## What changes

- Nurses and GPs will ask about **symptoms such as hot flushes, poor sleep and low mood**.
- People will be pointed to support earlier, rather than waiting to raise it themselves.

The report says the aim is to close the gap in time women spend in poor health.
''',
    createdAt: now.subtract(const Duration(hours: 3)),
    sourceName: 'BBC News',
    sourceUrl: 'https://www.bbc.co.uk/news',
    isAiDrafted: true,
  );

  static final article = Article(
    id: 'a1',
    kind: 'article',
    title: 'Why a brisk 10-minute walk is worth more than you think',
    summary:
        'Short bursts of brisk walking add up. Here is what happens in your '
        'body, and how to fit them into a busy day.',
    body: '''
You don't need a gym, or even an hour. Three brisk 10-minute walks spread across the day count towards the 150 minutes of activity a week the NHS recommends.

## What "brisk" means

Walking fast enough that you can still talk, but **not sing**. For most people that is around 100 steps a minute.

## Fitting it in

- Walk the first or last stop of your commute
- Take calls on the move
- Make a lap of the block after lunch

Start where you are. Even a few extra minutes a day makes a difference.
''',
    categoryId: 'c1',
    authorName: 'Dr Priya Shah',
    createdAt: now.subtract(const Duration(days: 1)),
  );

  static final videos = [
    Video(
      id: 'v1',
      title: 'Pelvic floor basics: a 6-minute routine',
      summary: 'A gentle routine you can do anywhere, with a women\'s health physio.',
      playbackUrl: 'https://example.org/v1.m3u8',
      durationSeconds: 372,
      categoryId: 'c2',
      presenterName: 'Hannah Lewis, physiotherapist',
      createdAt: now.subtract(const Duration(hours: 20)),
    ),
    Video(
      id: 'v2',
      title: 'Sleep and the menopause: what actually helps',
      summary: 'Practical changes backed by evidence.',
      playbackUrl: 'https://example.org/v2.m3u8',
      durationSeconds: 545,
      categoryId: 'c3',
      createdAt: now.subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Future<List<ContentCategory>> getCategories() async => categories;
  @override
  Future<Article?> getLatestNews() async => news;
  @override
  Future<List<ContentItem>> getFeed({String? categoryId}) async =>
      [videos[0], article, videos[1]];
  @override
  Future<Map<String, ContentProgress>> getProgress() async => {
        'video:v1': ContentProgress(progressSeconds: 140, completed: false),
      };
  @override
  Future<void> saveProgress({
    required String contentType,
    required String contentId,
    int progressSeconds = 0,
    bool completed = false,
  }) async {}
}

class FakeCommunityService extends CommunityService {
  FakeCommunityService({this.joined = true}) : super.forTesting();

  final bool joined;

  static final topics = [
    CommunityTopic(id: 't0', name: 'Announcements', isLocked: true),
    CommunityTopic(
      id: 't1',
      name: 'Walking wins',
      description: 'Share your progress and favourite routes',
      isLocked: false,
    ),
    CommunityTopic(
      id: 't2',
      name: 'Health chat',
      description: 'Support and experiences. Not medical advice.',
      isLocked: false,
    ),
    CommunityTopic(id: 't3', name: 'Introductions', isLocked: false),
  ];

  static final posts = [
    CommunityPost(
      id: 'p1',
      topicId: 't1',
      authorId: 'u1',
      authorName: 'Sophie',
      body: 'Hit 10,000 steps for the first time since my knee op! Took the '
          'long way round the reservoir at Carsington and it was gorgeous this morning.',
      status: 'visible',
      createdAt: now.subtract(const Duration(minutes: 42)),
      commentCount: 6,
      reactionCount: 24,
      reactedByMe: true,
    ),
    CommunityPost(
      id: 'p2',
      topicId: 't1',
      authorId: me,
      authorName: 'Jamie',
      body: 'Locking Instagram until lunchtime has genuinely changed my mornings. '
          'Anyone else find the first week the hardest?',
      status: 'visible',
      createdAt: now.subtract(const Duration(hours: 3)),
      commentCount: 3,
      reactionCount: 11,
      reactedByMe: false,
    ),
    CommunityPost(
      id: 'p3',
      topicId: 't1',
      authorId: 'u3',
      authorName: 'Aisha',
      body: 'Rainy day so I did laps of the shopping centre instead. 6,200 and counting.',
      status: 'visible',
      createdAt: now.subtract(const Duration(hours: 7)),
      commentCount: 0,
      reactionCount: 8,
      reactedByMe: false,
    ),
  ];

  static final comments = [
    CommunityComment(
      id: 'c1',
      postId: 'p1',
      authorId: 'u4',
      authorName: 'Megan',
      body: 'That is brilliant, well done! Carsington is my favourite too.',
      status: 'visible',
      createdAt: now.subtract(const Duration(minutes: 30)),
    ),
    CommunityComment(
      id: 'c2',
      postId: 'p1',
      authorId: me,
      authorName: 'Jamie',
      body: 'Amazing progress. How long did the full loop take you?',
      status: 'visible',
      createdAt: now.subtract(const Duration(minutes: 18)),
    ),
    CommunityComment(
      id: 'c3',
      postId: 'p1',
      authorId: 'u1',
      authorName: 'Sophie',
      body: 'About two hours with a coffee stop!',
      status: 'visible',
      createdAt: now.subtract(const Duration(minutes: 9)),
    ),
  ];

  @override
  String? get currentUserId => me;
  @override
  Future<CommunityProfile?> getMyProfile() async =>
      joined ? CommunityProfile(userId: me, displayName: 'Jamie') : null;
  @override
  Future<DateTime?> getMyRestriction() async => null;
  @override
  Future<List<CommunityTopic>> getTopics() async => topics;
  @override
  Future<List<CommunityPost>> getPosts(String topicId, {DateTime? before}) async =>
      before == null ? posts : [];
  @override
  Future<CommunityPost?> getPost(String postId) async =>
      posts.firstWhere((p) => p.id == postId);
  @override
  Future<List<CommunityComment>> getComments(String postId) async => comments;
}

void installFakes({
  bool joinedCommunity = true,
  bool blockerEnabled = true,
  int? nativeSteps,
}) {
  SupabaseService.debugOverride = FakeSupabaseService();
  StepTrackingService.debugOverride = FakeStepTrackingService();
  AppLockerService.debugOverride = FakeAppLockerService(
    blockerEnabled: blockerEnabled,
    nativeSteps: nativeSteps,
  );
  NotificationService.debugOverride = FakeNotificationService();
  PermissionsService.debugOverride = FakePermissionsService();
  ContentService.debugOverride = FakeContentService();
  CommunityService.debugOverride = FakeCommunityService(joined: joinedCommunity);
}
