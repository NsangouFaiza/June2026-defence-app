# LifeLink — Deployment Guide

## Overview

Deploy the Django backend (with Daphne for WebSockets) and Flutter mobile apps to production. Use PostgreSQL in production instead of SQLite.

## Backend Deployment

### Environment Variables (Production)

```env
DEBUG=False
SECRET_KEY=<strong-random-key>
ALLOWED_HOSTS=api.lifelink.example.com
CORS_ALLOWED_ORIGINS=https://lifelink.example.com

DATABASE_URL=postgres://user:pass@host:5432/lifelink

JWT_SECRET_KEY=<jwt-signing-key>
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.yourprovider.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=

FIREBASE_CREDENTIALS_PATH=/etc/lifelink/firebase-credentials.json
MTN_API_KEY=
MTN_API_URL=https://momodeveloper.mtn.com
ORANGE_API_KEY=
ORANGE_API_URL=https://api.orange.com

SECURE_SSL_REDIRECT=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
```

### PostgreSQL

Update `lifelink/settings.py` or use `dj-database-url`:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME'),
        'USER': config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
    }
}
```

### Redis for Channels (Production)

Replace in-memory channel layer:

```python
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {'hosts': [config('REDIS_URL', default='redis://127.0.0.1:6379/0')]},
    },
}
```

Add to `requirements.txt`: `channels-redis==4.1.0`

### Static & Media Files

```bash
python manage.py collectstatic --noinput
```

Serve media via Cloudinary, Firebase Storage, or S3. Configure:

```env
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
```

### Process Manager (Gunicorn + Daphne)

**Option A — Daphne only (HTTP + WebSocket):**

```bash
daphne -b 0.0.0.0 -p 8000 lifelink.asgi:application
```

**Option B — systemd service:**

```ini
[Unit]
Description=LifeLink ASGI
After=network.target

[Service]
User=www-data
WorkingDirectory=/var/www/lifelink/backend
EnvironmentFile=/etc/lifelink/env
ExecStart=/var/www/lifelink/venv/bin/daphne -b 0.0.0.0 -p 8000 lifelink.asgi:application
Restart=always

[Install]
WantedBy=multi-user.target
```

### Reverse Proxy (Nginx)

```nginx
upstream lifelink {
    server 127.0.0.1:8000;
}

server {
    listen 443 ssl;
    server_name api.lifelink.example.com;

    location / {
        proxy_pass http://lifelink;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /ws/ {
        proxy_pass http://lifelink;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## Mobile Deployment

### Android

```bash
cd mobile
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Google Play Console.

Configure signing in `android/key.properties` and `android/app/build.gradle`.

### iOS

```bash
flutter build ipa --release
```

Upload via Xcode / Transporter to App Store Connect.

### Release Checklist

- [ ] Point `API_BASE_URL` to production HTTPS endpoint
- [ ] Configure `WS_BASE_URL` with `wss://`
- [ ] Restrict Google Maps API key by app bundle ID
- [ ] Add production Firebase configs
- [ ] Enable ProGuard/R8 (Android) if needed
- [ ] Test JWT refresh flow on slow networks

## CI/CD Suggestion

```yaml
# .github/workflows/backend.yml
- run: pip install -r backend/requirements.txt
- run: python backend/manage.py check
- run: python backend/manage.py migrate --plan
```

```yaml
# .github/workflows/mobile.yml
- uses: subosito/flutter-action@v2
- run: flutter pub get
- run: flutter analyze
- run: flutter test
```

## Security Notes

- Rotate `SECRET_KEY` and `JWT_SECRET_KEY` per environment
- Enable HTTPS everywhere
- Use token blacklisting (already configured via `simplejwt.token_blacklist`)
- Rate-limit auth endpoints at reverse proxy
- Never commit `.env` or Firebase credential files

## Monitoring

- Backend logs: `backend/logs/django.log`
- Consider Sentry for error tracking
- Firebase Analytics for mobile usage (configure in Flutter Firebase SDK)

## Mobile Money Go-Live

Replace stubs in `backend/payments/services.py`:

1. Implement real MTN Collections API calls in `MTNMobileMoneyProvider.initiate()`
2. Implement Orange Money API in `OrangeMoneyProvider.initiate()`
3. Wire webhook endpoints for payment confirmation
4. Set production API keys in environment
