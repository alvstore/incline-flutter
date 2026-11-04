# Incline Application Changelog

All notable changes, bug fixes, architecture updates, and feature implementations for the Incline mobile platform.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0+1] - 2026-11-03

### Added
- **Production Supabase Integration**:
  - Live data binding across members, memberships, attendance, classes, invoices, and payments.
  - Zero-trust architecture enforced with PostgreSQL Row Level Security (RLS) (`auth.uid() = user_id`).
  - Isolated public `anon` key; zero administrative or `service_role` secrets bundled in application code.
- **Dynamic Class Disciplines**:
  - Replaced hardcoded class categories with dynamic database fetching (`classes` & `class_categories`).
  - Dynamic scheduling for Reformer Pilates, Yoga & Mobility, Functional Strength, Aerobics, and Zumba.
- **Invoice & Payment Differentiation**:
  - Multi-state payment status badges: Emerald (`PAID`), Amber (`PENDING`), Rose (`FAILED`), Cyan (`REFUNDED`), Purple (`PROCESSING`).
  - Sanitization of private staff notes from member payment receipts.
- **Habitual Workout Telemetry & Motivational Push**:
  - Peak visit time calculation derived from historical check-ins ($\text{mode}(\text{attendance})$).
  - Background notifications triggering streak defenses and workout motivators.
- **Biometric Security & Brand Standardization**:
  - Biometric app lock (Face ID / Fingerprint via `local_auth`).
  - Official Incline® registered trademark branding and luxury UI styling across dark/light modes.

### Security & Privacy
- Sanitized all authentication controllers to enforce real credential entry with zero hardcoded fallbacks.
- Configured compile-time environment variable injection (`--dart-define`) via `EnvConfig`.
- Set `InclineNotificationReceiver` to `android:exported="false"` in `AndroidManifest.xml`.
- Extended `.gitignore` to safeguard all keystores, JKS, certificates, and `.env` files.
