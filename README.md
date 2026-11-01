# INCLINE Member Mobile Application (Flutter)

Welcome to the native mobile member application for Incline (`com.incline.app.incline_app`), built with Flutter.

---

## 1. Core Engineering Principles

1. **Native Client to Existing Incline Platform**: The mobile application is a native client communicating with the production Incline Supabase backend. It consumes the same database tables, RPCs, Edge Functions, and Row Level Security (RLS) policies as the official web app (`theincline.in`).
2. **Dynamic Member Fitness Data**: Every authenticated member dynamically resolves their own assigned workout plan, diet plan, and assessment metrics from Supabase.
3. **No Hardcoded Member Identifiers or Fallbacks**: Mohit Gurjar's records are reference examples only. Never hardcode his UUID (`f07d801c-6892-475c-a08f-b7e70ec5a394`), profile metrics, or plans into application code.
4. **Authentic Empty States**: If a member has no assigned plan, the app must render the authentic Empty State matching the web app ("No Active Workout Plan" / "No Active Diet Plan") with action buttons for requesting a plan or booking a 1:1 PT session.
5. **Zero Commercial Pricing in Upgrade Sheets**: Requests to upgrade to 1:1 Personal Training register a lead with the front desk / lead trainer. Commercial prices must never be displayed in mobile upgrade dialogs.
6. **Brand Tokens & Visual Polish**: Dark Luxury aesthetics with Incline Gold (`#CCA855`), Deep Background (`#0A0A0A`), Elevated Card Surface (`#141414`), and animated `DumbbellLoader`.

---

## 2. Prerequisites & Environment Setup

- **Flutter SDK**: `>= 3.19.0` (Active on system at `/Users/admin/development/flutter/bin/flutter`)
- **Dart SDK**: `>= 3.3.0`
- **Android SDK**: API Level 34 (Target), API 24 (Minimum)
- **Connected Hardware**: Physical Samsung Galaxy S10 (`RF8M833Y5MK` / `SM-G973N`, Android 12) or Android Simulator / iOS Simulator.
- **Backend Configuration**: Supabase URL and Public Anon Key configured via `lib/core/config/env_config.dart`. Never commit service role keys.

---

## 3. Useful Commands

### 3.1 Static Analysis & Linting
Run static analysis before every commit or pull request. The codebase must maintain **0 issues**:
```bash
flutter analyze
```

### 3.2 Automated Tests
Run unit, widget, and integration tests:
```bash
# Run all unit and feature tests
flutter test

# Run specific feature tests
flutter test test/workout_plan_feature_test.dart test/diet_feature_test.dart
```

### 3.3 Build & Physical Device Deployment
Deploy directly to the connected Samsung Galaxy S10:
```bash
# Build debug APK
flutter build apk --debug

# Install to physical device
adb -s RF8M833Y5MK install -r build/app/outputs/flutter-apk/app-debug.apk

# Launch MainActivity
adb -s RF8M833Y5MK shell am start -n com.incline.app.incline_app/com.incline.app.incline_app.MainActivity

# Capture screenshot for visual verification
adb -s RF8M833Y5MK exec-out screencap -p > verification_screenshot.png
```

---

## 4. Architecture & Data Flow

```
lib/
├── core/
│   ├── config/         # Environment, URLs, public keys (EnvConfig)
│   ├── models/         # Strongly-typed models (Member, WorkoutPlan, DietPlan, etc.)
│   ├── services/       # SupabaseService, AuthenticationService, OfflineSyncService
│   └── theme/          # AppTheme, InclineColors, InclineTypography
├── features/
│   ├── auth/           # Login, WhatsApp OTP, password recovery
│   ├── bookings/       # Classes, recovery amenities (steam, sauna, cold plunge)
│   ├── dashboard/      # Member home dashboard, quick stats, active membership
│   ├── diet/           # Diet plan viewer, meal completions, macro/micronutrients
│   ├── onboarding/     # Permissions, initial member welcome
│   ├── profile/        # Member profile, dossier, invoices, referrals, feedback
│   ├── progress/       # Biometrics, HOWBODY 3D scan reports, posture analysis
│   └── workout/        # Workout plan viewer, session tracker, coach cues
└── main.dart           # App entrypoint, Supabase initialization, routing
```

### 4.1 Authentication & Session Management
- **Phone Login**: Invokes Supabase Edge Function `resolve-login-identifier` with 10-digit mobile number and password. GoTrue session is saved into secure device storage.
- **Email Login**: Direct call to `Supabase.instance.client.auth.signInWithPassword`.
- **Session Lifecycle**: On logout, `SupabaseService.signOut()` clears all cached member plans, biometrics, and offline sync caches to prevent data leakage across accounts.

### 4.2 Dynamic Plan Retrieval
- Queries `public.member_fitness_plans` filtering by `member_id = member.id`, `plan_type = 'workout'|'diet'`, and `.or('valid_until.is.null,valid_until.gte.$todayIso')`.
- Returns `null` if no active plan is found, which triggers the authentic Empty State.
- Plan completions are logged via upserts to `public.member_workout_completions` and `public.member_meal_completions`.

---

## 5. Security Invariants

1. **Zero Privileged Secrets**: The mobile application must only contain public client keys (`SUPABASE_ANON_KEY`, public Razorpay key).
2. **Branch Scoping**: All member actions are scoped to Incline Indiranagar (`branch_id = 11111111-1111-1111-1111-111111111111`).
3. **RLS Preservation**: Never attempt to bypass Row Level Security. Elevated queries (e.g. trainer profile lookup) are performed via authorized Security Definer RPCs (e.g. `get_my_trainers`).

---

## 6. Engineering Governance & Reusable Skills

All engineers and AI agents operating in the Flutter mobile application must adhere to the Incline governance framework:

### 6.1 Persistent Project Rules
- [Flutter App Rules & Governance (AGENTS.md)](file:///Users/admin/.gemini/antigravity/scratch/incline_app/AGENTS.md)
- [Always-On Governance Rules](file:///Users/admin/.gemini/antigravity/scratch/incline_app/.agents/rules/incline-project-rules.md)
- [Flutter Mobile Invariants](file:///Users/admin/.gemini/antigravity/scratch/incline_app/.agents/rules/incline-flutter-invariants.md)

### 6.2 Agent Skills (.agents/skills/)
1. **[incline-mobile-design](file:///Users/admin/.gemini/antigravity/scratch/incline_app/.agents/skills/incline-mobile-design/SKILL.md)**: Guidelines for the luxury dark-slate/gold design system, typography (Outfit & Inter), button press/scale micro-animations, bottom navigation indicators, `DumbbellLoader`, skeleton shimmer, haptic feedback, and accessibility ($\ge 44\times 44$ tap targets, $\ge 4.5:1$ contrast).
2. **[incline-supabase-audit](file:///Users/admin/.gemini/antigravity/scratch/incline_app/.agents/skills/incline-supabase-audit/SKILL.md)**: Mandatory 11-step read-only audit procedure before modifying queries, tables, RPCs, RLS policies, or Edge Functions.
3. **[incline-web-mobile-parity](file:///Users/admin/.gemini/antigravity/scratch/incline_app/.agents/skills/incline-web-mobile-parity/SKILL.md)**: Enforces the 8-stage evidence chain from existing web screen to Flutter widget and backend RPC. Prohibits invented endpoints and duplicate engines.
4. **[incline-change-verification](file:///Users/admin/.gemini/antigravity/scratch/incline_app/.agents/skills/incline-change-verification/SKILL.md)**: Enforces the 8-step verification pipeline, zero-issue `flutter analyze` policy, automated test suite execution, and structured reporting.
5. **[ui-ux-pro-max](file:///Users/admin/.gemini/antigravity/scratch/incline_app/.agents/skills/ui-ux-pro-max/SKILL.md)**: Searchable design intelligence CLI (`search.py`).

### 6.3 Architecture Documentation (docs/architecture/)
- [Web-to-Mobile Parity Guide](file:///Users/admin/.gemini/antigravity/scratch/incline_app/docs/architecture/MOBILE_PARITY.md)
- [Verified Mobile Integration Map](file:///Users/admin/.gemini/antigravity/scratch/incline_app/docs/architecture/MOBILE_INTEGRATION_MAP.md)
- [Supabase Backend Change Policy](file:///Users/admin/.gemini/antigravity/scratch/incline_app/docs/architecture/SUPABASE_CHANGE_POLICY.md)


