# Attender

Flutter attendance app with Supabase auth, role-based onboarding, and teacher-first class/session management. UI uses a Poppins-forward theme and gradient auth screens.

## Project status
- Implemented: splash/auth/onboarding flow, email + Google OAuth, Hive-backed session cache, role selection stored in Supabase, teacher dashboard with create/edit/delete classes, schedule builder, cached class lists, session management (start/close/delete), QR for attendance codes, calendar of sessions, attendee list per session, profile cards. See [lib/main.dart](lib/main.dart), [lib/screens/auth_page.dart](lib/screens/auth_page.dart), [lib/screens/home/teacher_home_page.dart](lib/screens/home/teacher_home_page.dart), and [lib/services/class_service.dart](lib/services/class_service.dart).
- Student side is a placeholder dashboard with static stats and no live attendance/class join flows yet. See [lib/screens/home/student_home_page.dart](lib/screens/home/student_home_page.dart).
- Supabase RPCs expected: `insert_profile`, `create_class_with_schedules`, `update_class_with_schedules`, `search_students`, `get_class_students`. The app also reads/writes `profiles`, `classes`, `schedules`, `class_students`, `class_sessions`, and `attendances` tables.
- Offline tolerance: profile/role and teacher class lists cache in Hive; most screens refresh on pull.

## Prerequisites
- Flutter 3.10+ and Dart 3.10+.
- Supabase project with anon key and deep-link redirect configured for Google OAuth (`io.supabase.flutter://callback`).
- Supabase schema with the tables above; create the RPCs or equivalent server logic used in `ClassService` and `ProfileService`.

## Setup
1) Install deps: `flutter pub get`.
2) Create `.env` at project root:
   ```
   SUPABASE_URL=your-url
   SUPABASE_KEY=your-anon-key
   ```
3) Ensure assets exist (logo at `lib/images/attender_icon.png` is already referenced).
4) For Google OAuth on mobile, match the redirect URI `io.supabase.flutter://callback` in Supabase and Android intent filters / iOS URL schemes.

## Run
- Debug: `flutter run`
- Build Android: `flutter build apk`
- Build iOS (on macOS): `flutter build ios`

## Notes and gaps
- Student features (joining classes, marking attendance, real stats) are not wired yet; current cards show placeholder data.
- Session attendance currently shows attendees and counts per session and supports closing/deleting sessions; student-side attendance submission is not implemented.
- Hive boxes used: `authBox` for auth/profile cache, `dataCache` for teacher class lists.
