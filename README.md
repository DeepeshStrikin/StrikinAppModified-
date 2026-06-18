# Strikin — Flutter app

Cross-platform (Android, iOS, web) Strikin booking & loyalty app, built in **Flutter**,
talking to the **FastAPI** backend in `../backend`. Responsive on any phone size.

## Prerequisites
- Flutter SDK (this project was built with Flutter 3.44 / Dart 3.12).
  Installed here at `C:\Users\DeepeshPJ\flutter` — add `…\flutter\bin` to PATH, or call it
  directly: `C:\Users\DeepeshPJ\flutter\bin\flutter`.

## Run the backend (from its venv)
```
cd ../backend
.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## Run the Flutter app

### A) Web — view on any phone browser (easiest)
```
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8090
```
Then open `http://<your-PC-LAN-IP>:8090` in the phone browser (same Wi-Fi).
The app auto-detects the backend at the **same host, port 8000** — so changing Wi-Fi/IP
just works. If the backend is unreachable it falls back to bundled sample data.

### B) Android device / emulator (native)
```
flutter run -d <device-id>          # see: flutter devices
flutter run --dart-define=API_URL=http://192.168.0.13:8000   # point at a specific backend
```

### C) Build a release APK to install on a phone
```
flutter build apk --release --dart-define=API_URL=http://<PC-LAN-IP>:8000
# output: build/app/outputs/flutter-apk/app-release.apk  (requires Android SDK)
```

## Configuration (no hardcoded secrets)
- App → backend URL: `--dart-define=API_URL=...` (otherwise resolved from the serving host on
  web, or the LAN-IP fallback on native — see `lib/api.dart`).
- Backend secrets (Razorpay, SendGrid, Restoworks): `../backend/.env`.

## Structure
```
lib/
  main.dart            splash -> auth gate -> shell
  theme.dart           design tokens (dark + lime #D6FD31)
  models.dart api.dart mock.dart   data layer (+ offline fallback)
  auth.dart store.dart            persisted login + booking draft (ChangeNotifier)
  widgets/             ui, brand_mark, animated_splash, scaffold
  screens/             login, shell(tabs), home, activity_booking, food,
                       checkout, confirmation, bookings, loyalty, profile, corporate
assets/                ring1..4.svg (logo rings for the animated splash)
```
