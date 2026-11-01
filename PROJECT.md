# Project: Incline App — Exercise Video Toggle & HOWBODY Progress Scanner

## Architecture
The Incline mobile client (`incline_app`) is built with Flutter 3.27.4, Dart 3.6.2, and Android API 34.
- **Routing**: Declarative navigation via `go_router: ^16.1.0` with shell navigation hosting `AppScaffoldShell` and `FloatingCapsuleNavBar`. Progress is hosted as Tab 2 within `WorkoutScreen` (`AppRoutePaths.workout?tab=2`).
- **State & Service Layer**: Singleton domain services (`SupabaseService`, `OfflineSyncService`, `SessionManager`, `WatchSyncService`) with disk persistence (`SharedPreferences`) and memory caching.
- **Backend & Database**: Production Supabase backend (`iyqqpbvnszyrrgerniog.supabase.co`) with Edge Functions (`howbody-bind-user`, `resolve-login-identifier`), PostgreSQL tables (`member_fitness_plans`, `howbody_devices`, `howbody_scan_sessions`, `howbody_body_reports`, `howbody_posture_reports`), and bucket storage (`workout-videos`).
- **Hardware Integration**: Camera hardware accessed via `mobile_scanner: ^6.0.4` for HUD reticle QR code scanning, pairing members with physical Incline 3D Body Scanners.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Exercise Media Model & Storage URL Normalization | Parse `imageUrl` and normalize relative video paths to Supabase `workout-videos` storage endpoint | M1 | Survey 1 |
| 2 | Exercise Video Demos Preference & State | Persist `'incline_exercise_video_demos_enabled'` in `SharedPreferences` (default `false` / OFF) | M1 | Survey 1 |
| 3 | Workout Screen Demos Toggle Switch | Branded "Demos" toggle switch row in `WorkoutScreen` above exercise list | M1 | Survey 1 |
| 4 | Execution Sheet Media Switch & Conditional Display | In-session quick toggle in `WorkoutExecutionSheet` and conditional render in `AnimatedExerciseVisualizer` (video demo card vs static guide/image) | M1 | Survey 1 |
| 5 | Mobile Scanner Dependency & Camera Configuration | Add `mobile_scanner: ^6.0.4` to `pubspec.yaml` with Android/iOS permissions | M2 | Survey 2 |
| 6 | HOWBODY QR Scanner Viewfinder Sheet | Modal bottom sheet with camera HUD reticle, torch/flip controls, and QR parser (`equipmentNo`, `scanId`, `kind`) | M2 | Survey 2 |
| 7 | HOWBODY Device Linking Sheet & Unit Converter | Bottom sheet with device label lookup, scan kind toggle, height converter (`cm` ⇄ `ft/in`), and bind action | M2 | Survey 2 |
| 8 | Scanner Session Polling & Report Launch | Poll `howbody_scan_sessions` table until completion, then open report in `InBodyScanSheet` | M2 | Survey 2 |
| 9 | Progress Screen Scanner Entry Points | High-visibility action buttons on Progress View empty card (`_buildEmptyAssessmentCard`), 3D Assessment card, and `InBodyScanSheet` | M2 | Survey 2 |
| 10 | Universal Deep Links for OS Camera Scanning | Route `/scan-login` and `/howbody-login` in `DeepLinkService` to directly launch the link sheet | M2 | Survey 2 |
| 11 | Comprehensive E2E & Regression Test Suite | 4-tier opaque-box test suite verifying all 10 features and ensuring 113 existing tests pass regression-free | M3 | Survey 3 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exercise Video Fetch & Toggle UI | Models, `OfflineSyncService`, `WorkoutScreen` toggle, `AnimatedExerciseVisualizer`, `WorkoutExecutionSheet` | none | DONE |
| 2 | HOWBODY Scanner Camera & Progress Linking | `pubspec.yaml`, `SupabaseService`, `DeepLinkService`, `HowbodyQrScannerSheet`, `HowbodyLinkSheet`, `WorkoutScreen` Progress entry points | none | DONE |
| 3 | Final E2E Test Suite & Adversarial Hardening | Pass 100% of E2E tests, full regression run (250+ tests), static analysis (0 issues) | M1, M2 | DONE |

## Interface Contracts
### Exercise Media & Preference Contract
- `WorkoutExercise`:
  - `final String? imageUrl`
  - `final String? videoUrl` (normalized to full Supabase storage URL when relative)
- `OfflineSyncService`:
  - `Future<bool> getExerciseVideoDemosEnabled()` (default `false`)
  - `Future<void> setExerciseVideoDemosEnabled(bool enabled)`
- `AnimatedExerciseVisualizer`:
  - `AnimatedExerciseVisualizer({required WorkoutExercise exercise, required bool showVideo, ...})`

### HOWBODY Scanner Contract
- QR Code URL Schema:
  - Formats: `https://inclinegym.com/scan-login?equipmentNo={no}&scanId={id}&kind={kind}` or `https://inclinegym.com/howbody-login?...` or raw query string `equipmentNo=...&scanId=...`
  - Extracted fields: `equipmentNo` (String), `scanId` (String), `kind` (String: `'body'` or `'posture'`)
- `SupabaseService`:
  - `Future<HowbodyBindResult> bindHowbodyScanner({required String equipmentNo, required String scanId, required String kind, required double heightCm})`
  - `Future<HowbodySessionStatus> checkHowbodySessionStatus(String scanId)`
  - `Future<String?> fetchHowbodyDeviceLabel(String equipmentNo)`

## Code Layout
- `lib/core/models/models.dart`: Models layer (`WorkoutExercise`)
- `lib/core/services/offline_sync_service.dart`: Local preference & offline plan cache
- `lib/core/services/supabase_service.dart`: HOWBODY binding & session polling methods
- `lib/core/services/deep_link_service.dart`: Scanner deep link routing
- `lib/features/workout/workout_screen.dart`: Exercise demos switch row & Progress screen scanner buttons
- `lib/features/workout/workout_execution_sheet.dart`: In-session media toggle icon
- `lib/features/workout/animated_exercise_visualizer.dart`: Conditional video player card vs static guide
- `lib/features/progress/components/howbody_qr_scanner_sheet.dart`: QR viewfinder modal
- `lib/features/progress/components/howbody_link_sheet.dart`: Scanner binding & polling sheet
- `lib/features/home/components/inbody_scan_sheet.dart`: Quick-action scan pill & report viewer
- `test/`: Unit, widget, and E2E test suites
