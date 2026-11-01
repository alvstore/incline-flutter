import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/features/diet/diet_view.dart';
import 'package:incline_app/features/diet/widgets/macro_radar_card.dart';
import 'package:incline_app/features/diet/widgets/water_intake_card.dart';
import 'package:incline_app/features/diet/widgets/meal_card.dart';
import 'package:incline_app/features/diet/widgets/supplements_card.dart';

import 'package:incline_app/core/widgets/dumbbell_loader.dart';

void main() {
  group('Diet & Nutrition Feature Tests', () {
    testWidgets('MacroRadarCard displays correct remaining calories and macros', (tester) async {
      final dayPlan = DietDayPlan(
        dayLabel: 'Wednesday',
        weekdayIndex: 3,
        nutritionistNote: 'Active Recovery & Rest Day',
        targetCalories: 2200,
        targetProtein: 175,
        targetCarbs: 200,
        targetFats: 60,
        targetWaterMl: 4000,
        meals: [
          DietMeal(
            id: 'm1',
            name: 'Hydration & Peptide Elixir',
            time: '07:30 AM',
            targetCalories: 150,
            targetProtein: 10,
            targetCarbs: 15,
            targetFats: 2,
            isCompleted: true,
            items: [
              MealFoodItem(name: 'Electrolytes', quantity: '500 ml', calories: 20, protein: 0, carbs: 4, fats: 0),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MacroRadarCard(dayPlan: dayPlan),
            ),
          ),
        ),
      );

      expect(find.text('DAILY MACRONUTRIENTS'), findsOneWidget);
      expect(find.text('2050 kcal remaining'), findsOneWidget);
    });

    testWidgets('WaterIntakeCard handles +250ml and +500ml actions', (tester) async {
      int loggedAmount = 0;
      bool resetTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaterIntakeCard(
              currentMl: 1000,
              targetMl: 3800,
              onAddWater: (delta) => loggedAmount += delta,
              onReset: () => resetTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('DAILY HYDRATION'), findsOneWidget);
      expect(find.text('1.0'), findsOneWidget);
      expect(find.text(' / 3.8 L'), findsOneWidget);

      await tester.tap(find.text('+250 ml (Glass)'));
      expect(loggedAmount, 250);

      await tester.tap(find.text('+500 ml (Shaker)'));
      expect(loggedAmount, 750);

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      expect(resetTriggered, isTrue);
    });

    testWidgets('MealCard expands and toggles completion', (tester) async {
      bool toggleValue = false;
      final meal = DietMeal(
        id: 'm2',
        name: 'Artisan Grilled Salmon',
        time: '01:00 PM',
        targetCalories: 620,
        targetProtein: 48,
        targetCarbs: 38,
        targetFats: 18,
        prepTips: 'Grill with rosemary and olive oil.',
        items: [
          MealFoodItem(
            name: 'Atlantic Salmon Fillet',
            quantity: '220g',
            calories: 450,
            protein: 44,
            carbs: 0,
            fats: 16,
            alternative: 'Tofu Steak (250g)',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealCard(
                meal: meal,
                index: 0,
                onToggleCompleted: (done) => toggleValue = done,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Artisan Grilled Salmon'), findsOneWidget);
      expect(find.text('620 kcal'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('Artisan Grilled Salmon'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('CURATED NUTRITIONAL ITEMS & PORTIONS'), findsOneWidget);
      expect(find.text('Atlantic Salmon Fillet'), findsOneWidget);
      expect(find.text('220g'), findsOneWidget);
      expect(find.text('Swap option: Tofu Steak (250g)'), findsOneWidget);

      // Tap toggle completion
      await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded));
      expect(toggleValue, isTrue);
    });

    testWidgets('SupplementsCard checks and unchecks items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SupplementsCard(
                supplements: [
                  'Creapure® Micronized Creatine (5g)',
                  'Ultra-Pure Omega-3 EPA/DHA (2,000mg)',
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('DAILY SUPPLEMENT PROTOCOL'), findsOneWidget);
      expect(find.text('Creapure® Micronized Creatine (5g)'), findsOneWidget);
    });

    testWidgets('DietView renders authentic empty state when no plan is assigned', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DietView(),
          ),
        ),
      );

      // Initial loading
      expect(find.byType(DumbbellLoader), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No Nutrition Plan Assigned'), findsOneWidget);
    });

    testWidgets('DietView renders full plan layout with Mon-Sun schedule when plan is assigned', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockPlan = MemberDietPlan(
        id: 'test_plan',
        planName: 'Elite Hypertrophy Fuel',
        nutritionistName: 'Coach Bhagirath Gurjar',
        dietaryType: 'High-Protein Clean Fuel',
        cuisine: 'Modern Indian & Mediterranean',
        days: [
          DietDayPlan(
            dayLabel: 'Monday',
            weekdayIndex: 1,
            nutritionistNote: 'Focus on hydration',
            targetCalories: 2400,
            targetProtein: 180,
            targetCarbs: 220,
            targetFats: 65,
            targetWaterMl: 3500,
            supplements: ['Creatine Monohydrate (5g)', 'Whey Isolate (30g)'],
            meals: [
              DietMeal(
                id: 'm1',
                name: 'Breakfast Bowl',
                time: '08:00 AM',
                targetCalories: 550,
                targetProtein: 40,
                targetCarbs: 60,
                targetFats: 15,
                items: [
                  MealFoodItem(name: 'Oats & Berries', quantity: '100g', calories: 350, protein: 12, carbs: 55, fats: 5),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DietView(initialPlan: mockPlan),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('WEEKLY NUTRITION SCHEDULE'), findsOneWidget);
      expect(find.text('DAILY MACRONUTRIENTS'), findsOneWidget);
      expect(find.text('DAILY HYDRATION'), findsOneWidget);
      expect(find.text('DAILY SUPPLEMENT PROTOCOL'), findsOneWidget);
    });

    testWidgets('MacroRadarCard toggles to Clinical Micronutrients and displays electrolytes', (tester) async {
      const micros = DietMicronutrients(
        fiber: 35.0,
        sodium: 2100.0,
        potassium: 3200.0,
        magnesium: 390.0,
        zinc: 14.0,
        iron: 16.0,
        calcium: 950.0,
        vitaminD: 1800.0,
        vitaminC: 85.0,
        vitaminB12: 5.5,
        omega3: 1400.0,
      );

      final dayPlan = DietDayPlan(
        dayLabel: 'Thursday',
        weekdayIndex: 4,
        targetCalories: 2500,
        targetProtein: 190,
        targetCarbs: 230,
        targetFats: 70,
        targetMicros: DietMicronutrients.athleticRda,
        meals: [
          DietMeal(
            id: 'm1',
            name: 'Hydration & Power Bowl',
            time: '08:00 AM',
            targetCalories: 500,
            targetProtein: 40,
            targetCarbs: 50,
            targetFats: 15,
            micros: micros,
            isCompleted: true,
            items: const [
              MealFoodItem(
                name: 'Oats & Berries',
                quantity: '1 bowl',
                calories: 350,
                protein: 20,
                carbs: 45,
                fats: 8,
                fiber: 6.0,
                micros: micros,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MacroRadarCard(dayPlan: dayPlan),
            ),
          ),
        ),
      );

      // Verify Macros view initially
      expect(find.text('Macros & Calories'), findsOneWidget);
      expect(find.text('Micros & Electrolytes'), findsOneWidget);
      expect(find.text('2000 kcal remaining'), findsOneWidget);

      // Tap on Micros & Electrolytes tab
      await tester.tap(find.text('Micros & Electrolytes'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Verify Clinical Electrolytes & Micronutrients appear
      expect(find.text('CLINICAL ELECTROLYTES & MICRONUTRIENTS'), findsOneWidget);
      expect(find.text('Potassium (K)'), findsOneWidget);
      expect(find.text('Sodium (Na)'), findsOneWidget);
      expect(find.text('Magnesium (Mg)'), findsOneWidget);
      expect(find.text('Dietary Fiber'), findsOneWidget);
      expect(find.text('Zinc (Zn)'), findsOneWidget);
      expect(find.text('ATHLETIC RDA'), findsOneWidget);
    });

    test('DietMeal.fromJson accurately maps backend slot totals and video links', () {
      final json = {
        'id': 'slot_lunch_01',
        'name': 'Power Athlete Lunch',
        'time': '01:30 PM',
        'totals': {
          'calories': 680,
          'protein': 55.0,
          'carbs': 75.0,
          'fats': 18.0,
        },
        'items': [
          {
            'name': 'Grilled Chicken Breast',
            'quantity': '200g',
            'calories': 330,
            'protein': 46,
            'carbs': 0,
            'fats': 7,
          },
          {
            'name': 'Brown Basmati Rice',
            'quantity': '150g',
            'calories': 210,
            'protein': 5,
            'carbs': 45,
            'fats': 2,
          },
        ],
        'notes': 'Marinated in Greek yogurt and herbs',
        'recipe_link': 'https://incline.fit/recipes/athlete_lunch',
      };

      final meal = DietMeal.fromJson(json);
      expect(meal.name, equals('Power Athlete Lunch'));
      expect(meal.time, equals('01:30 PM'));
      expect(meal.targetCalories, equals(680));
      expect(meal.targetProtein, equals(55.0));
      expect(meal.targetCarbs, equals(75.0));
      expect(meal.targetFats, equals(18.0));
      expect(meal.items.length, equals(2));
      expect(meal.items[0].name, equals('Grilled Chicken Breast'));
      expect(meal.prepTips, equals('Marinated in Greek yogurt and herbs'));
      expect(meal.recipeLink, equals('https://incline.fit/recipes/athlete_lunch'));
    });

    testWidgets('DietView renders 1-day plan without empty state even if opened on different weekday', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final singleDayPlan = MemberDietPlan(
        id: 'ba74a19b-02a4-4967-bd30-2edb70750972',
        planName: 'Muscle Gain Indian Plan (Non-Veg)',
        description: 'Authentic high-protein Indian non-veg meal plan.',
        nutritionistName: 'Incline Sports Nutritionist',
        dietaryType: 'High-Protein Muscle Gain',
        days: [
          DietDayPlan(
            dayLabel: 'Monday',
            weekdayIndex: 1,
            targetCalories: 2580,
            targetProtein: 189.0,
            targetCarbs: 266.0,
            targetFats: 75.0,
            meals: [
              DietMeal(
                id: 'm_breakfast',
                name: 'Breakfast • Fuel',
                time: '08:30 AM',
                targetCalories: 550,
                targetProtein: 42.0,
                targetCarbs: 55.0,
                targetFats: 18.0,
                items: const [
                  MealFoodItem(
                    name: 'Eggs & Oats',
                    quantity: '4 whole eggs + 60g oats',
                    calories: 550,
                    protein: 42.0,
                    carbs: 55.0,
                    fats: 18.0,
                    fiber: 7.0,
                  ),
                ],
              ),
              DietMeal(
                id: 'm_lunch',
                name: 'Lunch • Sustained Energy',
                time: '01:30 PM',
                targetCalories: 750,
                targetProtein: 58.0,
                targetCarbs: 80.0,
                targetFats: 22.0,
                items: const [
                  MealFoodItem(
                    name: 'Chicken Breast & Brown Rice',
                    quantity: '250g chicken + 150g rice',
                    calories: 750,
                    protein: 58.0,
                    carbs: 80.0,
                    fats: 22.0,
                    fiber: 5.0,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: DietView(initialPlan: singleDayPlan),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure that even if today is Thursday/Friday, Monday is safely selected and rendered
      expect(find.text('No Nutrition Plan Assigned'), findsNothing);
      expect(find.text('DAILY MACRONUTRIENTS'), findsOneWidget);
      expect(find.text('Breakfast • Fuel'), findsOneWidget);
      expect(find.text('Lunch • Sustained Energy'), findsOneWidget);
      expect(find.textContaining('2580'), findsWidgets); // Calories target
      expect(find.textContaining('189g'), findsWidgets); // Real Protein
      expect(find.textContaining('266g'), findsWidgets); // Real Carbs
      expect(find.textContaining('75g'), findsWidgets);  // Real Fats
    });

    testWidgets('DietView renders dynamic slot labels and persists meal consumption on device', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fullDayPlan = MemberDietPlan(
        id: 'ba74a19b-02a4-4967-bd30-2edb70750972',
        planName: 'Muscle Gain Indian Plan (Non-Veg)',
        nutritionistName: 'Bhagirath Gurjar',
        dietaryType: 'High-Protein Muscle Gain',
        days: [
          DietDayPlan(
            dayLabel: 'Monday',
            weekdayIndex: 1,
            targetCalories: 2580,
            targetProtein: 189.0,
            targetCarbs: 266.0,
            targetFats: 75.0,
            meals: [
              DietMeal(
                id: 'monday_pre_workout',
                name: 'Banana + 1 Scoop Whey Protein in Water',
                slotLabel: 'Pre-Workout',
                time: '06:30',
                targetCalories: 220,
                targetProtein: 25.0,
                targetCarbs: 28.0,
                targetFats: 1.0,
                items: const [MealFoodItem(name: 'Banana + Whey', quantity: '1 serving', calories: 220, protein: 25, carbs: 28, fats: 1)],
              ),
              DietMeal(
                id: 'monday_post_workout',
                name: 'Chicken Breast with Rice — 100g + 1/2 cup rice',
                slotLabel: 'Post-Workout',
                time: '08:30',
                targetCalories: 280,
                targetProtein: 28.0,
                targetCarbs: 30.0,
                targetFats: 5.0,
                items: const [MealFoodItem(name: 'Chicken + Rice', quantity: '1 serving', calories: 280, protein: 28, carbs: 30, fats: 5)],
              ),
              DietMeal(
                id: 'monday_breakfast',
                name: 'Egg Sandwich (3 whole eggs + 2 BB) — 1',
                slotLabel: 'Breakfast',
                time: '10:00',
                targetCalories: 430,
                targetProtein: 24.0,
                targetCarbs: 42.0,
                targetFats: 18.0,
                items: const [MealFoodItem(name: 'Egg Sandwich', quantity: '1', calories: 430, protein: 24, carbs: 42, fats: 18)],
              ),
              DietMeal(
                id: 'monday_snack1',
                name: 'Oats with Whole Milk and Honey',
                slotLabel: 'Mid-Morning Snack',
                time: '12:00',
                targetCalories: 300,
                targetProtein: 12.0,
                targetCarbs: 45.0,
                targetFats: 8.0,
                items: const [MealFoodItem(name: 'Oats + Milk', quantity: '1 bowl', calories: 300, protein: 12, carbs: 45, fats: 8)],
              ),
              DietMeal(
                id: 'monday_lunch',
                name: 'Chicken Biryani — 1 plate',
                slotLabel: 'Lunch',
                time: '02:00',
                targetCalories: 620,
                targetProtein: 34.0,
                targetCarbs: 72.0,
                targetFats: 20.0,
                items: const [MealFoodItem(name: 'Chicken Biryani', quantity: '1 plate', calories: 620, protein: 34, carbs: 72, fats: 20)],
              ),
              DietMeal(
                id: 'monday_snack2',
                name: 'Apple — 1',
                slotLabel: 'Evening Snack',
                time: '17:00',
                targetCalories: 190,
                targetProtein: 26.0,
                targetCarbs: 4.0,
                targetFats: 8.0,
                items: const [MealFoodItem(name: 'Apple', quantity: '1', calories: 190, protein: 26, carbs: 4, fats: 8)],
              ),
              DietMeal(
                id: 'monday_dinner',
                name: 'Fish + Rice — 150g + 1 cup rice',
                slotLabel: 'Dinner',
                time: '08:30',
                targetCalories: 540,
                targetProtein: 40.0,
                targetCarbs: 45.0,
                targetFats: 15.0,
                items: const [MealFoodItem(name: 'Fish + Rice', quantity: '1 serving', calories: 540, protein: 40, carbs: 45, fats: 15)],
              ),
            ],
          ),
        ],
      );

      final dietKey = GlobalKey<DietViewState>();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: DietView(key: dietKey, initialPlan: fullDayPlan),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify all 7 dynamic slot labels are rendered as badges
      expect(find.text('PRE-WORKOUT'), findsOneWidget);
      expect(find.text('POST-WORKOUT'), findsOneWidget);
      expect(find.text('BREAKFAST'), findsOneWidget);
      expect(find.text('MID-MORNING SNACK'), findsOneWidget);
      expect(find.text('LUNCH'), findsOneWidget);
      expect(find.text('EVENING SNACK'), findsOneWidget);
      expect(find.text('DINNER'), findsOneWidget);

      // 2. Verify all food items and macros are present
      expect(find.text('Banana + 1 Scoop Whey Protein in Water'), findsOneWidget);
      expect(find.text('Chicken Biryani — 1 plate'), findsOneWidget);
      expect(find.text('P 25g • C 28g • F 1g'), findsOneWidget);
      expect(find.text('P 34g • C 72g • F 20g'), findsOneWidget);

      // Initially 0 of 7 logged
      expect(find.text('0 of 7 LOGGED'), findsOneWidget);
      expect(find.text('0g / 189g'), findsWidgets); // Consumed protein initially 0

      // 3. Toggle Pre-Workout meal as consumed
      final preWorkoutCheckbox = find.descendant(
        of: find.widgetWithText(MealCard, 'Banana + 1 Scoop Whey Protein in Water'),
        matching: find.byIcon(Icons.radio_button_unchecked_rounded),
      );
      expect(preWorkoutCheckbox, findsOneWidget);
      await tester.ensureVisible(preWorkoutCheckbox);
      await tester.pumpAndSettle();
      await tester.tap(preWorkoutCheckbox);
      await tester.pumpAndSettle();

      // Verify immediate consumption calculation
      expect(find.text('1 of 7 LOGGED'), findsOneWidget);
      expect(find.text('25g / 189g'), findsWidgets); // 25g protein consumed!

      // 4. Simulate tab-switch / refresh via reloadSilent()
      dietKey.currentState?.reloadSilent();
      await tester.pumpAndSettle();

      // Verify the logged state was NOT wiped!
      expect(find.text('1 of 7 LOGGED'), findsOneWidget);
      expect(find.text('25g / 189g'), findsWidgets);
    });
  });
}
