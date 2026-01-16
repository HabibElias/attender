# Attender

Attender is a Flutter-based attendance app built around Supabase authentication and a teacher-first workflow for creating classes, scheduling sessions, and tracking attendance.

## Features

### Authentication & onboarding
- Email/password sign-in and Google OAuth via Supabase.
- Role-based onboarding (Teacher/Student) with profile setup.
- Splash screen routing into the correct flow.

### Teacher workflow
- Create, edit, and delete classes.
- Create schedules for classes.
- Start/close/delete class sessions.
- Generate QR-based attendance codes.
- Session calendar view + per-session attendee list.

### Student workflow (in progress)
- Student dashboard exists, but most data is currently placeholder and the “join class / submit attendance” flows are not fully wired yet.

### Offline tolerance
- Lightweight local caching using Hive for auth/profile and teacher class lists.

## Tech stack
- Flutter (Material 3)
- Supabase (`supabase_flutter`) for auth + database
- `flutter_dotenv` for local env config
- Hive (`hive`/`hive_flutter`) for caching
- QR and scanning: `qr_flutter`, `mobile_scanner`
- Calendar UI: `table_calendar`
- Typography: `google_fonts`

## Getting started

### Prerequisites
- Flutter (Dart SDK `^3.10.7` as configured in `pubspec.yaml`)
- A Supabase project (URL + anon key)

### Configure environment
1) Install dependencies:
   ```bash
   flutter pub get
   ```
2) Create a `.env` file at the project root:
   ```
   SUPABASE_URL=YOUR_SUPABASE_URL
   SUPABASE_KEY=YOUR_SUPABASE_ANON_KEY
   ```

### Run
```bash
flutter run
```

Build targets:
```bash
flutter build apk
flutter build web
```

## Supabase requirements

### OAuth redirect (Google)
For mobile deep-links, configure the redirect URI:
- `io.supabase.flutter://callback`

You may also need to set up Android intent filters / iOS URL schemes to match the redirect.

### Database tables & RPCs
This app expects Supabase tables (or equivalent views) for:
- `profiles`
- `classes`
- `schedules`
- `class_students`
- `class_sessions`
- `attendances`

It also expects RPCs (Postgres functions) referenced by the services layer:
- `insert_profile`
- `create_class_with_schedules`
- `update_class_with_schedules`
- `search_students`
- `get_class_students`

If your schema differs, update the calls in:
- `lib/services/profile_service.dart`
- `lib/services/class_service/class_service.dart`

## Project structure
- `lib/main.dart` – app bootstrap (Hive + dotenv + Supabase init) and theme
- `lib/screens/` – UI screens (auth, home, profile setup, QR)
- `lib/services/` – Supabase + storage services

## Current status / roadmap
- Teacher flows (classes, schedules, sessions, attendee lists) are implemented.
- Student flows (join classes, scan/submit attendance, real stats) are still in progress.

