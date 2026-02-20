# NFC Event Management System

A complete NFC-based event management system for tracking food and goodie distribution at events. Participants tap their NFC tags at distribution counters, and the system instantly verifies identity, prevents duplicate collections, and provides real-time visual feedback.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Complete Mobile → Backend Flow](#complete-mobile--backend-flow)
- [API Reference](#api-reference)
- [Step-by-Step Setup Guide](#step-by-step-setup-guide)
- [Testing the Full Flow](#testing-the-full-flow)
- [Security Features](#security-features)
- [Production Deployment](#production-deployment)

---

## Architecture Overview

```
┌────────────────────┐         HTTP/JSON          ┌────────────────────┐
│                    │  ◄──────────────────────►   │                    │
│   Flutter Mobile   │    Token Auth (Header)      │   Django Backend   │
│   App (Android)    │                             │   (DRF + SQLite)   │
│                    │                             │                    │
│  • NFC Tag Reader  │   POST /api/login/          │  • Auth System     │
│  • Login Screen    │   POST /api/scan/           │  • Participant DB  │
│  • Scan Screen     │   POST /api/give-breakfast/ │  • Race-Safe Dist  │
│  • Result Overlay  │   POST /api/give-lunch/     │  • Admin Dashboard │
│                    │   POST /api/give-dinner/    │                    │
│                    │   POST /api/give-goodie/    │                    │
│                    │   GET  /api/stats/          │                    │
└────────────────────┘                             └────────────────────┘
```

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **Backend** | Python 3.10+, Django 4.x, Django REST Framework |
| **Database** | SQLite (dev) / PostgreSQL (production) |
| **Mobile App** | Flutter 3.x, Dart |
| **NFC Library** | `nfc_manager` (Flutter) |
| **Authentication** | DRF Token Authentication |
| **Race Safety** | `transaction.atomic()` + `select_for_update()` |

---

## Project Structure

```
nfc/
├── README.md                  ← You are here
├── SETUP.md                   ← Detailed setup instructions
├── DEPLOYMENT.md              ← Production deployment guide
├── API_TESTS.md               ← curl/PowerShell API examples
│
├── backend/                   ← Django REST API
│   ├── manage.py
│   ├── requirements.txt
│   ├── db.sqlite3             ← Created after migration
│   ├── nfc_backend/
│   │   ├── settings.py        ← Django config (DB, CORS, DRF)
│   │   ├── urls.py            ← Root URL routing → events.urls
│   │   └── wsgi.py            ← WSGI entry point
│   └── events/
│       ├── models.py          ← Participant model
│       ├── views.py           ← 7 API endpoint handlers
│       ├── serializers.py     ← Request/response validation
│       ├── urls.py            ← API route definitions
│       ├── admin.py           ← Django admin config
│       ├── tests.py           ← 13 unit tests
│       └── management/
│           └── commands/
│               └── seed_data.py  ← Sample data generator
│
└── mobile/                    ← Flutter Android App
    ├── pubspec.yaml           ← Dependencies
    ├── lib/
    │   ├── main.dart          ← App entry, theme, auto-login
    │   ├── api_service.dart   ← HTTP client + token management
    │   ├── models.dart        ← Participant & DistributionResponse
    │   ├── login_screen.dart  ← Admin login UI
    │   ├── scan_screen.dart   ← NFC scanning + distribution UI
    │   └── result_screen.dart ← Success/error overlay
    └── android/
        └── app/src/main/
            └── AndroidManifest.xml  ← NFC permissions + intents
```

---

## Complete Mobile → Backend Flow

This is the **end-to-end journey** from app launch to food distribution:

### Step 1: App Launch & Auto-Login Check

```
App starts → main.dart → NfcEventApp → AppInitializer
                                            │
                                    loadToken() from
                                    SharedPreferences
                                            │
                               ┌────────────┴────────────┐
                               │                         │
                         Token exists?              No token?
                               │                         │
                        → ScanScreen              → LoginScreen
```

- `AppInitializer` checks SharedPreferences for a saved auth token
- If found, skips login and goes directly to `ScanScreen`
- If not found, shows `LoginScreen`

### Step 2: Admin Login

```
LoginScreen                          Django Backend
    │                                     │
    │  POST /api/login/                   │
    │  {"username":"admin",               │
    │   "password":"admin123"}            │
    │ ──────────────────────────────────► │
    │                                     │  authenticate()
    │                                     │  Token.objects.get_or_create()
    │  {"status":"success",               │
    │   "token":"abc123def...",           │
    │   "username":"admin"}              │
    │ ◄────────────────────────────────── │
    │                                     │
    │  Save token → SharedPreferences     │
    │  Navigate → ScanScreen              │
```

- User enters username + password (and optionally configures server URL)
- `ApiService.login()` sends POST to `/api/login/`
- Backend authenticates via `django.contrib.auth.authenticate()`
- On success: returns a DRF `Token`, saved to `SharedPreferences`
- On failure: returns 401 with error message

### Step 3: NFC Tag Scan

```
Physical NFC Tag              Flutter App                    Django Backend
      │                           │                               │
  [TAP TAG]                       │                               │
      │                   NfcManager detects tag                  │
      │                   onDiscovered callback                   │
      │                           │                               │
      │                   Extract UID bytes from                  │
      │                   nfca/nfcb/mifare/isodep                 │
      │                           │                               │
      │                   Convert to uppercase hex                │
      │                   e.g. "04A23B1C5D6E80"                   │
      │                           │                               │
      │                   POST /api/scan/                         │
      │                   Authorization: Token abc123             │
      │                   {"uid":"04A23B1C5D6E80"}                │
      │                   ─────────────────────────────────────► │
      │                                                           │
      │                                              Normalize UID (uppercase)
      │                                              Participant.objects.get()
      │                                                           │
      │                   {"status":"valid",                      │
      │                    "name":"Rahul Kumar",                  │
      │                    "college":"IIT Madras",                │
      │                    "breakfast": false,                    │
      │                    "lunch": false,                        │
      │                    "dinner": false,                       │
      │                    "goodie_collected": false}             │
      │                   ◄───────────────────────────────────── │
      │                           │                               │
      │                   Display participant card                │
      │                   Show 4 action buttons                   │
```

**UID Extraction Logic** (handles all NFC tag types):
1. Try `nfca['identifier']` (most common — MIFARE Ultralight/Classic)
2. Try `mifare['identifier']`
3. Try `nfcb['identifier']`
4. Try `nfcf['identifier']` (FeliCa)
5. Try `nfcv['identifier']` (ISO 15693)
6. Try `isodep['identifier']`

**UID Format**: Raw bytes → uppercase hex string, no separators  
Example: `[0x04, 0xA2, 0x3B, 0x1C, 0x5D, 0x6E, 0x80]` → `"04A23B1C5D6E80"`

### Step 4: Food/Goodie Distribution

```
Flutter App                                        Django Backend
    │                                                    │
    │  User taps "Give Breakfast" button                 │
    │                                                    │
    │  POST /api/give-breakfast/                         │
    │  Authorization: Token abc123                       │
    │  {"uid":"04A23B1C5D6E80"}                          │
    │  ───────────────────────────────────────────────► │
    │                                                    │
    │                                       transaction.atomic():
    │                                         participant = Participant
    │                                           .objects
    │                                           .select_for_update()
    │                                           .get(uid=uid)
    │                                                    │
    │                                       if participant.breakfast:
    │                                         → already_collected
    │                                       else:
    │                                         participant.breakfast = True
    │                                         participant.save()
    │                                         → success
    │                                                    │
    │  ◄ FIRST TIME ─────────────────────────────────── │
    │  {"status":"success",                              │
    │   "message":"Breakfast given to Rahul Kumar.",      │
    │   "name":"Rahul Kumar",                            │
    │   "college":"IIT Madras"}                          │
    │                                                    │
    │  → Show GREEN overlay: "Allowed"                   │
    │  → Refresh participant data                        │
    │  → Button changes to "Breakfast ✓ Collected"       │
    │  → Button gets disabled                            │
    │                                                    │
    │  ◄ SECOND TIME ────────────────────────────────── │
    │  {"status":"already_collected",                    │
    │   "message":"Breakfast already collected           │
    │              by Rahul Kumar.",                      │
    │   "name":"Rahul Kumar",                            │
    │   "college":"IIT Madras"}                          │
    │                                                    │
    │  → Show RED overlay: "Already Collected"           │
```

**Race Condition Prevention**: If two counters scan the same tag simultaneously:
- `select_for_update()` locks the database row
- Second request waits until the first completes
- Only one gets `"success"`, the other gets `"already_collected"`

### Step 5: Visual Feedback (Result Overlay)

| Status | Color | Icon | Auto-dismiss |
|--------|-------|------|-------------|
| **Success** | 🟢 Green gradient | ✓ Check circle | 2 seconds |
| **Already Collected** | 🔴 Red gradient | ⊘ Block | 2 seconds |
| **Invalid Tag** | 🟠 Orange gradient | ⚠ Error | 2 seconds |
| **Error** | 🟣 Purple gradient | ⚠ Warning | 2 seconds |

### Step 6: Scan Next Tag

After distributing, the operator can:
1. **Tap another NFC tag** → automatically scans the new tag (NFC session continues)
2. **Press "Scan Another Tag"** → resets the UI to scan mode
3. **Press refresh icon** → clears current participant and waits for new tag

---

## API Reference

All endpoints require `Authorization: Token <token>` header except `/api/login/`.

| Method | Endpoint | Body | Auth | Description |
|--------|----------|------|------|-------------|
| POST | `/api/login/` | `{"username", "password"}` | No | Get auth token |
| POST | `/api/scan/` | `{"uid": "HEX"}` | Yes | Lookup participant |
| POST | `/api/give-breakfast/` | `{"uid": "HEX"}` | Yes | Mark breakfast collected |
| POST | `/api/give-lunch/` | `{"uid": "HEX"}` | Yes | Mark lunch collected |
| POST | `/api/give-dinner/` | `{"uid": "HEX"}` | Yes | Mark dinner collected |
| POST | `/api/give-goodie/` | `{"uid": "HEX"}` | Yes | Mark goodie collected |
| GET | `/api/stats/` | — | Yes | Distribution statistics |

---

## Step-by-Step Setup Guide

### Prerequisites

- Python 3.10+
- Flutter SDK 3.0+
- Android device with NFC (or emulator for testing without NFC)

### 1. Start the Backend

```bash
cd backend

# Create virtual environment
python -m venv venv

# Activate (Windows)
.\venv\Scripts\activate

# Activate (macOS/Linux)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create database tables
python manage.py makemigrations events
python manage.py migrate

# Seed sample data (creates users + 20 participants)
python manage.py seed_data

# Start server (accessible from mobile device)
python manage.py runserver 0.0.0.0:8000
```

**Note the output from `seed_data`** — it prints:
- Admin credentials: `admin` / `admin123`
- Counter credentials: `counter1` / `counter123`
- Auth tokens for both users
- Sample NFC UIDs for testing

### 2. Configure & Run the Mobile App

```bash
cd mobile

# Install Flutter dependencies
flutter pub get

# Run on connected Android device
flutter run
```

### 3. Connect App to Backend

On the **Login Screen**, tap **"Server Config"** and set the URL:

| Scenario | Server URL |
|----------|-----------|
| Android Emulator → host PC | `http://10.0.2.2:8000/api` |
| Physical device → same WiFi | `http://<your-pc-ip>:8000/api` |
| Production server | `https://yourdomain.com/api` |

To find your PC's IP:
```bash
# Windows
ipconfig

# macOS/Linux
ifconfig
```

### 4. Login

Enter `admin` / `admin123` (or `counter1` / `counter123`) and tap **Sign In**.

### 5. Start Scanning

- **With NFC tags**: Simply hold a registered NFC tag near the device
- **Without NFC tags**: Tap **"Enter UID manually"** and type a sample UID from the seed output

---

## Testing the Full Flow

### Quick Smoke Test (No NFC Hardware Needed)

1. Start backend: `python manage.py runserver 0.0.0.0:8000`
2. Run Flutter app: `flutter run`
3. Login with `admin` / `admin123`
4. Tap **"Enter UID manually"**
5. Enter a sample UID from the seed data output
6. You should see the participant's name and college
7. Tap **"Give Breakfast"** → Green overlay ✓
8. Tap **"Give Breakfast"** again → Red overlay (already collected)
9. Tap **"Give Lunch"** → Green overlay ✓
10. Tap **"Scan Another Tag"** → Ready for next participant

### Run Backend Unit Tests

```bash
cd backend
.\venv\Scripts\python.exe manage.py test events -v 2
```

Expected: **13 tests, all passing**

### Run Flutter Static Analysis

```bash
cd mobile
flutter analyze
```

Expected: **No issues found**

### API Test with curl

```bash
# Login
curl -X POST http://localhost:8000/api/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}'

# Scan (use token from login response)
curl -X POST http://localhost:8000/api/scan/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN" \
  -d '{"uid": "SAMPLE_UID_FROM_SEED"}'

# Distribute
curl -X POST http://localhost:8000/api/give-breakfast/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN" \
  -d '{"uid": "SAMPLE_UID_FROM_SEED"}'
```

See [API_TESTS.md](API_TESTS.md) for more examples.

---

## Security Features

| Feature | Implementation |
|---------|---------------|
| **Authentication** | DRF Token Auth on all endpoints (except login) |
| **Race Conditions** | `select_for_update()` + `transaction.atomic()` |
| **UID Normalization** | Uppercase hex, strip colons/hyphens on both ends |
| **CORS** | Open in dev (`DEBUG=True`), restricted in production |
| **Cleartext HTTP** | Enabled for development only; use HTTPS in production |

---

## Production Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for full instructions covering:
- PostgreSQL database setup
- Gunicorn + Nginx configuration
- HTTPS with Let's Encrypt
- Systemd service for auto-restart
- Building release APK

---

## Database Model

```
Participant
├── uid: CharField(32, unique, indexed)   ← NFC tag hardware UID
├── name: CharField(200)                  ← Participant name
├── college: CharField(200)               ← College/institution
├── breakfast: BooleanField (default: False)
├── lunch: BooleanField (default: False)
├── dinner: BooleanField (default: False)
├── goodie_collected: BooleanField (default: False)
└── created_at: DateTimeField (auto)
```

---

## Default Credentials

| User | Password | Role | Use Case |
|------|----------|------|----------|
| `admin` | `admin123` | Superuser | Django admin panel + API |
| `counter1` | `counter123` | Staff | Distribution counters |

> ⚠️ **Change these credentials before deploying to production!**
