# INCLINE — Engineering Governance & Repository Instructions

These instructions govern all AI coding agents, pair programmers, and engineers working in this repository (`https://github.com/alvstore/incline.git`).
This repository contains the authoritative Incline web application, Supabase backend configuration (migrations, schema, Edge Functions), and the native Flutter mobile client (`mobile/` -> `../incline_app`).

---

## 1. Six Mandatory Governance Pillars

Every task in this repository must strictly adhere to these six invariants:

### 1.1 Source-of-Truth Rule
- The existing Incline web application (`src/`), actual Supabase database schema, verified database functions (RPCs), Edge Functions (`supabase/functions/`), and established business workflows are authoritative.
- Never independently invent a replacement architecture, parallel schema, or duplicate logic when the existing implementation already provides the required behavior.
- The Flutter mobile application is a native client of the existing Incline platform, not an independent replacement system.

### 1.2 Audit-Before-Change Rule
Before any code change involving an existing feature:
1. **Inspect** the current web implementation and identify all source files (`src/pages/`, `src/components/`).
2. **Trace** its data flow through hooks (`src/hooks/`) and client services (`src/services/`) to the backend.
3. **Inspect** relevant database tables, columns, relationships, RLS policies, RPCs, triggers, and Edge Functions in `supabase/migrations/` and `src/integrations/supabase/types.ts`.
4. **Identify** downstream dependencies, web callers, mobile callers, and side effects.
5. **Determine** the smallest safe change that accomplishes the requirement without altering unrelated behavior.
6. **Establish** relevant regression tests or verification steps before writing code.
*Never begin code modifications until this audit is complete. Request explicit approval before destructive changes, schema migrations, production writes, or changes to established backend contracts.*

### 1.3 Supabase-First Rule
- Use the existing Supabase project, authenticated sessions, repositories, RPCs, Edge Functions, and server-side operations.
- Do not create a second backend, duplicate booking engines, or duplicate business logic.
- Inspect all relevant schema definitions, foreign keys, constraints, indexes, grants, RLS policies, triggers, functions, and migrations before changing backend behavior.
- Do not assume the agent has live direct SQL access. When direct database connection is unavailable, inspect checked-in migrations (`supabase/migrations/`), schema definitions (`src/integrations/supabase/types.ts`), application code, Edge Functions, and tests. Clearly label any remaining uncertainty.
- **Strict Security**: Never use a production `service_role` key in Flutter or client-facing code. Never expose privileged credentials.

### 1.4 RPC Preservation Rule
- Existing database functions (RPCs) are integral parts of the application's business, auditing, and security contracts.
- Before modifying or calling an RPC, inspect:
  - Its complete SQL implementation and callers.
  - Its parameters, return shape, grants, and execution privileges (`SECURITY DEFINER` vs `INVOKER`).
  - Its `search_path`, authorization guards, branch scoping, and transaction semantics.
  - Dependent functions, triggers, RLS policies, Edge Functions, and web services.
- Always prefer calling the existing RPC from Flutter through the authenticated Supabase client (`supabase.rpc(...)`).
- Preserve the existing RPC contract unless a documented, approved requirement proves a change is necessary.
- **Never bypass an RPC's validation by writing directly to its underlying tables.** (e.g. Always use `book_class`, `cancel_class_booking`, `ensure_facility_slots`, `cancel_facility_slot`).
- Never replace an atomic or audited server-side operation with client-side logic.
- Any required RPC modification must be explicitly justified, reviewed for security and backward compatibility, and accompanied by regression tests.

### 1.5 Dynamic Member-Data Rule
- Member profiles, membership details, assigned diet plans, workout plans, assessments, measurements, bookings, and referrals must be dynamically resolved from the authenticated member's actual backend records (`members.user_id = auth.uid()`).
- **Never hardcode Mohit Gurjar or any other member**, a fixed member UUID (`f07d801c-6892-475c-a08f-b7e70ec5a394`), plans, assessment values, email, phone number, or production API responses into application code or default fallbacks.
- Never fetch all members' private data and filter it locally on the client. Preserve member isolation, branch scoping, and RLS.
- **Authentic Empty States**: If no plan, scan, or reservation exists for the member, render the authentic empty state (`No Active Workout Plan` / `No Active Diet Plan` / `No 3D Body Scan on File`) matching the web app. Never substitute sample data or hardcoded fallback programs in production.

### 1.6 Existing Web Behavior Rule
- Before creating or modifying any mobile feature, inspect the equivalent web feature and document:
  - Web source files (`src/pages/...`, `src/components/...`).
  - Service or hook (`src/hooks/...`, `src/services/...`).
  - Actual backend objects (tables, views, RPCs, Edge Functions).
  - Authorization and business rules (RLS, role checks, branch scoping).
  - Request and response contracts.
  - Error handling, empty states, and side effects.
- The Flutter UI may be native, fluid, and visually elevated, but the underlying business behavior, validation, and contracts must remain 100% consistent with the web application.

---

## 2. Incline Platform Specific Rules

1. **Branch Scoping**: All member activity belongs to the member's home branch (default: Incline Indiranagar `11111111-1111-1111-1111-111111111111`). All queries filtering by branch must preserve this scoping.
2. **Zero Commercial Pricing in Upgrade Workflows**: When a member requests a Personal Training (1:1) upgrade or plan consultation, the app registers a request with the front desk / lead trainer via `public.tasks` or `public.approval_requests`. Commercial prices must never be hardcoded or displayed in mobile upgrade dialogs.
3. **No Embedded Webviews as Screen Substitutes**: Web features must be rendered natively in Flutter using shared design tokens, atomic animations (`DumbbellLoader`), and Flutter widgets.
4. **Backend-Enforced Cancellation Policies**: Never hardcode arbitrary cancellation windows (e.g. blanket 2-hour penalty warnings) or dummy reservations. All cancellations must invoke the authoritative Supabase RPCs (`cancel_facility_slot` and `cancel_class_booking`). The backend evaluates `benefit_settings.cancellation_deadline_minutes` per facility and class start times. The mobile UI must faithfully present backend responses.
5. **Quality Gates**: Every change must maintain:
   - `flutter analyze` with 0 issues.
   - All unit and widget tests passing (`flutter test`).
   - Clean git status and documented changes.

---

## 3. Architecture & Directory Overview

```
.
├── AGENTS.md                                      # Repository rules & governance (this file)
├── .agents/
│   ├── rules/
│   │   ├── incline-project-rules.md               # Always-on governance rule file
│   │   └── incline-flutter-invariants.md          # Flutter-specific mobile invariants
│   └── skills/
│       ├── incline-mobile-design/                 # Mobile UI/UX design skill
│       ├── incline-supabase-audit/                # Supabase schema & RPC audit skill
│       ├── incline-web-mobile-parity/             # Web-to-mobile parity mapping skill
│       ├── incline-change-verification/           # 8-step verification pipeline skill
│       └── ui-ux-pro-max/                         # Design intelligence database & CLI
├── docs/
│   └── architecture/
│       ├── MOBILE_PARITY.md                       # Comprehensive web-to-mobile parity guide
│       ├── MOBILE_INTEGRATION_MAP.md              # Verified database, RPC, and Edge Function map
│       └── SUPABASE_CHANGE_POLICY.md              # Mandatory policy for backend/schema changes
├── mobile/ (symlink -> ../incline_app)            # Flutter native mobile client
│   └── README.md                                  # Mobile client architecture & dev guidelines
├── src/                                           # Web portal source (React + Vite + TypeScript)
│   ├── components/                                # Web UI components & member modules
│   ├── contexts/                                  # React contexts (AuthContext, etc.)
│   ├── hooks/                                     # Data hooks (useMemberData, etc.)
│   ├── pages/                                     # Web page routes (MyWorkout, MyDiet, Book...)
│   └── services/                                  # Client-side API services (classService, etc.)
└── supabase/
    ├── functions/                                 # Supabase Edge Functions (Deno / TypeScript)
    └── migrations/                                # 780+ PostgreSQL schema migrations
```

---

## 4. Reusable Agent Skills Reference

Agents working on Incline must invoke the project skills in `.agents/skills/`:
- **`incline-mobile-design`**: Use for all Flutter UI/UX work, design tokens, micro-interactions, animations, `DumbbellLoader`, empty states, haptics, and accessibility.
- **`incline-supabase-audit`**: Use before any database, RPC, RLS, Edge Function, or query modification to audit existing contracts.
- **`incline-web-mobile-parity`**: Use to construct the evidence-backed feature-to-backend mapping before writing mobile features.
- **`incline-change-verification`**: Use to execute the mandatory 8-step verification pipeline, static analysis, and test suites.
