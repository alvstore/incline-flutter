import '../../../core/theme/incline_colors.dart';
import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import 'macro_radar_card.dart';
import 'meal_card.dart';

/// Interactive Widget Previews for Incline Nutrition & Diet UI
/// Demonstrates MacroRadarCard with Micronutrient toggle and MealCard with micro breakdown

Widget previewMacroRadarCard() {
  const micros = DietMicronutrients(
    fiber: 32.5,
    sodium: 2100,
    potassium: 3100,
    magnesium: 380,
    zinc: 14.5,
    iron: 16.0,
    calcium: 950,
    vitaminD: 1800,
    vitaminC: 85,
    vitaminB12: 5.5,
    omega3: 1400,
  );

  final dayPlan = DietDayPlan(
    dayLabel: 'Wednesday • Peak Performance',
    weekdayIndex: 3,
    targetCalories: 2450,
    targetProtein: 185,
    targetCarbs: 240,
    targetFats: 65,
    targetMicros: DietMicronutrients.athleticRda,
    meals: [
      DietMeal(
        id: 'm1',
        name: 'Pre-Workout Fuel & Hydration',
        time: '07:30 AM',
        targetCalories: 450,
        targetProtein: 35,
        targetCarbs: 55,
        targetFats: 10,
        micros: micros,
        isCompleted: true,
        items: const [
          MealFoodItem(
            name: 'Steel Cut Oats with Almond Butter & Whey',
            quantity: '1 bowl',
            calories: 380,
            protein: 30,
            carbs: 45,
            fats: 9,
            fiber: 6.5,
          ),
          MealFoodItem(
            name: 'Himalayan Pink Salt & Electrolyte Elixir',
            quantity: '500 ml',
            calories: 70,
            protein: 5,
            carbs: 10,
            fats: 1,
            fiber: 1.0,
          ),
        ],
      ),
    ],
  );

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: Scaffold(
      backgroundColor: InclineColors.bgPrimary,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: MacroRadarCard(dayPlan: dayPlan),
        ),
      ),
    ),
  );
}

Widget previewMealCard() {
  final meal = DietMeal(
    id: 'm2',
    name: 'Artisan Grilled Salmon & Quinoa Bowl',
    time: '01:30 PM',
    targetCalories: 680,
    targetProtein: 52,
    targetCarbs: 48,
    targetFats: 22,
    prepTips: 'Grill with rosemary, extra virgin olive oil, and steamed asparagus.',
    micros: const DietMicronutrients(
      fiber: 7.5,
      potassium: 820,
      magnesium: 115,
      sodium: 540,
      zinc: 4.5,
      iron: 3.8,
      vitaminD: 650,
      omega3: 1850,
    ),
    isCompleted: false,
    items: const [
      MealFoodItem(
        name: 'Wild Atlantic Salmon Fillet',
        quantity: '240g',
        calories: 420,
        protein: 44,
        carbs: 0,
        fats: 20,
        fiber: 0,
      ),
      MealFoodItem(
        name: 'Tri-Color Quinoa & Steamed Asparagus',
        quantity: '1.5 cups',
        calories: 260,
        protein: 8,
        carbs: 48,
        fats: 2,
        fiber: 7.5,
      ),
    ],
  );

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: Scaffold(
      backgroundColor: InclineColors.bgPrimary,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: MealCard(
          meal: meal,
          index: 0,
          onToggleCompleted: (_) {},
        ),
      ),
    ),
  );
}
