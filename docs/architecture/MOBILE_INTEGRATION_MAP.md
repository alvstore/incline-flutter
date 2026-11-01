# INCLINE — Verified Mobile Integration Map

**Audit Date**: 26 October 2026  
**Repository**: `https://github.com/alvstore/incline.git`  
**Flutter Workspace**: `/Users/admin/.gemini/antigravity/scratch/incline_app`  
**Web Workspace**: `/Users/admin/.gemini/antigravity/scratch/incline`  
**Branch Scoping**: Incline Indiranagar (`11111111-1111-1111-1111-111111111111`)  
**Strict Policy**: Unverified items must be explicitly marked as `UNVERIFIED`. Never fabricate schemas.

---

## 1. Feature-to-Backend Verification Matrix

| Feature Domain | Web Source File | Flutter Source File | Supabase Table / View | RPC / Edge Function | Authorization / RLS | Verification Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Email Login** | `src/pages/Auth.tsx` | `lib/features/auth/login_screen.dart` | `auth.users` | GoTrue `signInWithPassword` | Public / Anon | **VERIFIED** |
| **Phone Login** | `src/components/auth/LoginForm.tsx` | `lib/core/services/authentication_service.dart` | `auth.users`, `public.profiles` | Edge Fn: `resolve-login-identifier` + RPC `resolve_email_by_phone` | Service Role inside Edge Function | **VERIFIED** |
| **WhatsApp OTP** | `src/components/registration/OtpStep.tsx` | `lib/core/services/authentication_service.dart` | `public.otp_verifications` | Edge Fn: `send-registration-otp` | Service Role inside Edge Function | **VERIFIED** |
| **Member Profile** | `src/hooks/useMemberData.ts` | `lib/features/profile/profile_screen.dart` | `public.members`, `public.branches` | PostgREST join on `user_id = auth.uid()` | RLS: `user_id = auth.uid()` | **VERIFIED** |
| **Trainer Info** | `src/lib/members/myTrainers.ts` | `lib/core/services/supabase_service.dart` | `public.trainers`, `public.profiles` | RPC: `get_my_trainers` | Security Definer | **VERIFIED** |
| **Active Membership**| `src/hooks/useMemberData.ts` | `lib/core/services/supabase_service.dart` | `public.memberships`, `membership_plans` | PostgREST query on `member_id` | RLS: `member_id IN (SELECT id FROM members WHERE user_id = auth.uid())` | **VERIFIED** |
| **Workout Plan** | `src/pages/MyWorkout.tsx` | `lib/features/workout/workout_screen.dart` | `public.member_fitness_plans` | PostgREST `.eq('plan_type','workout')` | RLS: Member self or assigned trainer | **VERIFIED** |
| **Diet Plan** | `src/pages/MyDiet.tsx` | `lib/features/diet/diet_view.dart` | `public.member_fitness_plans`, `diet_plans` | PostgREST `.eq('plan_type','diet')` | RLS: Member self or assigned trainer | **VERIFIED** |
| **Plan Completions**| `src/services/memberPlanProgressService.ts` | `lib/core/services/supabase_service.dart` | `member_workout_completions`, `member_meal_completions` | PostgREST Upsert | RLS: `member_id = auth.uid() member` | **VERIFIED** |
| **Manual Metrics** | `src/pages/MyProgress.tsx` | `lib/features/progress/progress_view.dart` | `public.member_measurements` | Storage: `createSignedUrl` (bucket: `member-measurements`) | RPC: `can_access_member_measurements` | **VERIFIED** |
| **3D Body Scans** | `src/pages/MyProgress.tsx` | `lib/features/progress/progress_view.dart` | `public.howbody_body_reports`, `howbody_posture_reports` | RPC: `howbody_scan_quota`, `get_howbody_public_report` | Security Definer | **VERIFIED** |
| **Class Schedule** | `src/services/classService.ts` | `lib/features/bookings/bookings_screen.dart` | `public.classes` | PostgREST query by `branch_id` | RLS: Public authenticated read | **VERIFIED** |
| **Book Class** | `src/services/classService.ts` | `lib/core/services/supabase_service.dart` | `public.class_bookings` | RPC: `book_class`, `validate_class_booking` | Security Definer / Member Auth | **VERIFIED** |
| **Cancel Class** | `src/services/classService.ts` | `lib/core/services/supabase_service.dart` | `public.class_bookings` | RPC: `cancel_class_booking` | Security Definer / Member Auth | **VERIFIED** |
| **Recovery Slots** | `src/services/benefitBookingService.ts`| `lib/features/bookings/bookings_screen.dart` | `public.benefit_slots` | RPC: `ensure_facility_slots` | Security Definer | **VERIFIED** |
| **Recovery Book** | `src/services/benefitBookingService.ts`| `lib/core/services/supabase_service.dart` | `public.benefit_bookings` | PostgREST Insert / RPC `cancel_facility_slot` | RLS: `member_id` ownership | **VERIFIED** |
| **Store Products** | `src/services/storeService.ts` | `lib/features/store/store_screen.dart` | `public.products` | PostgREST query `is_active = true` | RLS: Authenticated read | **VERIFIED** |
| **Referral List** | `src/services/referralService.ts` | `lib/features/profile/referral_card.dart` | `public.referrals`, `referral_rewards`| PostgREST query `referrer_member_id` | RLS: Member self read | **VERIFIED** |
| **Claim Reward** | `src/services/referralService.ts` | `lib/core/services/supabase_service.dart` | `public.referral_rewards` | RPC: `claim_referral_reward` (idempotent) | Security Definer | **VERIFIED** |
| **Notifications** | `src/services/notificationService.ts`| `lib/features/notifications/notifications_view.dart` | `public.notifications` | PostgREST `.eq('user_id', auth.uid())` | RLS: `user_id = auth.uid()` | **VERIFIED** |
| **HealthKit / Sync**| None (Client Scaffolding) | `lib/core/services/native_health_bridge.dart` | **NONE** | **NONE** | No backend sync schema exists | **UNVERIFIED / CLIENT-ONLY** |

---

## 2. Deep-Dive Domain Contracts

### 2.1 Authentication & WhatsApp OTP
- **Phone Login Contract**:
  - Endpoint: Edge Function `resolve-login-identifier`
  - Payload:
    ```json
    { "phone": "9876543210", "password": "UserSecretPassword" }
    ```
  - Response:
    ```json
    { "session": { "access_token": "...", "refresh_token": "...", "expires_in": 3600 } }
    ```
- **Registration OTP Contract**:
  - Endpoint: Edge Function `send-registration-otp`
  - Payload: `{ "phone": "9876543210" }`
  - Response: `{ "success": true, "message": "OTP sent via WhatsApp" }`
  - Rate Limiting: Max 3 requests per 10-minute window per phone (checked against `otp_verifications` table).

### 2.2 Member Identity & Branch Isolation
- Authenticated user UUID (`auth.uid()`) is never assumed to be the `member.id`.
- Mapping table: `public.members` where `user_id = auth.uid()`.
- Branch ID: Default branch UUID `11111111-1111-1111-1111-111111111111` (Incline Indiranagar).
- Assigned Trainer: Resolved via Security Definer RPC `get_my_trainers()`. Direct queries on `public.trainers` or `public.profiles` for trainer IDs fail under non-staff RLS.

### 2.3 Dynamic Diet & Workout Plans
- Table: `public.member_fitness_plans`
- Active Plan Filter:
  - `member_id = :memberId`
  - `plan_type = 'workout'` (or `'diet'`)
  - `valid_until IS NULL OR valid_until >= CURRENT_DATE`
  - Order: `created_at DESC LIMIT 1`
- **Fallback Rule**: If no row is returned, return `null`. Never substitute Mohit Gurjar's plan or bundled mock plans.
- **Empty State UX**:
  - Title: `No Active Workout Plan` / `No Active Diet Plan`
  - Subtitle: `Request a personalised plan from your trainer to take the guesswork out of training.`
  - Action: `Request Plan` / `Book PT Session` (if trainer assigned) or `Upgrade to 1:1`.

### 2.4 Body Assessments & HOWBODY Scans
- Table `public.member_measurements`:
  - Columns: `weight_kg`, `height_cm`, `body_fat_percentage`, `chest_cm`, `waist_cm`, `hips_cm`, `biceps_left_cm`, `biceps_right_cm`, `thighs_left_cm`, `thighs_right_cm`, `recorded_at`.
  - Photo URLs: Signed via `supabase.storage.from('member-measurements').createSignedUrl(path, 3600)`.
- Table `public.howbody_body_reports`:
  - Columns: `bmi`, `bmr`, `fat`, `smm`, `vfr`, `tbw`, `pbf`, `health_score`, `target_weight`, `test_time`.
- Table `public.howbody_posture_reports`:
  - Columns: `score`, `head_forward`, `high_low_shoulder`, `pelvis_forward`, `model_url`, `front_img`, `back_img`, `left_img`, `right_img`.
- Scan Quotas: RPC `howbody_scan_quota(_member_id, _kind)` where `_kind` is `'body'` or `'posture'`.

### 2.5 Classes & Group Bookings
- Schedule: `public.classes` where `branch_id = :branchId` and `scheduled_at >= NOW()`.
- Booking RPC: `book_class(_class_id => :classId, _member_id => :memberId)`
  - Returns: `{ "success": true, "booking_id": "..." }` or `{ "success": false, "error": "..." }`.
- Cancellation RPC: `cancel_class_booking(_booking_id => :bookingId, _reason => 'Cancelled by member')`
  - Restores class credit if cancelled before class starts (`class_scheduled_at > now()`) and promotes next waitlisted member. Returns `{ "success": true }` or `{ "success": false, "error": "..." }`.

### 2.6 Recovery Amenities (Steam, Sauna, Cold Plunge)
- Slot Generation: `public.ensure_facility_slots(p_branch_id, p_start_date, p_end_date)`
- Booking Table: `public.benefit_bookings` (`slot_id`, `member_id`, `membership_id`, `status`).
- Cancellation RPC: `public.cancel_facility_slot(p_booking_id => :bookingId, p_reason => 'Cancelled by member')`.
  - Enforces `benefit_settings.cancellation_deadline_minutes` per facility/branch (default 60 min). Automatically restores benefit usage. Rejects cancellations within deadline window with backend error. Zero dummy fallbacks or client-side penalty windows.

### 2.7 Referrals & Rewards
- Referral List: `public.referrals` (`referrer_member_id = :memberId`).
- Reward Claim: `public.claim_referral_reward(p_reward_id, p_member_id, p_idempotency_key)`.

### 2.8 Notifications
- Query: `public.notifications` (`user_id = auth.uid()`, ordered by `created_at DESC LIMIT 20`).
- Deduplication: Handled server-side by PostgreSQL trigger `notifications_dedupe_guard` (60-second window).

---

## 3. Unresolved Gaps & Unverified Systems

1. **Native HealthKit / Health Connect Cloud Sync**:
   - Status: `UNVERIFIED / CLIENT-ONLY`.
   - Evidence: `native_health_bridge.dart` exists in Flutter, but there are **no Supabase tables, migrations, or RPCs** for syncing Apple Health or Google Health Connect metrics to the Incline backend. Daily step counts and active calorie burn currently remain on-device only.
2. **Push Notifications Delivery (FCM / APNs)**:
   - Status: `UNVERIFIED (BACKEND DISPATCH CHANNEL PENDING)`.
   - Evidence: Web uses in-app polling (`notifications` table) and WhatsApp/Email via `dispatch-communication`. Native push token registration table (`user_push_tokens`) exists in migrations, but automated FCM dispatch triggers for mobile background push are unverified in production.
3. **Hardware Gate Pass (QR Code / NFC)**:
   - Status: `REMOVED / UNVERIFIED`.
   - Evidence: In accordance with `docs/member-mobile-pathway.md`, simulated gate QR passes were intentionally removed. Physical gym turnstiles use MIPS biometric face recognition, managed via Edge Function `sync-to-mips`.

---

## 4. Test Evidence & Parity Coverage

- Flutter Unit & Widget Tests:
  - `test/diet_feature_test.dart` (Empty state, macro breakdown, micronutrients, retry handler)
  - `test/workout_plan_feature_test.dart` (Empty state, exercise fields, coach notes, retry handler)
  - `test/bookings_suites_cold_plunge_test.dart` (Slot booking, capacity verification)
  - `test/payment_verification_wallet_coupon_test.dart` (Settlement rules, wallet deduction)
  - `test/profile_registration_details_card_test.dart` (Dynamic profile loading, branch isolation)
- Static Analysis: `flutter analyze` — 0 errors, 0 warnings.

---

## 5. Architectural References & Governance

- [Web-to-Mobile Parity Guide](file:///Users/admin/.gemini/antigravity/scratch/incline/docs/architecture/MOBILE_PARITY.md)
- [Supabase Backend Change Policy](file:///Users/admin/.gemini/antigravity/scratch/incline/docs/architecture/SUPABASE_CHANGE_POLICY.md)
- [Repository Governance Invariants](file:///Users/admin/.gemini/antigravity/scratch/incline/AGENTS.md)
- [Always-On Governance Rules](file:///Users/admin/.gemini/antigravity/scratch/incline/.agents/rules/incline-project-rules.md)
- [Flutter Engineering Invariants](file:///Users/admin/.gemini/antigravity/scratch/incline/.agents/rules/incline-flutter-invariants.md)
- [Flutter Client Architecture README](file:///Users/admin/.gemini/antigravity/scratch/incline/mobile/README.md)

