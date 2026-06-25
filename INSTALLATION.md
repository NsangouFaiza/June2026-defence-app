# LifeLink — Installation Guide

## Prerequisites

- **Python 3.10+** (3.11 recommended; 3.13 supported with updated Pillow)
- **Flutter SDK 3.16+** ([install Flutter](https://docs.flutter.dev/get-started/install))
- **Git**
- Optional: Android Studio / Xcode for device emulators

## 1. Clone / Open Project

```bash
cd "c:\Users\NSANGOU FAIZA\Desktop\June2026 defence app"
```

## 2. Backend Setup

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# macOS/Linux
# source venv/bin/activate

pip install -r requirements.txt
copy .env.example .env   # Windows
# cp .env.example .env   # macOS/Linux
```

Edit `backend/.env`:

```env
DEBUG=True
SECRET_KEY=change-me-in-production
ALLOWED_HOSTS=localhost,127.0.0.1
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:8080
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
```

Run migrations and seed demo data:

```bash
python manage.py migrate
python manage.py seed_data
python manage.py createsuperuser   # optional extra admin
```

Start the ASGI server (required for WebSocket chat):

```bash
daphne -b 127.0.0.1 -p 8000 lifelink.asgi:application
```

Alternative (HTTP only, no WebSocket):

```bash
python manage.py runserver
```

Verify:

- Health: http://127.0.0.1:8000/api/users/login/
- API reference: `backend/API_DOCUMENTATION.md`
- Admin: http://127.0.0.1:8000/admin/

## 3. Mobile Setup

```bash
cd mobile
copy .env.example .env
flutter pub get
```

Configure API URL in `lib/core/constants/app_constants.dart` or via environment:

```dart
static const String baseUrl = 'http://127.0.0.1:8000/api';
static const String wsBaseUrl = 'ws://127.0.0.1:8000/ws';
```

### Google Maps

1. Create a Google Cloud project and enable Maps SDK for Android/iOS.
2. Add `GOOGLE_MAPS_API_KEY` to `.env`.
3. Android: `android/app/src/main/AndroidManifest.xml`
4. iOS: `ios/Runner/AppDelegate.swift`

### Firebase (Push Notifications)

1. Create a Firebase project.
2. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
3. Place backend credentials at path configured in `FIREBASE_CREDENTIALS_PATH`.

Run the app:

```bash
flutter run
```

For web/desktop, use `flutter run -d chrome` or `-d windows`.

## 4. Verify Installation

### Backend checks

```bash
python manage.py check
python manage.py migrate --plan
```

Test login:

```bash
curl -X POST http://127.0.0.1:8000/api/users/login/ ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"donor@lifelink.com\",\"password\":\"Donor@12345\"}"
```

### Flutter checks

```bash
flutter analyze
flutter test
```

## 5. Troubleshooting

| Issue | Fix |
|-------|-----|
| Pillow build error on Python 3.13 | Use `Pillow>=10.4.0` (already in requirements.txt) |
| CORS errors from mobile | Add emulator IP to `CORS_ALLOWED_ORIGINS` |
| WebSocket fails | Use `daphne`, not `runserver` |
| Flutter not found | Add Flutter SDK to PATH |
| Android emulator API | Use `http://10.0.2.2:8000/api` instead of localhost |

## 6. Database Schema

See `backend/DATABASE_SCHEMA.md` for full ERD and table descriptions. Migrations live in each Django app's `migrations/` folder.
