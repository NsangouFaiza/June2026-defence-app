# LifeLink

**LifeLink** is a production-ready blood donation and blood bank management platform for connecting donors, patients, hospitals, laboratory staff, and administrators.

## Architecture

| Layer | Stack |
|-------|-------|
| Mobile | Flutter (Material 3), Riverpod, Clean Architecture |
| Backend | Django REST Framework, JWT, role-based access |
| Database | SQLite (development) |
| Real-time | Django Channels WebSocket chat |
| Integrations | Firebase FCM, Google Maps, MTN/Orange Money stubs, SMTP email |

## Project Structure

```
June2026 defence app/
├── backend/          → junction to lifelink-backend (Django API)
├── mobile/           → junction to lifelink-flutter (Flutter app)
├── README.md
├── INSTALLATION.md
└── DEPLOYMENT.md
```

## User Roles

- **Donor** — eligibility, appointments, donation history, rewards
- **Patient** — blood search, requests, emergency requests, hospital locator
- **Hospital Staff** — inventory, appointments, requests, campaigns
- **Lab Technician** — validate attendance, record donations, approve/reject units
- **Blood Bank Admin / System Admin** — users, hospitals, statistics, audit logs

## Quick Start

### Backend

```bash
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
copy .env.example .env
python manage.py migrate
python manage.py seed_data
daphne -b 0.0.0.0 -p 8000 lifelink.asgi:application
```

API docs: see `backend/API_DOCUMENTATION.md`

### Mobile

```bash
cd mobile
copy .env.example .env
flutter pub get
flutter run
```

See [INSTALLATION.md](INSTALLATION.md) for full setup and [DEPLOYMENT.md](DEPLOYMENT.md) for production deployment.

## Demo Accounts (after `seed_data`)

| Email | Password | Role |
|-------|----------|------|
| admin@lifelink.com | Admin@12345 | System Admin |
| donor@lifelink.com | Donor@12345 | Donor |
| patient@lifelink.com | Patient@12345 | Patient |
| staff@lifelink.com | Staff@12345 | Hospital Staff |
| lab@lifelink.com | Lab@12345 | Lab Technician |

## API Documentation

- **Detailed endpoint reference**: `backend/API_DOCUMENTATION.md`
- **Database schema**: `backend/DATABASE_SCHEMA.md`

## Configuration

Copy `.env.example` in both `backend/` and `mobile/`. Required keys for full functionality:

- `SECRET_KEY`, `JWT_SECRET_KEY` (backend)
- `GOOGLE_MAPS_API_KEY` (mobile + backend reference)
- `FIREBASE_CREDENTIALS_PATH` (backend push notifications)
- `MTN_API_KEY`, `ORANGE_API_KEY` (Mobile Money — stubs work without keys)
- SMTP settings for email verification and password reset

## License

Academic / defence project — June 2026.
