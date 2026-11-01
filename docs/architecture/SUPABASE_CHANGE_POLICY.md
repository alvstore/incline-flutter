# INCLINE — Supabase Backend & Schema Change Policy

**Document Status**: Authoritative Architecture Standard  
**Target Repository**: `https://github.com/alvstore/incline.git`  
**Backend Framework**: Supabase (PostgreSQL 15+, GoTrue Auth, PostgREST, Edge Functions)  
**Clients**: Web (`src/`), Mobile (`mobile/` -> `../incline_app`)  

---

## 1. Executive Policy Statement

The Incline backend is a shared, mission-critical infrastructure supporting web members, club administrators, trainers, point-of-sale systems, and the native mobile application.

**Any modification to the Supabase database schema, Remote Procedure Calls (RPCs), Row Level Security (RLS) policies, database triggers, or Edge Functions requires an explicit, pre-change Impact Analysis.**

Agents and engineers are strictly prohibited from:
1. Executing ad-hoc DDL or SQL migrations in production without pre-audit and approval.
2. Altering RPC signatures or return shapes that break existing web callers.
3. Modifying or dropping existing database columns without backward-compatibility deprecation cycles.
4. Changing RLS policies without running authorization regression tests for all roles (`anon`, `authenticated`, member, trainer, admin).
5. Using `service_role` privileges to bypass RLS in client code.

---

## 2. Mandatory Impact Analysis Checklist

Before proposing or applying any backend change, complete the following impact assessment:

### 2.1 Table & Column Mutations
1. **Existing Web Callers**:
   - Search the entire web codebase for references:
     ```bash
     grep -rn "<table_name>" src/
     grep -rn "<column_name>" src/
     ```
   - Verify every hook, service, and form component that reads or writes to the table.
2. **Existing Mobile Callers**:
   - Search the mobile codebase:
     ```bash
     grep -rn "<table_name>" mobile/lib/
     grep -rn "<column_name>" mobile/lib/
     ```
3. **Migration History**:
   - Check the migration history in `supabase/migrations/` to understand historical constraints and triggers.
4. **Foreign Key & Cascade Effects**:
   - Check if other tables reference this table with `ON DELETE CASCADE` or `ON DELETE RESTRICT`.
   - Ensure foreign key constraints are not violated by new defaults.

### 2.2 Remote Procedure Calls (RPCs)
1. **Contract Integrity**:
   - If an RPC's parameters or return shape must change, create a versioned RPC (e.g. `public.cancel_class_booking_v2`) or maintain default parameters so existing web callers do not fail.
2. **Security Definer & Search Path**:
   - Every `SECURITY DEFINER` function MUST specify `SET search_path = public` to prevent search path hijacking.
   - Explicitly verify internal guards:
     ```sql
     -- Example mandatory internal guard
     IF auth.uid() IS NULL THEN
       RAISE EXCEPTION 'Not authenticated';
     END IF;
     ```
3. **Grant Validation**:
   - Ensure execution permissions are explicitly granted:
     ```sql
     GRANT EXECUTE ON FUNCTION public.<function_name> TO authenticated;
     ```

### 2.3 Row Level Security (RLS) Policies
1. **Never Disable RLS**:
   - `ALTER TABLE public.<table_name> DISABLE ROW LEVEL SECURITY;` is strictly prohibited on production tables.
2. **Policy Evaluation Costs**:
   - Avoid slow `IN (SELECT ...)` subqueries in RLS policies without supporting indexes on foreign keys.
   - Use `auth.uid()` directly wherever possible.
3. **Multi-Role Testing**:
   - Test policies under 4 distinct contexts:
     - Anonymous user (`anon`)
     - Authenticated member (`authenticated`, standard member)
     - Assigned trainer / staff
     - Branch administrator

### 2.4 Edge Functions
1. **Secret & Key Hygiene**:
   - Never commit API keys or secrets to `supabase/functions/`. All secrets must be referenced via `Deno.env.get(...)`.
2. **CORS & Preflight**:
   - Ensure all responses include standard CORS headers from `_shared/cors.ts`.
3. **JSON Payloads**:
   - Maintain strict input validation using schema validators (e.g. `zod`) before processing operations.

---

## 3. Standard Migration Protocol

When a database change is approved:

1. **Sequential Migration Naming**:
   - Create a new migration file in `supabase/migrations/` following the existing timestamp format:
     `supabase/migrations/<YYYYMMDDHHMMSS>_<short_descriptive_name>.sql`
2. **Idempotent DDL**:
   - Use idempotent statements:
     - `CREATE TABLE IF NOT EXISTS ...`
     - `ADD COLUMN IF NOT EXISTS ...`
     - `CREATE INDEX IF NOT EXISTS ...`
     - `CREATE OR REPLACE FUNCTION ...`
     - `DROP POLICY IF EXISTS ... ON ...` followed by `CREATE POLICY ...`
3. **Reversible Scripts**:
   - Document a rollback statement or migration script for emergency recovery.
4. **Types Generation**:
   - After migration, regenerate TypeScript definitions (`types.ts`) to ensure compile-time type safety across web and mobile tests:
     ```bash
     npx supabase gen types typescript --local > src/integrations/supabase/types.ts
     ```

---

## 4. Change Classification & Approval Matrix

| Change Tier | Description | Risk Level | Approval Required |
| :--- | :--- | :--- | :--- |
| **Tier 1: Read-Only Query Optimization** | Adding indexes, analyzing query plans | LOW | Tech Lead review |
| **Tier 2: Additive Column / Table** | Adding optional columns (`NULL` default), new non-disruptive tables | MEDIUM | Full code review + test verification |
| **Tier 3: RPC Logic Modification** | Modifying business rules inside existing RPCs | HIGH | Pre-change audit + user approval + regression tests |
| **Tier 4: RLS Policy Alteration** | Modifying permissions or table visibility rules | HIGH | Security review + multi-role policy testing |
| **Tier 5: Destructive Mutations** | Dropping columns, altering types, table renaming | CRITICAL | Explicit user authorization + data backup plan |
