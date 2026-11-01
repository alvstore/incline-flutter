# INCLINE — Web-to-Mobile Parity Guide (Source of Truth)

**Document Version**: 1.0.0  
**Target Repository**: `https://github.com/alvstore/incline.git`  
**Mobile Client**: Flutter (`mobile/` -> `../incline_app`)  
**Web Client**: React + Vite (`src/`)  
**Backend**: Supabase (PostgreSQL, PostgREST, GoTrue Auth, Edge Functions)

---

## 1. Executive Parity Principles

1. **Client Equivalence**: The Flutter mobile application is a native client to the existing Incline gym management platform. It must consume the exact same database tables, RPCs, Edge Functions, and Row Level Security (RLS) policies as the production web application (`theincline.in`).
2. **Zero Commercial Pricing in Upgrade Workflows**: When a member requests a Personal Training (1:1) upgrade or plan consultation, the app registers a request with the front desk / lead trainer. Commercial prices must never be displayed in mobile upgrade dialogs.
3. **No Embedded Webviews as Screen Substitutes**: Web features must be rendered natively in Flutter using shared design tokens, atomic animations (`DumbbellLoader`), and Flutter widgets.
4. **Member Branch Isolation**: Every data query must respect the member's home branch (`11111111-1111-1111-1111-111111111111` for Incline Indiranagar).

---

## 2. Authentication & Identity Mapping

### 2.1 Web Implementation Reference
- Route: `/auth` ([`src/pages/Auth.tsx`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/pages/Auth.tsx))
- Context: [`src/contexts/AuthContext.tsx`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/contexts/AuthContext.tsx)
- Login Form: [`src/components/auth/LoginForm.tsx`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/components/auth/LoginForm.tsx)
- Identifier Parser: [`src/lib/auth/identifier.ts`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/lib/auth/identifier.ts)

### 2.2 Sign-in Methods
1. **Email + Password**:
   - Web: `supabase.auth.signInWithPassword({ email, password })`
   - Mobile: Same call via Supabase Flutter SDK.
2. **Indian Mobile (10-Digit) + Password**:
   - Web: Calls Edge Function `resolve-login-identifier` with `{ phone: "9876543210", password: "..." }`.
   - The Edge Function resolves the user's primary email via internal security definer RPC `resolve_email_by_phone`, authenticates with GoTrue, and returns `{ session: { access_token, refresh_token } }`.
   - Web sets session via `supabase.auth.setSession()`.
   - Mobile: Must call the exact same Edge Function `resolve-login-identifier` and initialize the local session with returned tokens.
3. **WhatsApp OTP Registration**:
   - Edge Function: `send-registration-otp` sends 6-digit cryptographic OTP via WhatsApp.
   - Verification completes registration via `register-member` Edge Function.

### 2.3 User-to-Member Resolution
- The authenticated GoTrue user is resolved via `supabase.auth.getUser()` -> `user.id`.
- The member record is retrieved by joining `members` on `user_id = user.id`:
  ```sql
  SELECT m.*, b.id, b.name, b.code 
  FROM public.members m
  JOIN public.branches b ON m.branch_id = b.id
  WHERE m.user_id = auth.uid()
  LIMIT 1;
  ```
- **Assigned Trainer Resolution**: Members do not have direct RLS table read on `trainers` or trainer `profiles`. Trainer identity and profile info are fetched via the security-definer RPC:
  ```sql
  SELECT * FROM public.get_my_trainers();
  ```
  This returns `trainer_id`, `full_name`, `avatar_url`, `trainer_code`, `specializations`, and `relation`.

---

## 3. Membership & Account State Parity

### 3.1 Web Implementation Reference
- Hook: [`src/hooks/useMemberData.ts`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/hooks/useMemberData.ts)
- Profile Page: [`src/pages/MemberProfile.tsx`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/pages/MemberProfile.tsx)

### 3.2 Membership States
1. **Active**: `memberships.status = 'active'`, `end_date >= CURRENT_DATE`.
2. **Frozen**: `memberships.status = 'frozen'`.
3. **Scheduled**: `memberships.status = 'pending'`, `start_date > CURRENT_DATE`.
4. **Expired**: `end_date < CURRENT_DATE`.
5. **No Membership**: No rows returned.

### 3.3 Days Remaining Calculation
```typescript
const daysRemaining = activeMembership
  ? Math.max(0, Math.ceil((new Date(activeMembership.end_date).getTime() - Date.now()) / (1000 * 60 * 60 * 24)))
  : 0;
```

---

## 4. Diet & Workout Plans (Strict Dynamic Retrieval)

### 4.1 Web Implementation Reference
- Workout: [`src/pages/MyWorkout.tsx`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/pages/MyWorkout.tsx)
- Diet: [`src/pages/MyDiet.tsx`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/pages/MyDiet.tsx)
- Normalizer: [`src/lib/planNormalizer.ts`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/lib/planNormalizer.ts)
- Types: [`src/types/fitnessPlan.ts`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/types/fitnessPlan.ts)

### 4.2 Query Contracts
- **Workout Plan**:
  ```sql
  SELECT * FROM public.member_fitness_plans
  WHERE member_id = :memberId
    AND plan_type = 'workout'
    AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
  ORDER BY created_at DESC
  LIMIT 1;
  ```
- **Diet Plan**:
  ```sql
  SELECT * FROM public.member_fitness_plans
  WHERE member_id = :memberId
    AND plan_type = 'diet'
    AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
  ORDER BY created_at DESC
  LIMIT 1;
  ```
  *(Legacy fallback table `diet_plans` where `is_active = true` is supported read-only).*

### 4.3 Authentic Empty States
When `data == null`:
- **Workout**:
  - Title: `No Active Workout Plan`
  - Subtitle: `Request a personalised plan from your trainer to take the guesswork out of training.`
  - Primary Action: `Request Workout Plan` (opens request drawer/modal).
  - Secondary Action: `Book PT Session` (if assigned trainer exists) or `Upgrade to 1:1`.
  - Tips Section: Displays 6 curated workout tips.
- **Diet**:
  - Title: `No Active Diet Plan`
  - Subtitle: `You don't have a personalised diet plan yet. Request one from your trainer to get started.`
  - Primary Action: `Request Diet Plan`.
  - Secondary Action: `Book PT Session` (if assigned trainer exists).
  - Tips Section: Displays 6 curated nutrition tips.

**Strict Invariant**: Under no circumstances may Mohit Gurjar's records or hardcoded mock plans be displayed as a fallback when `data == null`.

### 4.4 Plan Progress Tracking
- Workout exercise completions are logged to `public.member_workout_completions`.
- Meal slot completions are logged to `public.member_meal_completions`.

---

## 5. Body Assessments & Fitness Metrics

### 5.1 Web Implementation Reference
- Page: [`src/pages/MyProgress.tsx`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/pages/MyProgress.tsx)
- Hook: [`src/hooks/useHowbodyReports.ts`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/hooks/useHowbodyReports.ts)
- Photo Signing: [`src/lib/measurements/photoSigning.ts`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/lib/measurements/photoSigning.ts)

### 5.2 Manual Measurements (`public.member_measurements`)
- Columns: `weight_kg`, `height_cm`, `body_fat_percentage`, `chest_cm`, `waist_cm`, `hips_cm`, `biceps_left_cm`, `biceps_right_cm`, `thighs_left_cm`, `thighs_right_cm`, `recorded_at`.
- Photos: Private progress photos stored in Supabase storage bucket `member-measurements`. URLs are signed client-side via `supabase.storage.from('member-measurements').createSignedUrl(path, 3600)` with a 25-minute refresh interval.

### 5.3 3D Scanner & Posture Reports (HOWBODY)
- Body Reports: `public.howbody_body_reports` (`bmi`, `bmr`, `fat`, `smm`, `vfr`, `tbw`, `pbf`, `health_score`, `target_weight`).
- Posture Reports: `public.howbody_posture_reports` (`score`, `head_forward`, `high_low_shoulder`, `pelvis_forward`, `model_url`, `front_img`, `back_img`, `left_img`, `right_img`).
- Scan Quota: Checked via RPC:
  ```sql
  SELECT * FROM public.howbody_scan_quota(_member_id => :memberId, _kind => 'body');
  SELECT * FROM public.howbody_scan_quota(_member_id => :memberId, _kind => 'posture');
  ```

---

## 6. Group Classes & Class Bookings

### 6.1 Web Implementation Reference
- Page: `src/pages/MemberClassBooking.tsx`, `src/pages/Book.tsx`
- Service: [`src/services/classService.ts`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/services/classService.ts)

### 6.2 Contracts & RPCs
- **Fetch Schedule**:
  ```sql
  SELECT c.*, t.full_name AS trainer_name
  FROM public.classes c
  WHERE c.branch_id = :branchId AND c.scheduled_at >= NOW()
  ORDER BY c.scheduled_at ASC;
  ```
- **Book Class**:
  ```sql
  SELECT * FROM public.book_class(_class_id => :classId, _member_id => :memberId);
  ```
- **Validate Booking**:
  ```sql
  SELECT * FROM public.validate_class_booking(_class_id => :classId, _member_id => :memberId);
  ```
- **Waitlist**:
  ```sql
  SELECT * FROM public.add_to_waitlist(_class_id => :classId, _member_id => :memberId);
  ```
- **Cancel Booking**:
  ```sql
  SELECT * FROM public.cancel_class_booking(_booking_id => :bookingId, _reason => 'Cancelled by member');
  ```
  - Authoritative Logic: Enforces member ownership. If cancelled before class start time (`class_scheduled_at > now()`), the class credit is automatically refunded and the highest-priority waitlisted member is promoted. No client-side deadline assumptions may override this RPC.

---

## 7. Recovery Amenities (Steam, Sauna, Cold Plunge)

### 7.1 Web Implementation Reference
- Service: [`src/services/benefitBookingService.ts`](file:///Users/admin/.gemini/antigravity/scratch/incline/src/services/benefitBookingService.ts)

### 7.2 Facility Slots & Bookings
- **Slot Generation RPC**:
  ```sql
  SELECT public.ensure_facility_slots(
    p_branch_id => :branchId,
    p_start_date => :startDate,
    p_end_date => :endDate
  );
  ```
- **Book Slot**:
  ```sql
  INSERT INTO public.benefit_bookings (slot_id, member_id, membership_id, status, notes)
  VALUES (:slotId, :memberId, :membershipId, 'booked', :notes);
  ```
- **Cancel Facility Slot RPC**:
  ```sql
  SELECT public.cancel_facility_slot(p_booking_id => :bookingId, p_reason => 'Cancelled by member');
  ```
  - Authoritative Logic: Dynamically enforces cancellation deadline configured in `benefit_settings.cancellation_deadline_minutes` per facility/branch (defaults to 60 minutes if unset). Returns `{ success: false, error: 'Cancellation window closed...' }` if within window. When successful, automatically refunds benefit usage.
  - Invariant: Zero invented 2-hour penalty notices or dummy fallback reservations (`res_sample_01`, etc.) in mobile. All cancellation terms reflect backend rules.

---

## 8. Store, Referrals & Notifications

### 8.1 Store
- Products: `SELECT * FROM public.products WHERE is_active = true AND (branch_id = :branchId OR branch_id IS NULL)`.

### 8.2 Referrals
- Referral History: `SELECT * FROM public.referrals WHERE referrer_member_id = :memberId`.
- Claim Reward RPC:
  ```sql
  SELECT public.claim_referral_reward(
    p_reward_id => :rewardId,
    p_member_id => :memberId,
    p_idempotency_key => :idempotencyKey
  );
  ```

### 8.3 Notifications
- Query: `SELECT * FROM public.notifications WHERE user_id = :userId ORDER BY created_at DESC LIMIT 20`.
- Mark Read: `UPDATE public.notifications SET is_read = true WHERE id = :id`.

---

## 9. Architectural Boundaries & System Topology

To preserve platform stability, each layer in the Incline ecosystem has strict functional boundaries:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER (PRESENTATION)                     │
│                                                                        │
│   Web Application (React 18 + Vite)     Mobile Application (Flutter)   │
│   - Administrative portal               - Member companion             │
│   - Trainer management console          - Personal fitness tracking    │
│   - Front-desk operations               - Dynamic workout / diet plans │
│   - MIPS biometric face-scan CRM        - Class & recovery bookings    │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
               HTTPS / WSS / JWT     │ PostgREST / GoTrue / Edge Fns
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      SERVERLESS & API GATEWAY                          │
│                                                                        │
│   Supabase Edge Functions (Deno / TypeScript)                          │
│   - `resolve-login-identifier`: Phone + password GoTrue resolver       │
│   - `send-registration-otp`: WhatsApp cryptographic OTP engine        │
│   - `register-member`: Atomic member registration transaction          │
│   - `mips-*`: Hardware middleware webhook proxy & sync                 │
│   - `push-notifications`: FCM dispatch for mobile alerts               │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     DATABASE LAYER (BUSINESS ENGINE)                   │
│                                                                        │
│   PostgreSQL 15+ & Row Level Security (Supabase)                       │
│   - Authoritative Tables: `members`, `memberships`, `fitness_plans`... │
│   - Security Definer RPCs: `book_class`, `cancel_facility_slot`...     │
│   - Trigger Engines: Quota counters, audit logs, auto-timestamps       │
│   - Identity: `auth.users` -> `public.members.user_id = auth.uid()`    │
│   - Storage Buckets: `member-measurements` (private), `template-media` │
└────────────────────────────────────────────────────────────────────────┘
```

### 9.1 Boundary Invariants
1. **Database Owns Business Rules & Validation**:
   - Booking quota calculation, cancellation deadlines, attendance confirmation, waitlist promotions, and referral rewards belong exclusively inside PostgreSQL RPCs and triggers.
   - Neither the web nor Flutter client may implement independent client-side validation that overrides database rejections.
2. **Edge Functions Own Third-Party & Privileged Integrations**:
   - Sending WhatsApp messages via external SMS/WhatsApp gateways.
   - Interfacing with MIPS hardware face-recognition devices.
   - Resolving phone numbers to email identifiers with `service_role` privileges.
   - Client applications never hold service-role keys or direct vendor API secrets.
3. **Clients Own Native UX & State Presentation**:
   - The Flutter mobile client provides an elevated, 60/120 FPS tactile experience with haptics, `DumbbellLoader`, bento layouts, and cached offline states.
   - Mobile client UI improvements must never bypass server-side rules.

---

## 10. Developer & Agent Implementation Workflow

When an engineer or AI agent implements or fixes any feature:

```
Step 1: Reconnaissance
  ├─ Inspect corresponding web screen (src/pages/..., src/components/...)
  └─ Audit database schema, RPCs, and RLS (invoke `incline-supabase-audit`)
Step 2: Parity Mapping
  ├─ Trace 8-stage evidence chain (invoke `incline-web-mobile-parity`)
  └─ Verify branch scoping (Indiranagar: 11111111-1111-1111-1111-111111111111)
Step 3: Implementation
  ├─ Follow luxury dark design system & tokens (invoke `incline-mobile-design`)
  ├─ Embed `DumbbellLoader` and authentic empty states (no fake plans)
  └─ Call authoritative Supabase RPCs (no direct table writes bypassing RPCs)
Step 4: Change Verification
  ├─ Run static analysis: `flutter analyze` (Must pass with 0 issues)
  ├─ Run automated tests: `flutter test` (All tests must pass)
  ├─ If hardware connected: deploy debug APK and capture screenshot via ADB
  └─ Output structured report (invoke `incline-change-verification`)
```

---

## 11. Cross-References & Policy Documentation

- [Repository Governance & Invariants](file:///Users/admin/.gemini/antigravity/scratch/incline/AGENTS.md)
- [Always-On Project Rules](file:///Users/admin/.gemini/antigravity/scratch/incline/.agents/rules/incline-project-rules.md)
- [Flutter Engineering Invariants](file:///Users/admin/.gemini/antigravity/scratch/incline/.agents/rules/incline-flutter-invariants.md)
- [Verified Mobile Integration Map](file:///Users/admin/.gemini/antigravity/scratch/incline/docs/architecture/MOBILE_INTEGRATION_MAP.md)
- [Supabase Backend Change Policy](file:///Users/admin/.gemini/antigravity/scratch/incline/docs/architecture/SUPABASE_CHANGE_POLICY.md)
- [Flutter Client Architecture README](file:///Users/admin/.gemini/antigravity/scratch/incline/mobile/README.md)

