import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/constants/incline_general_programs.dart';

void main() {
  group('Workout Duration & Rest Calculation Tests', () {
    test('WorkoutDay.calculatedMinutes calculates realistic time with sets, rest, and warm-up', () {
      final day = WorkoutDay(
        id: 'test_day_1',
        dayLabel: 'Monday',
        weekLabel: 'Week 1',
        focus: 'Chest & Back',
        weekdayIndex: 1,
        warmUp: '5 min dynamic warm-up',
        coolDown: '5 min static stretching',
        exercises: [
          WorkoutExercise(
            name: 'Bench Press',
            sets: 3,
            reps: '10-12',
            rest: '90s',
          ),
          WorkoutExercise(
            name: 'Lat Pulldown',
            sets: 3,
            reps: '10-12',
            rest: '60s',
          ),
        ],
      );

      // Calculation breakdown:
      // Warm-up: 300s (5 min)
      // Cool-down: 300s (5 min)
      // Bench Press:
      //   - Work: 3 sets * 35s = 105s
      //   - Rest: (3 - 1) * 90s = 180s
      //   - Setup: 45s
      //   Total = 330s (5.5 min)
      // Lat Pulldown:
      //   - Work: 3 sets * 35s = 105s
      //   - Rest: (3 - 1) * 60s = 120s
      //   - Setup: 45s
      //   Total = 270s (4.5 min)
      // Grand Total = 300 + 300 + 330 + 270 = 1200 seconds = 20 minutes
      expect(day.calculatedMinutes, equals(20));
      expect(day.estimatedMinutes, equals(20));
    });

    test('WorkoutDay.calculatedMinutes handles cardio minutes correctly', () {
      final cardioDay = WorkoutDay(
        id: 'test_cardio',
        dayLabel: 'Wednesday',
        weekLabel: 'Week 1',
        focus: 'Cardio',
        weekdayIndex: 3,
        exercises: [
          WorkoutExercise(
            name: 'Treadmill',
            sets: 1,
            reps: '20 min',
            rest: '60s',
          ),
        ],
      );

      // 20 min cardio = 20 * 60 = 1200s + 0 warm/cool = 20 minutes
      expect(cardioDay.calculatedMinutes, equals(20));
    });

    test('WorkoutDay.calculatedMinutes returns 0 for rest days', () {
      final restDay = WorkoutDay(
        id: 'test_rest',
        dayLabel: 'Sunday',
        weekLabel: 'Week 1',
        focus: 'Rest',
        weekdayIndex: 0,
        isRest: true,
        exercises: [],
      );

      expect(restDay.calculatedMinutes, equals(0));
      expect(restDay.estimatedMinutes, equals(0));
    });

    test('InclineGeneralPrograms advance program has realistic durations', () {
      final plan = InclineGeneralPrograms.advanceFitnessWorkoutProgram;
      for (final day in plan.days) {
        if (day.isRest) {
          expect(day.estimatedMinutes, equals(0));
        } else {
          expect(day.estimatedMinutes, greaterThanOrEqualTo(15));
          expect(day.estimatedMinutes, lessThanOrEqualTo(90));
        }
      }
    });
  });
}
