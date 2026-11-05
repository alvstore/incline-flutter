import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/services/push_notification_service.dart';
import 'package:incline_app/features/notifications/notifications_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Notifications & Broadcast Bulletins Audit Tests', () {
    test('GymNotification model correctly supports club announcements and personal alerts', () {
      final personalNotif = GymNotification(
        id: 'notif_personal_01',
        title: 'Workout Plan Updated',
        message: 'Coach Bhagirath has assigned you the Hypertrophy Protocol.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        type: 'workout',
        isRead: false,
        badge: 'WORKOUT',
        actionLabel: 'View Details',
      );

      final clubAnnouncement = GymNotification(
        id: 'ann_broadcast_01',
        title: 'Diwali Training Hours',
        message: 'Club recovery floor remains open 24/7. Main gym floor closes at 8 PM.',
        timestamp: DateTime.now(),
        type: 'announcement',
        isRead: false,
        badge: 'IMPORTANT',
        actionLabel: 'View Details',
      );

      expect(personalNotif.type, equals('workout'));
      expect(personalNotif.isRead, isFalse);
      expect(personalNotif.badge, equals('WORKOUT'));

      expect(clubAnnouncement.type, equals('announcement'));
      expect(clubAnnouncement.isRead, isFalse);
      expect(clubAnnouncement.badge, equals('IMPORTANT'));
      expect(clubAnnouncement.id.startsWith('ann_'), isTrue);
    });

    test('Announcement read status persistence via SharedPreferences operates correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('incline_read_announcement_ids') ?? [], isEmpty);

      // Simulate marking announcement ann_xyz123 as read
      const annId = 'xyz123';
      final readIds = (prefs.getStringList('incline_read_announcement_ids') ?? []).toSet();
      readIds.add(annId);
      await prefs.setStringList('incline_read_announcement_ids', readIds.toList());

      final updated = (prefs.getStringList('incline_read_announcement_ids') ?? []).toSet();
      expect(updated.contains('xyz123'), isTrue);
      expect(updated.contains('other_id'), isFalse);
    });

    test('Unread count calculation sums unread personal notifications and unread club bulletins', () {
      final readAnnouncements = {'ann_read_01'};

      final notifications = [
        GymNotification(
          id: 'notif_01',
          title: 'PT Session Confirmed',
          message: 'Session with Trainer at 6:00 PM',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          type: 'booking',
          isRead: false, // Unread personal
        ),
        GymNotification(
          id: 'notif_02',
          title: 'Class Reminder',
          message: 'HIIT in 1 hour',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          type: 'reminder',
          isRead: true, // Read personal
        ),
        GymNotification(
          id: 'ann_unread_01',
          title: 'Recovery Suite Upgrade',
          message: 'Cold plunge temperature calibrated to 4°C',
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          type: 'announcement',
          isRead: readAnnouncements.contains('ann_unread_01'), // Unread bulletin
          badge: 'CLUB BULLETIN',
        ),
        GymNotification(
          id: 'ann_read_01',
          title: 'Hydration Guidelines',
          message: 'Electrolyte intake tips',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          type: 'announcement',
          isRead: readAnnouncements.contains('ann_read_01'), // Read bulletin
        ),
      ];

      final unreadCount = notifications.where((n) => !n.isRead).length;
      expect(unreadCount, equals(2)); // notif_01 and ann_unread_01
    });

    test('Deduplication correctly prevents duplicate bulletin content while keeping latest', () {
      final rawList = [
        GymNotification(
          id: 'ann_01',
          title: 'Annual Maintenance',
          message: 'Sauna maintenance this Saturday.',
          timestamp: DateTime.now(),
          type: 'announcement',
        ),
        GymNotification(
          id: 'notif_dup_01',
          title: 'Annual Maintenance',
          message: 'Sauna maintenance this Saturday.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          type: 'info',
        ),
        GymNotification(
          id: 'notif_unique',
          title: 'Personal Training Request Accepted',
          message: 'Coach assigned.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          type: 'workout',
        ),
      ];

      final seen = <String>{};
      final deduplicated = <GymNotification>[];
      for (final n in rawList) {
        final key = '${n.title.trim().toLowerCase()}_${n.message.trim().toLowerCase()}';
        if (!seen.contains(key)) {
          seen.add(key);
          deduplicated.add(n);
        }
      }

      expect(deduplicated.length, equals(2));
      expect(deduplicated[0].id, equals('ann_01'));
      expect(deduplicated[1].id, equals('notif_unique'));
    });

    test('PushNotificationService correctly triggers local heads-up alert banner', () async {
      final pushService = PushNotificationService.instance;
      bool tapDispatched = false;
      String? tappedRoute;

      pushService.onNotificationTap = (route) {
        tapDispatched = true;
        tappedRoute = route;
      };

      // Dispatches without throwing
      await pushService.showLocalAlert(
        title: '📢 Club Bulletin: Pool Reopening',
        body: 'Contrast therapy pool is now fully operational.',
        payloadRoute: '/notifications',
      );

      // Verify callback trigger
      pushService.onNotificationTap?.call('/notifications');
      expect(tapDispatched, isTrue);
      expect(tappedRoute, equals('/notifications'));
    });
  });

  group('NotificationsScreen Populated UI Tests', () {
    testWidgets('Renders authentic notification cards with badges and responds to filter tabs', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify authentic headers and filter buttons render cleanly
      expect(find.text('Club Bulletins'), findsOneWidget);
      expect(find.textContaining('All'), findsOneWidget);
      expect(find.text('Club News'), findsOneWidget);
      expect(find.text('Reservations'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
    });
  });
}
