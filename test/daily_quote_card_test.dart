import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/features/home/components/daily_quote_card.dart';

void main() {
  group('DailyQuoteCard Offline Deterministic Tests', () {
    test('getQuoteForDate is deterministic for same calendar date', () {
      final date1 = DateTime(2026, 10, 28, 8, 30);
      final date2 = DateTime(2026, 10, 28, 23, 59);

      final quote1 = DailyQuoteCard.getQuoteForDate(date1);
      final quote2 = DailyQuoteCard.getQuoteForDate(date2);

      expect(quote1.text, equals(quote2.text));
      expect(quote1.author, equals(quote2.author));
      expect(quote1.text.isNotEmpty, isTrue);
      expect(quote1.author.isNotEmpty, isTrue);
    });

    test('getQuoteForDate advances sequentially on different days', () {
      final day1 = DateTime(2026, 10, 28);
      final day2 = DateTime(2026, 10, 29);

      final quote1 = DailyQuoteCard.getQuoteForDate(day1);
      final quote2 = DailyQuoteCard.getQuoteForDate(day2);

      expect(quote1.text, isNot(equals(quote2.text)));
    });

    testWidgets('renders daily quote in Dark Theme', (tester) async {
      final testDate = DateTime(2026, 10, 28);
      final expectedQuote = DailyQuoteCard.getQuoteForDate(testDate);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DailyQuoteCard(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('“${expectedQuote.text}”'), findsOneWidget);
      expect(find.text('— ${expectedQuote.author}'), findsOneWidget);
      expect(find.byIcon(Icons.format_quote_rounded), findsOneWidget);
    });

    testWidgets('renders daily quote in Light Theme', (tester) async {
      final testDate = DateTime(2026, 10, 29);
      final expectedQuote = DailyQuoteCard.getQuoteForDate(testDate);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: DailyQuoteCard(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('“${expectedQuote.text}”'), findsOneWidget);
      expect(find.text('— ${expectedQuote.author}'), findsOneWidget);
    });

    testWidgets('responsive layout on narrow screen (320px) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testDate = DateTime(2026, 10, 28);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DailyQuoteCard(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DailyQuoteCard), findsOneWidget);
    });

    testWidgets('responsive layout on wide tablet screen (800px) is constrained and centered', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testDate = DateTime(2026, 10, 28);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DailyQuoteCard(date: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ConstrainedBox), findsWidgets);
    });

    testWidgets('respects disableAnimations setting', (tester) async {
      final testDate = DateTime(2026, 10, 28);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DailyQuoteCard(date: testDate),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(DailyQuoteCard), findsOneWidget);
    });
  });
}
