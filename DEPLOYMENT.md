# Deployment Guide — Gunicorn + Nginx

This guide covers deploying the NFC Event Management System to a production Ubuntu server.

---

## 1. Server Prerequisites

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install python3 python3-pip python3-venv nginx certbot python3-certbot-nginx -y
```

## 2. Deploy Django Backend

### Clone and Setup

```bash
cd /opt
sudo mkdir nfc-event && cd nfc-event
# Copy your backend/ directory here

cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Configure for Production

Edit `nfc_backend/settings.py` or set environment variables:

```bash
export DJANGO_SECRET_KEY="your-super-secret-key-here"
export DJANGO_DEBUG="False"
export DJANGO_ALLOWED_HOSTS="yourdomain.com,your-server-ip"
export CORS_ALLOWED_ORIGINS="https://yourdomain.com"
```

### Switch to PostgreSQL (Recommended)

```bash
sudo apt install postgresql postgresql-contrib -y
sudo -u postgres psql
```

```sql
CREATE DATABASE nfc_events;
CREATE USER nfc_user WITH PASSWORD 'your_db_password';
ALTER ROLE nfc_user SET client_encoding TO 'utf8';
ALTER ROLE nfc_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE nfc_user SET timezone TO 'Asia/Kolkata';
GRANT ALL PRIVILEGES ON DATABASE nfc_events TO nfc_user;
\q
```

Uncomment the PostgreSQL config in `settings.py` and update credentials.

### Run Migrations and Seed

```bash
python manage.py migrate
python manage.py seed_data --count 500
python manage.py collectstatic --noinput
```

---

## 3. Configure Gunicorn

### Create Systemd Service

```bash
sudo nano /etc/systemd/system/nfc-event.service
```

```ini
[Unit]
Description=NFC Event Management Backend
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/nfc-event/backend
Environment="DJANGO_SECRET_KEY=your-super-secret-key"
Environment="DJANGO_DEBUG=False"
Environment="DJANGO_ALLOWED_HOSTS=yourdomain.com"
ExecStart=/opt/nfc-event/backend/venv/bin/gunicorn \
    --workers 4 \
    --bind unix:/opt/nfc-event/backend/nfc_event.sock \
    --timeout 120 \
    nfc_backend.wsgi:application

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl start nfc-event
sudo systemctl enable nfc-event
sudo systemctl status nfc-event
```

---

## 4. Configure Nginx

```bash
sudo nano /etc/nginx/sites-available/nfc-event
```

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location /static/ {
        alias /opt/nfc-event/backend/staticfiles/;
    }

    location / {
        proxy_pass http://unix:/opt/nfc-event/backend/nfc_event.sock;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/nfc-event /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## 5. Enable HTTPS (Let's Encrypt)

```bash
sudo certbot --nginx -d yourdomain.com
sudo systemctl restart nginx
```

Certbot auto-renews certificates.

---

## 6. Build Flutter Release APK

On your development machine:

```bash
cd mobile

# Update the server URL in lib/api_service.dart:
# static String baseUrl = 'https://yourdomain.com/api';

flutter build apk --release --split-per-abi
```

Install the APK on your Android devices:
```
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 7. Firewall

```bash
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw enable
```

---

## 8. Monitoring & Logs

```bash
# Backend logs
sudo journalctl -u nfc-event -f

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Restart services
sudo systemctl restart nfc-event
sudo systemctl restart nginx
```
