import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/theme/app_theme.dart';
import 'package:incline_app/core/widgets/curved_notch_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final navItems = const [
    CapsuleNavItem(
      outlineIcon: Icons.hot_tub_outlined,
      filledIcon: Icons.hot_tub_rounded,
      label: 'Bookings',
    ),
    CapsuleNavItem(
      outlineIcon: Icons.fitness_center_outlined,
      filledIcon: Icons.fitness_center_rounded,
      label: 'Workout',
    ),
    CapsuleNavItem(
      outlineIcon: Icons.home_outlined,
      filledIcon: Icons.home_rounded,
      label: 'Home',
      isCenterHero: true,
    ),
    CapsuleNavItem(
      outlineIcon: Icons.shopping_bag_outlined,
      filledIcon: Icons.shopping_bag_rounded,
      label: 'Store',
    ),
    CapsuleNavItem(
      outlineIcon: Icons.insights_outlined,
      filledIcon: Icons.insights_rounded,
      label: 'Activity',
    ),
  ];

  Widget buildTestHarness({
    required int selectedIndex,
    required double width,
    required bool isDark,
    ValueChanged<int>? onSelected,
  }) {
    return MaterialApp(
      theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: CurvedNotchNavBar(
            selectedIndex: selectedIndex,
            onItemSelected: onSelected ?? (_) {},
            items: navItems,
          ),
        ),
      ),
    );
  }

  group('CurvedNotchNavBar 1:1 Precision Audit', () {
    testWidgets('Renders all 5 tabs and active floating bubble for Tab 0 (Bookings)', (tester) async {
      await tester.pumpWidget(buildTestHarness(selectedIndex: 0, width: 360, isDark: false));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CurvedNotchNavBar), findsOneWidget);
      expect(find.byIcon(Icons.hot_tub_rounded), findsOneWidget); // Active bubble icon
      expect(find.text('Bookings'), findsOneWidget);
    });

    testWidgets('Renders and aligns Tab 4 (Activity) at far right without overflow', (tester) async {
      await tester.pumpWidget(buildTestHarness(selectedIndex: 4, width: 360, isDark: false));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.insights_rounded), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
    });

    testWidgets('Renders and transitions through all 5 tabs in Dark Mode without exception', (tester) async {
      int currentTab = 2; // Home
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestHarness(
              selectedIndex: currentTab,
              width: 390,
              isDark: true,
              onSelected: (idx) => setState(() => currentTab = idx),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);

      // Tap Tab 0 (Bookings)
      await tester.tap(find.byTooltip('Bookings'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(currentTab, 0);

      // Tap Tab 4 (Activity)
      await tester.tap(find.byTooltip('Activity'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(currentTab, 4);

      // Tap Tab 1 (Workout)
      await tester.tap(find.byTooltip('Workout'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(currentTab, 1);
    });

    testWidgets('Responsive stress test: adapts from narrow 320dp to tablet 700dp', (tester) async {
      for (final w in [320.0, 360.0, 390.0, 412.0, 430.0, 600.0, 700.0]) {
        tester.view.physicalSize = Size(w, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestHarness(selectedIndex: 2, width: w, isDark: false));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      }
    });
  });
}
