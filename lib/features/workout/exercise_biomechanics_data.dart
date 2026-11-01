import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum ExerciseArchetype {
  press,
  pull,
  squat,
  hinge,
  core,
  cardio,
}

class ExerciseBiomechanicalProfile {
  final String canonicalName;
  final ExerciseArchetype archetype;
  final String movementPlane;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> stabilizers;
  final List<String> coachFormCues;
  final List<String> mistakesToAvoid;
  final String optimalCadence;
  final String recommendedRest;
  final String leadCoachAdvice;

  const ExerciseBiomechanicalProfile({
    required this.canonicalName,
    required this.archetype,
    required this.movementPlane,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.stabilizers,
    required this.coachFormCues,
    required this.mistakesToAvoid,
    this.optimalCadence = '3-1-1 (3s lower, 1s pause, 1s drive)',
    this.recommendedRest = '60-90s',
    this.leadCoachAdvice = 'Focus on controlled eccentric tension and diaphragmatic bracing.',
  });

  IconData get archetypeIcon {
    switch (archetype) {
      case ExerciseArchetype.press:
        return Icons.fitness_center_rounded;
      case ExerciseArchetype.pull:
        return Icons.vertical_align_bottom_rounded;
      case ExerciseArchetype.squat:
        return Icons.directions_walk_rounded;
      case ExerciseArchetype.hinge:
        return Icons.accessibility_new_rounded;
      case ExerciseArchetype.core:
        return Icons.shield_rounded;
      case ExerciseArchetype.cardio:
        return Icons.speed_rounded;
    }
  }

  Color get archetypeColor {
    switch (archetype) {
      case ExerciseArchetype.press:
        return AppTheme.primaryForest;
      case ExerciseArchetype.pull:
        return AppTheme.cyan;
      case ExerciseArchetype.squat:
        return AppTheme.emerald;
      case ExerciseArchetype.hinge:
        return AppTheme.amber;
      case ExerciseArchetype.core:
        return AppTheme.sky;
      case ExerciseArchetype.cardio:
        return AppTheme.rose;
    }
  }
}

class ExerciseMappingEngine {
  static final List<ExerciseBiomechanicalProfile> _catalog = [
    // 1. Incline Dumbbell Press
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Incline Dumbbell Press',
      archetype: ExerciseArchetype.press,
      movementPlane: 'Sagittal / 45° Transverse Plane',
      primaryMuscles: ['Clavicular Pectoralis (Upper Chest)', 'Anterior Deltoids'],
      secondaryMuscles: ['Triceps Brachii', 'Serratus Anterior'],
      stabilizers: ['Rotator Cuff', 'Core & Erector Spinae'],
      coachFormCues: [
        'Set the bench strictly at 30° to 45° to isolate upper pecs without shoulder impingement.',
        'Retract and depress scapulae into the pad before unracking the dumbbells.',
        'Maintain a 45° elbow tuck relative to the torso throughout the 3-second descent.',
        'Drive through the palms and converge slightly at peak contraction without clanking bells.',
      ],
      mistakesToAvoid: [
        'Excessive flaring of elbows out to 90° which strains the anterior capsule.',
        'Bouncing dumbbells off upper chest at the bottom.',
        'Over-arching lumbar spine to turn it into a flat press.',
      ],
      optimalCadence: '3-1-1 (3s lower, 1s pause, 1s drive)',
      recommendedRest: '90s',
      leadCoachAdvice: 'Coach Bhagirath: Squeeze the upper chest fibres at the top peak for 1 second. Mind-muscle connection yields maximum hypertrophy.',
    ),

    // 2. Barbell Flat Bench Press
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Barbell Flat Bench Press',
      archetype: ExerciseArchetype.press,
      movementPlane: 'Transverse Plane Push',
      primaryMuscles: ['Pectoralis Major (Sternal & Clavicular)', 'Triceps Brachii'],
      secondaryMuscles: ['Anterior Deltoid', 'Serratus Anterior'],
      stabilizers: ['Lats (Latissimus Dorsi)', 'Core', 'Leg Drive (Glutes)'],
      coachFormCues: [
        'Establish 5 points of contact: head, shoulders, glutes, left foot, right foot.',
        'Grip barbell with wrists neutral and knuckles stacked over wrists.',
        'Pull the bar down towards the lower sternum while pulling chest towards bar.',
        'Drive heels firmly into the floor to transfer leg drive through kinetic chain.',
      ],
      mistakesToAvoid: [
        'Bouncing the bar violently off the ribcage.',
        'Lifting glutes off the bench during the concentric drive.',
        'Loose upper back leading to shoulder collapse.',
      ],
      optimalCadence: '2-1-1 (2s lower, 1s pause on chest, 1s drive)',
      recommendedRest: '120s',
      leadCoachAdvice: 'Coach Bhagirath: Think of bending the bar in half as you lower it to engage the lats and lock the shoulders in place.',
    ),

    // 3. Standing Overhead Military Press
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Standing Overhead Military Press',
      archetype: ExerciseArchetype.press,
      movementPlane: 'Frontal / Vertical Push',
      primaryMuscles: ['Anterior & Lateral Deltoids', 'Triceps Brachii'],
      secondaryMuscles: ['Upper Trapezius', 'Pectoralis Major Clavicular Head'],
      stabilizers: ['Transverse Abdominis', 'Gluteus Maximus', 'Erector Spinae'],
      coachFormCues: [
        'Brace glutes and core aggressively to prevent hyperextending lumbar spine.',
        'Keep forearms strictly vertical directly under the bar at bottom position.',
        'Move head slightly backward as bar passes face, then press up and lock head through window.',
      ],
      mistakesToAvoid: [
        'Leaning backward significantly to recruit upper chest.',
        'Pushing with knee dip (this is a strict military press, not push press).',
      ],
      optimalCadence: '3-0-1 (3s lower, no bounce, 1s press)',
      recommendedRest: '90-120s',
      leadCoachAdvice: 'Coach Bhagirath: Lock your glutes like concrete before every rep. Total body stability equals pressing power.',
    ),

    // 4. Romanian Deadlifts (RDL)
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Romanian Deadlifts (RDL)',
      archetype: ExerciseArchetype.hinge,
      movementPlane: 'Sagittal Plane Posterior Chain Hinge',
      primaryMuscles: ['Hamstrings (Biceps Femoris, Semitendinosus)', 'Gluteus Maximus'],
      secondaryMuscles: ['Erector Spinae', 'Adductor Magnus', 'Lats'],
      stabilizers: ['Forearm Flexors (Grip)', 'Core & Obliques', 'Rhomboids'],
      coachFormCues: [
        'Unlock knees slightly (15-20° bend) and freeze knee angle throughout the hinge.',
        'Push hips backward towards the back wall as if closing a car door with your glutes.',
        'Keep barbell dragging directly against shins and thighs—do not let bar drift forward.',
        'Stop descent when hips stop moving backward (usually just below kneecap).',
      ],
      mistakesToAvoid: [
        'Rounding lumbar spine at maximum stretch.',
        'Squatting the weight down instead of hinging backwards.',
        'Hyperextending lower back at lockout instead of squeezing glutes.',
      ],
      optimalCadence: '3-1-1 (3s hinge back, 1s hamstring stretch, 1s glute drive)',
      recommendedRest: '90s',
      leadCoachAdvice: 'Coach Bhagirath: Think hip displacement, not lowering the weight. When your hips stop moving back, initiate the drive with your glutes.',
    ),

    // 5. Cable Lateral Raises
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Cable Lateral Raises',
      archetype: ExerciseArchetype.pull,
      movementPlane: 'Coronal Plane Abduction',
      primaryMuscles: ['Lateral Deltoid (Middle Head)'],
      secondaryMuscles: ['Anterior Deltoid', 'Supraspinatus'],
      stabilizers: ['Upper Trapezius', 'Core Stabilizers'],
      coachFormCues: [
        'Set cable pulley at wrist/hip height to maximize tension in the lengthened range.',
        'Lean slightly forward (10°) into the cable column for optimal scapular plane alignment.',
        'Raise lead elbow slightly higher than wrist; lead with the side delt.',
        'Lower slowly with 3-second resistance against constant cable tension.',
      ],
      mistakesToAvoid: [
        'Using body momentum or hip swing to heave the weight up.',
        'Shrugging traps up to ears instead of isolating lateral delts.',
      ],
      optimalCadence: '3-1-1 (3s eccentric, 1s peak hold, 1s drive)',
      recommendedRest: '60s',
      leadCoachAdvice: 'Coach Bhagirath: Cables provide continuous tension where dumbbells fail. Control the descent to sculpt full shoulder caps.',
    ),

    // 6. Triceps Rope Pushdowns
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Triceps Rope Pushdowns',
      archetype: ExerciseArchetype.press,
      movementPlane: 'Sagittal Plane Elbow Extension',
      primaryMuscles: ['Triceps Brachii (Lateral & Medial Heads)'],
      secondaryMuscles: ['Triceps Long Head', 'Anconeus'],
      stabilizers: ['Core', 'Anterior Shoulder Stabilizers'],
      coachFormCues: [
        'Pin elbows tightly to your ribcage; keep upper arms immobile throughout the set.',
        'Spread the rope ends apart at the bottom contraction to maximize lateral head squeeze.',
        'Control return until forearms reach parallel or slightly above 90°.',
      ],
      mistakesToAvoid: [
        'Letting elbows flare forward and backward.',
        'Leaning over the weight using bodyweight to push down.',
      ],
      optimalCadence: '3-1-1 (3s eccentric control, 1s peak flare, 1s extension)',
      recommendedRest: '45-60s',
      leadCoachAdvice: 'Coach Bhagirath: Lock the elbows like hinges. Only the forearms move. Feel the horseshoe burn.',
    ),

    // 7. Walking Lunges
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Walking Lunges',
      archetype: ExerciseArchetype.squat,
      movementPlane: 'Sagittal Plane Unilateral Drive',
      primaryMuscles: ['Quadriceps', 'Gluteus Maximus'],
      secondaryMuscles: ['Hamstrings', 'Adductors', 'Calves'],
      stabilizers: ['Core', 'Gluteus Medius (Pelvic Stability)', 'Erector Spinae'],
      coachFormCues: [
        'Take a measured stride forward and sink rear knee straight down towards floor.',
        'Maintain an upright torso with chest proud and shoulders pulled back.',
        'Drive through the front heel and mid-foot to stand up in continuous motion.',
        'Keep front knee tracking in line with second toe—do not let knee cave inward.',
      ],
      mistakesToAvoid: [
        'Front knee collapsing inward (valgus collapse).',
        'Banging rear knee against the hard gym floor.',
        'Short stepping that pushes front knee excessively forward.',
      ],
      optimalCadence: '2-0-1 (Smooth walking cadence)',
      recommendedRest: '60s',
      leadCoachAdvice: 'Coach Bhagirath: Unilateral leg training corrects pelvic imbalances and builds functional athletic power.',
    ),

    // 8. Seated Hamstring Curls
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Seated Hamstring Curls',
      archetype: ExerciseArchetype.pull,
      movementPlane: 'Sagittal Plane Knee Flexion',
      primaryMuscles: ['Hamstrings (Biceps Femoris Long & Short Heads)'],
      secondaryMuscles: ['Gastrocnemius', 'Gracilis', 'Sartorius'],
      stabilizers: ['Hip Stabilizers', 'Core'],
      coachFormCues: [
        'Align knee joint directly with the machine axis pivot point.',
        'Fasten the thigh pad snugly to prevent hips from lifting during flexion.',
        'Curl heels under seat explosively and hold peak hamstring contraction for 1 second.',
        'Resist the pad on the return, keeping tension high throughout full range.',
      ],
      mistakesToAvoid: [
        'Letting the weight stack slam on the eccentric return.',
        'Pointing toes inward or hyperextending ankles.',
      ],
      optimalCadence: '3-1-1 (3s extension, 1s full curl squeeze, 1s pull)',
      recommendedRest: '60s',
      leadCoachAdvice: 'Coach Bhagirath: The seated curl places hamstrings in a lengthened hip position, providing superior muscle stimulus over lying curls.',
    ),

    // 9. Barbell Hip Thrusts
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Barbell Hip Thrusts',
      archetype: ExerciseArchetype.hinge,
      movementPlane: 'Sagittal Plane Glute Extension',
      primaryMuscles: ['Gluteus Maximus (Upper & Lower Divs)'],
      secondaryMuscles: ['Hamstrings', 'Adductor Magnus'],
      stabilizers: ['Transverse Abdominis', 'Quadriceps'],
      coachFormCues: [
        'Rest upper back/scapulae on bench edge with bar padded across hip crease.',
        'Position feet so shins are vertical (90°) at peak extension.',
        'Keep chin tucked into chest and gaze forward throughout the lift.',
        'Drive through heels to full horizontal hip lockout; squeeze glutes hard for 1 second.',
      ],
      mistakesToAvoid: [
        'Hyperextending lumbar spine at the top instead of achieving posterior pelvic tilt.',
        'Looking up at the ceiling which arches lower back.',
      ],
      optimalCadence: '2-1-1 (2s lower, 1s isometric glute clamp, 1s drive)',
      recommendedRest: '90s',
      leadCoachAdvice: 'Coach Bhagirath: Keep your chin tucked and ribs down. Full glute contraction without lower back involvement.',
    ),

    // 10. Standing Calf Raises
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Standing Calf Raises',
      archetype: ExerciseArchetype.squat,
      movementPlane: 'Sagittal Plane Plantarflexion',
      primaryMuscles: ['Gastrocnemius (Medial & Lateral Heads)'],
      secondaryMuscles: ['Soleus', 'Tibialis Posterior'],
      stabilizers: ['Intrinsic Foot Muscles', 'Core'],
      coachFormCues: [
        'Balls of feet securely on edge of block, heels hanging free.',
        'Descend into a deep 3-second calf stretch at the bottom.',
        'Drive straight up onto big toes and pause at maximum elevation for 2 seconds.',
      ],
      mistakesToAvoid: [
        'Bouncing quickly at the bottom using Achilles tendon elasticity.',
        'Bending knees to push the weight up.',
      ],
      optimalCadence: '3-2-1 (3s deep stretch, 2s peak contraction hold, 1s drive)',
      recommendedRest: '45s',
      leadCoachAdvice: 'Coach Bhagirath: Calves grow under loaded stretches and pauses. Eliminate the bounce.',
    ),

    // 11. Elliptical / Cardio Cadence
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Elliptical Cardio Cadence',
      archetype: ExerciseArchetype.cardio,
      movementPlane: 'Multi-planar Closed Kinetic Loop',
      primaryMuscles: ['Cardiovascular System', 'Quadriceps', 'Glutes'],
      secondaryMuscles: ['Hamstrings', 'Calves', 'Deltoids & Lats (Dual Handles)'],
      stabilizers: ['Core Stability', 'Pelvic Neutral'],
      coachFormCues: [
        'Push and pull the moving handlebars to distribute effort across full body.',
        'Maintain a steady rhythm of 65-75 RPM with moderate magnetic resistance.',
        'Keep heels planted flat on pedals to protect knee joints.',
      ],
      mistakesToAvoid: [
        'Leaning forward heavily on handrails.',
        'Pedaling on tiptoes with high bouncing.',
      ],
      optimalCadence: 'Continuous aerobic pacing (Zone 2-3)',
      recommendedRest: 'Continuous',
      leadCoachAdvice: 'Coach Bhagirath: Low-impact cardio accelerates lymphatic drainage and recovery between heavy lifting sessions.',
    ),

    // 12. Back Extension
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Back Extension',
      archetype: ExerciseArchetype.hinge,
      movementPlane: 'Sagittal Plane Posterior Extension',
      primaryMuscles: ['Erector Spinae', 'Gluteus Maximus'],
      secondaryMuscles: ['Hamstrings'],
      stabilizers: ['Core', 'Upper Trapezius'],
      coachFormCues: [
        'Position pelvic pad just below hip crease to allow free hip flexion.',
        'Hinge forward from the hips with spine neutral.',
        'Raise torso until body forms a straight line—do not hyperextend past neutral.',
      ],
      mistakesToAvoid: [
        'Swinging torso up aggressively with momentum.',
        'Excessive backward arching at the peak.',
      ],
      optimalCadence: '3-1-1 (3s descent, 1s peak hold, 1s ascent)',
      recommendedRest: '60s',
      leadCoachAdvice: 'Coach Bhagirath: Strengthens the spinal erectors against disc compression.',
    ),

    // 13. Hip Abduction
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Hip Abduction',
      archetype: ExerciseArchetype.squat,
      movementPlane: 'Frontal Plane Hip Abduction',
      primaryMuscles: ['Gluteus Medius', 'Gluteus Minimus', 'Tensor Fasciae Latae'],
      secondaryMuscles: ['Piriformis', 'Obturator Externus'],
      stabilizers: ['Core', 'Pelvic Floor'],
      coachFormCues: [
        'Sit firmly against backrest with knees against outside pads.',
        'Drive knees outward smoothly against resistance until full abduction.',
        'Hold the contraction for 1 full second before 3-second eccentric return.',
      ],
      mistakesToAvoid: [
        'Letting weights crash together at bottom.',
        'Twisting hips or sliding forward on seat.',
      ],
      optimalCadence: '3-1-1 (3s return, 1s outward peak squeeze, 1s drive)',
      recommendedRest: '45-60s',
      leadCoachAdvice: 'Coach Bhagirath: Vital for knee tracking and preventing hip collapse during squats.',
    ),

    // 14. Plank
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Forearm Plank',
      archetype: ExerciseArchetype.core,
      movementPlane: 'Sagittal Anti-Extension Isometric',
      primaryMuscles: ['Rectus Abdominis', 'Transverse Abdominis'],
      secondaryMuscles: ['Internal & External Obliques', 'Serratus Anterior'],
      stabilizers: ['Gluteus Maximus', 'Quadriceps', 'Shoulder Girdle'],
      coachFormCues: [
        'Place elbows under shoulders, forearms parallel.',
        'Tuck pelvis into posterior tilt, engage glutes, and pull belly button to spine.',
        'Imagine pulling elbows towards toes to create maximum anterior core tension.',
      ],
      mistakesToAvoid: [
        'Sagging hips towards floor (lumbar hyperextension).',
        'Piking hips into an inverted V shape.',
        'Holding breath—maintain steady diaphragmatic breathing.',
      ],
      optimalCadence: 'Isometric hold (30-60s sets)',
      recommendedRest: '45s',
      leadCoachAdvice: 'Coach Bhagirath: A true plank is an active contraction, not just waiting out the clock. Squeeze everything.',
    ),

    // 15. Kettlebell Swings
    const ExerciseBiomechanicalProfile(
      canonicalName: 'Kettlebell Swings',
      archetype: ExerciseArchetype.hinge,
      movementPlane: 'Sagittal Ballistic Hip Hinge',
      primaryMuscles: ['Gluteus Maximus', 'Hamstrings'],
      secondaryMuscles: ['Core', 'Latissimus Dorsi', 'Forearms'],
      stabilizers: ['Rotator Cuff', 'Upper Back', 'Calves'],
      coachFormCues: [
        'Hinge hips backward as the bell swings between upper thighs.',
        'Snap hips forward explosively to stand tall; glutes contract hard.',
        'The bell floats to chest height via hip momentum—do not raise with arms.',
      ],
      mistakesToAvoid: [
        'Squatting the bell down instead of hinging.',
        'Using shoulder muscles to lift the kettlebell.',
      ],
      optimalCadence: 'Ballistic power cadence',
      recommendedRest: '60s',
      leadCoachAdvice: 'Coach Bhagirath: Pure posterior chain explosiveness. Protect your lower back by locking glutes at the top.',
    ),
  ];

  /// Fuzzy match engine that maps any backend exercise title to its biomechanical profile
  static ExerciseBiomechanicalProfile getProfile(String rawName) {
    final lower = rawName.toLowerCase().trim();

    for (final profile in _catalog) {
      final pLower = profile.canonicalName.toLowerCase();
      if (lower.contains(pLower) || pLower.contains(lower)) {
        return profile;
      }
    }

    // Pattern heuristics
    if (lower.contains('incline') || (lower.contains('bench') && lower.contains('press')) || lower.contains('chest')) {
      return _catalog[0]; // Incline press / Bench press
    } else if (lower.contains('deadlift') || lower.contains('rdl')) {
      return _catalog[3]; // RDL
    } else if (lower.contains('overhead') || lower.contains('military') || lower.contains('shoulder')) {
      return _catalog[2]; // Military press
    } else if (lower.contains('lateral') || lower.contains('raise')) {
      return _catalog[4]; // Lateral raise
    } else if (lower.contains('tricep') || lower.contains('pushdown') || lower.contains('skull')) {
      return _catalog[5]; // Triceps pushdown
    } else if (lower.contains('lunge') || lower.contains('split squat')) {
      return _catalog[6]; // Lunges
    } else if (lower.contains('curl') && lower.contains('ham')) {
      return _catalog[7]; // Hamstring curl
    } else if (lower.contains('hip thrust') || lower.contains('bridge')) {
      return _catalog[8]; // Hip thrust
    } else if (lower.contains('calf')) {
      return _catalog[9]; // Calf raise
    } else if (lower.contains('elliptical') || lower.contains('bike') || lower.contains('cycle') || lower.contains('run')) {
      return _catalog[10]; // Elliptical / Cardio
    } else if (lower.contains('back extension') || lower.contains('hyperextension')) {
      return _catalog[11]; // Back extension
    } else if (lower.contains('abduct')) {
      return _catalog[12]; // Abduction
    } else if (lower.contains('plank') || lower.contains('core') || lower.contains('ab')) {
      return _catalog[13]; // Plank
    } else if (lower.contains('swing') || lower.contains('kettlebell')) {
      return _catalog[14]; // Kettlebell swing
    } else if (lower.contains('squat') || lower.contains('leg press')) {
      return _catalog[6]; // Squat/Leg movement
    } else if (lower.contains('pull') || lower.contains('lat') || lower.contains('row')) {
      return _catalog[4]; // Pull movement
    }

    // General fallback
    return ExerciseBiomechanicalProfile(
      canonicalName: rawName,
      archetype: ExerciseArchetype.press,
      movementPlane: 'Multi-planar Functional Movement',
      primaryMuscles: ['Target Muscle Agonist', 'Prime Movers'],
      secondaryMuscles: ['Synergist Muscle Chain', 'Stabilizers'],
      stabilizers: ['Transverse Abdominis (Core)', 'Postural Stabilizers'],
      coachFormCues: [
        'Retract scapulae and stabilize core before beginning the movement.',
        'Maintain a strict 3-second eccentric lowering phase for maximum tension.',
        'Drive through the concentric phase smoothly without using momentum.',
      ],
      mistakesToAvoid: [
        'Rushing the tempo or using jerky motions.',
        'Losing core abdominal brace during heavy exertion.',
      ],
      optimalCadence: '3-1-1 (Controlled time under tension)',
      recommendedRest: '60-90s',
      leadCoachAdvice: 'Coach Bhagirath: Clean form and controlled eccentric lowering are the keys to long-term joint health and hypertrophy.',
    );
  }
}
