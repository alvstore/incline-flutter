# Incline App Test Infrastructure & 4-Tier E2E Test Suite Specification

## 1. Executive Summary

This document establishes the test architecture, execution protocol, and feature verification matrix for the **Incline Mobile Application** (`incline_app`), built on Flutter 3.27.4 and Dart 3.6.2. 

The primary test deliverable is the 4-Tier Opaque-Box E2E Test Suite located at:
`test/e2e/e2e_features_test.dart`

All test specifications adhere strictly to:
- `PROJECT.md` (Architecture, Feature Inventory & Interface Contracts)
- `ORIGINAL_REQUEST.md` (Exercise Video Toggle & HOWBODY Scanner Camera specifications)
- README §16 (Incline 3D Body Scanner Hardware & Universal Link workflows)

---

## 2. Feature Inventory & Test Mapping

The test infrastructure validates all features scoped across Milestones M1, M2, and M3:

| Feature # | Feature Name | Primary Source / Contract | Test Coverage Tier |
|---|---|---|---|
| **F-01** | Exercise Media Model & Storage URL Normalization | `WorkoutExercise.fromJson`, `EnvConfig.supabaseUrl` | Tier 1, Tier 2, Tier 3 |
| **F-02** | Exercise Video Demos Preference & State | `OfflineSyncService.get/setExerciseVideoDemosEnabled` | Tier 1, Tier 2, Tier 3 |
| **F-03** | Workout Screen Demos Toggle Switch | `WorkoutScreen`, `OfflineSyncService` | Tier 1, Tier 3, Tier 4 |
| **F-04** | Execution Sheet Media Switch & Conditional Display | `WorkoutExecutionSheet`, `AnimatedExerciseVisualizer` | Tier 1, Tier 3, Tier 4 |
| **F-05** | Mobile Scanner Dependency & Camera Configuration | `AndroidManifest.xml`, `Info.plist`, camera permissions | Tier 1, Tier 2 |
| **F-06** | HOWBODY QR Scanner Viewfinder & Parser Contract | `HowbodyQrPayload` URL schema parser | Tier 1, Tier 2, Tier 4 |
| **F-07** | HOWBODY Device Linking Sheet & Unit Converter | Dual-unit converter ($cm \leftrightarrow ft/in$), kind selector | Tier 1, Tier 2, Tier 4 |
| **F-08** | Scanner Session Polling & Report Launch | Polling state machine (`pending` $\rightarrow$ `bound` $\rightarrow$ `completed`) | Tier 1, Tier 2, Tier 4 |
| **F-09** | Progress Screen Scanner Entry Points | `WorkoutScreen` Tab 2 Progress & `InBodyScanSheet` | Tier 1, Tier 4 |
| **F-10** | Universal Deep Links for OS Camera Scanning | `DeepLinkService` route dispatch (`/scan-login`, `/howbody-login`) | Tier 1, Tier 3, Tier 4 |
| **F-11** | Full Regression Safety | Zero regressions across existing 113 tests in `test/` | Regression Suite |

---

## 3. 4-Tier Testing Methodology

The test suite in `test/e2e/e2e_features_test.dart` is structured into four progressive tiers of opaque-box verification:

```
┌─────────────────────────────────────────────────────────────┐
│ Tier 4: Real-World Scenarios                                │
│ (Full member gym workout & HOWBODY scanner linking flows)   │
├─────────────────────────────────────────────────────────────┤
│ Tier 3: Cross-Feature Combinations                          │
│ (Mid-session toggles, multi-session persistence, deep links)│
├─────────────────────────────────────────────────────────────┤
│ Tier 2: Boundary & Corner Cases                             │
│ (Empty URLs, malformed QR schemas, extreme heights, errors) │
├─────────────────────────────────────────────────────────────┤
│ Tier 1: Feature Coverage (Happy Path)                       │
│ (Direct verification of features 1 through 10)              │
└─────────────────────────────────────────────────────────────┘
```

### Tier 1: Feature Coverage (Happy Path)
Verifies the primary intended behavior of each independent feature:
1. **F-01**: `WorkoutExercise` parses `imageUrl`, normalizes relative video paths to the Supabase `workout-videos` storage endpoint (`${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos/${path}`), and preserves absolute HTTP/S links.
2. **F-02**: `OfflineSyncService` defaults video demos preference to `false` (OFF); persisting `true` updates `SharedPreferences` key `'incline_exercise_video_demos_enabled'` and survives subsequent queries.
3. **F-03**: `WorkoutScreen` renders exercise items and respects the active demo preference.
4. **F-04**: `AnimatedExerciseVisualizer` conditionally renders `ExerciseVideoCard` when `showVideo == true` and renders static guides/images when `showVideo == false`. `WorkoutExecutionSheet` allows toggling media mode in the AppBar actions.
5. **F-05**: Verifies camera permission definitions and scanner readiness.
6. **F-06**: QR parser extracts `equipmentNo`, `scanId`, and `kind` from valid Incline QR URLs and query strings.
7. **F-07**: Dual-unit converter accurately calculates metric to imperial ($178\text{ cm} \rightarrow 5\text{ ft } 10\text{ in}$) and imperial to metric ($5\text{ ft } 10\text{ in} \rightarrow 177.8\text{ cm}$).
8. **F-08**: Session polling verifies state transition from `pending` to `bound` and `completed`.
9. **F-09**: Progress View empty assessment card and active 3D assessment cards render expected headers and action triggers.
10. **F-10**: `DeepLinkService` parses `/scan-login` and `/howbody-login` routes and extracts query arguments.

### Tier 2: Boundary & Corner Cases
Adversarial hardening and defensive edge-case testing:
1. **Empty & Malformed Media URLs**: Null, empty string, whitespace-only, or multi-leading slash relative paths (`///exercises/test.mp4`) handle gracefully without throwing unhandled exceptions.
2. **Corrupted & Malicious QR Codes**: Random strings, missing `scanId`, missing `equipmentNo`, SQL injection payloads, and XSS script tags in query parameters are rejected safely (`null` payload or handled error).
3. **Extreme Height Values & Invariant Boundaries**: Negative heights ($-15\text{ cm}$), sub-scanner heights ($45\text{ cm}$), hyper-extreme heights ($320\text{ cm}$), and edge boundaries ($100.0\text{ cm}$, $250.0\text{ cm}$).
4. **Camera Permission Denial**: Graceful handling when camera hardware permissions are rejected or restricted.
5. **Session Polling Failures & Timeouts**: Simulates network dropping or server returning session state `'failed'` or `'cancelled'`.
6. **Storage Resilience**: Handling unexpected data types in `SharedPreferences` without app crash.

### Tier 3: Cross-Feature Combinations
Multi-component interactions and state persistence:
1. **Mid-Session Toggle with Offline Cache**: Changing video demo toggle while caching workout plans ensures serialized JSON retains normalized video URLs and image URLs.
2. **Multi-Session Preference Persistence**: Simulates app restarts to ensure video demo preference is restored and passed to widgets across cold boots.
3. **Deep Link Ingress During Active Sheet**: Incoming scanner deep link dispatched while workout execution sheet is open routes cleanly without tearing down the widget tree.
4. **Converter Mathematical Invariant**: Roundtrip precision test ($cm \rightarrow ft/in \rightarrow cm$) remains within $\pm 0.5\text{ cm}$ tolerance across human height ranges ($120\text{ cm}$ to $220\text{ cm}$).

### Tier 4: Real-World Scenarios
High-fidelity end-to-end user journeys:
1. **Scenario 1: Member Gym Workout & Form Guidance Flow**:
   - Member starts workout on Day 1.
   - Observes default static guide / image mode (data saver active).
   - Toggles "Demos" on; visualizer renders luxury 16:9 `ExerciseVideoCard` with slow-motion `0.75× SLOW-MO` tag.
   - Toggles back to static mode mid-session; completes exercise sets and finishes workout.
2. **Scenario 2: HOWBODY Scanner Pairing & 3D Report Flow**:
   - Member opens Progress Tab (Tab 2).
   - Triggers 3D Body Scanner action.
   - Simulates QR code scan at Incline Udaipur Flagship kiosk (`INC-HOWBODY-UDR-01`).
   - Verifies device label and adjusts height using dual-unit converter.
   - Submits binding and monitors session polling until completion.
   - Inspects generated 3D Body Composition & Posture report with multi-angle photos.

---

## 4. Expected Output Derivation & Authoritative Sources

All expected values in the test suite are derived deterministically:
1. **Storage URLs**: Follow the Supabase public object storage convention:
   `${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos/${cleanPath}`
2. **SharedPreferences Keys**:
   - `'incline_exercise_video_demos_enabled'`: boolean (default `false`)
   - `'incline_cached_workout_plan'`: serialized JSON
3. **Height Math Invariants**:
   - $1\text{ inch} = 2.54\text{ cm}$
   - $1\text{ foot} = 12\text{ inches} = 30.48\text{ cm}$
4. **QR Schema Formats**:
   - Primary: `https://inclinegym.com/scan-login?equipmentNo={no}&scanId={id}&kind={kind}`
   - Secondary: `https://inclinegym.com/howbody-login?...`
   - Tertiary: `incline://scan-login?...` or raw query `equipmentNo=...&scanId=...`

---

## 5. Test Execution Protocol

### Running the E2E Test Suite
```bash
export PATH="/Users/admin/development/flutter/bin:$PATH"
cd /Users/admin/.gemini/antigravity/scratch/incline_app

flutter test test/e2e/e2e_features_test.dart
```

### Running Static Analysis
```bash
export PATH="/Users/admin/development/flutter/bin:$PATH"
cd /Users/admin/.gemini/antigravity/scratch/incline_app

flutter analyze
```

### Running the Full Regression Suite
```bash
export PATH="/Users/admin/development/flutter/bin:$PATH"
cd /Users/admin/.gemini/antigravity/scratch/incline_app

flutter test
```

---

## 6. Audit & Verification Standards

- **No Facade Tests**: Every test interacts with real models, genuine serialization logic, stateful services, or rendered widget trees.
- **Isolation**: Each test runs with isolated `SharedPreferences.setMockInitialValues` and independent test fixtures.
- **Zero Lint Violations**: Code must pass `flutter analyze` with 0 issues.
