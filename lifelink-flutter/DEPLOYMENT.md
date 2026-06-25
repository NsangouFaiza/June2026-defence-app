# LifeLink - Deployment Guide

## Backend Deployment

### Prerequisites
- Python 3.8+
- PostgreSQL (recommended for production)
- Nginx
- Gunicorn
- SSL Certificate

### Steps

1. **Prepare the Server**
   ```bash
   # Update system
   sudo apt update && sudo apt upgrade -y

   # Install Python and pip
   sudo apt install python3 python3-pip python3-venv -y

   # Install PostgreSQL
   sudo apt install postgresql postgresql-contrib -y

   # Install Nginx
   sudo apt install nginx -y
   ```

2. **Clone and Setup Backend**
   ```bash
   git clone <repository-url>
   cd lifelink-backend

   # Create virtual environment
   python3 -m venv venv
   source venv/bin/activate

   # Install dependencies
   pip install -r requirements.txt

   # Configure environment variables
   cp .env.example .env
   # Edit .env with your production settings
   ```

3. **Configure Database**
   ```bash
   # Create PostgreSQL database
   sudo -u postgres psql
   CREATE DATABASE lifelink;
   CREATE USER lifelink_user WITH PASSWORD 'your_password';
   GRANT ALL PRIVILEGES ON DATABASE lifelink TO lifelink_user;
   \q

   # Run migrations
   python manage.py migrate
   python manage.py createsuperuser
   ```

4. **Collect Static Files**
   ```bash
   python manage.py collectstatic --noinput
   ```

5. **Configure Gunicorn**
   Create `/etc/systemd/system/lifelink.service`:
   ```ini
   [Unit]
   Description=LifeLink Gunicorn daemon
   After=network.target

   [Service]
   User=www-data
   Group=www-data
   WorkingDirectory=/path/to/lifelink-backend
   ExecStart=/path/to/lifelink-backend/venv/bin/gunicorn --access-logfile - --workers 3 --bind unix:/run/lifelink.sock lifelink.wsgi:application

   [Install]
   WantedBy=multi-user.target
   ```

6. **Configure Nginx**
   Create `/etc/nginx/sites-available/lifelink`:
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;

       location = /favicon.ico { access_log off; log_not_found off; }
       location /static/ {
           root /path/to/lifelink-backend;
       }

       location / {
           include proxy_params;
           proxy_pass http://unix:/run/lifelink.sock;
       }
   }
   ```

7. **Enable and Start Services**
   ```bash
   sudo ln -s /etc/nginx/sites-available/lifelink /etc/nginx/sites-enabled
   sudo nginx -t
   sudo systemctl start lifelink
   sudo systemctl enable lifelink
   sudo systemctl restart nginx
   ```

8. **Configure SSL with Let's Encrypt**
   ```bash
   sudo apt install certbot python3-certbot-nginx -y
   sudo certbot --nginx -d your-domain.com
   ```

## Frontend Deployment

### Android (Google Play Store)

1. **Generate Signed APK/Bundle**
   ```bash
   flutter build appbundle --release
   ```

2. **Upload to Google Play Console**
   - Go to [Google Play Console](https://play.google.com/console)
   - Create a new application
   - Upload the app bundle
   - Complete store listing
   - Submit for review

### iOS (App Store)

1. **Build for iOS**
   ```bash
   flutter build ios --release
   ```

2. **Archive in Xcode**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select "Any iOS Device" as target
   - Product → Archive
   - Upload to App Store Connect

3. **Submit to App Store**
   - Go to [App Store Connect](https://appstoreconnect.apple.com/)
   - Create a new app
   - Upload the archive
   - Complete app information
   - Submit for review

## Environment Variables

### Backend (.env)
```env
DEBUG=False
SECRET_KEY=your-secret-key-here
DATABASE_URL=postgresql://lifelink_user:password@localhost/lifelink
ALLOWED_HOSTS=your-domain.com,www.your-domain.com
CORS_ALLOWED_ORIGINS=https://your-domain.com
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
```

### Frontend
Update `lib/data/services/api_service.dart`:
```dart
static const String baseUrl = 'https://your-domain.com/api';
```

## Monitoring and Maintenance

1. **Set up logging** - Configure Django logging
2. **Monitor server resources** - Use tools like htop, netdata
3. **Set up backups** - Regular database backups
4. **Monitor API usage** - Set up rate limiting
5. **Update dependencies** - Regular security updates

## Security Checklist

- [ ] HTTPS enabled with valid SSL certificate
- [ ] Strong SECRET_KEY configured
- [ ] DEBUG mode disabled in production
- [ ] Database credentials secured
- [ ] CORS properly configured
- [ ] Rate limiting enabled
- [ ] Input validation on all endpoints
- [ ] SQL injection protection (Django ORM handles this)
- [ ] XSS protection enabled
- [ ] Regular security audits
