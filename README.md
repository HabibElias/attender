# Attender

Flutter app for attendance tracking with Supabase auth, role-based onboarding, and a polished Poppins-forward UI.

## Features
- Supabase email/password and Google OAuth sign-in/sign-up.
- Onboarding flow: splash → auth → role-based profile setup (student/teacher) → home.
- Hive local storage for session/user cache.
- Theming with primary color `#0E58BC`, gradient auth screens, branded splash logo.

## Prerequisites
- Flutter 3.10+ and Dart 3.10+.
- Supabase project with URL and anon key.

## Setup
1) Install dependencies: `flutter pub get`.
2) Create a `.env` file at project root with:
	```
	SUPABASE_URL=your-url
	SUPABASE_KEY=your-anon-key
	```
3) Ensure assets are available (logo at `lib/images/attender_icon.png`).

## Run
- Debug: `flutter run`
- Build Android: `flutter build apk`
- Build iOS: `flutter build ios` (on macOS)

## Notes
- If Supabase email confirmation is enabled, sign-up may require email verification.
- Role selection is stored locally in Hive and in Supabase via `ProfileService`.
