# NFC Event Management System — Setup Guide

## Prerequisites

- **Python 3.10+** with pip
- **Flutter SDK 3.0+** ([install guide](https://docs.flutter.dev/get-started/install))
- **Android SDK** (via Android Studio)
- **Android device with NFC** (for testing NFC scanning)
- Git

---

## 1. Backend Setup (Django)

### Create Virtual Environment

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate
```

### Install Dependencies

```bash
pip install -r requirements.txt
```

### Run Migrations

```bash
python manage.py migrate
```

### Create Admin User & Seed Data

```bash
# Creates admin user (admin/admin123) + counter user (counter1/counter123) + 20 sample participants
python manage.py seed_data

# Or create more participants:
python manage.py seed_data --count 500
```

The seed command prints:
- Admin auth token
- Counter auth token
- Sample participant UIDs for testing

### Create a Custom Admin User (Optional)

```bash
python manage.py createsuperuser
```

### Start Development Server

```bash
# Listen on all interfaces (needed for mobile app to connect)
python manage.py runserver 0.0.0.0:8000
```

The server will be available at `http://<your-ip>:8000/`

### Access Django Admin

Open `http://localhost:8000/admin/` in your browser.  
Login with `admin` / `admin123`.

---

## 2. Flutter App Setup

### Install Dependencies

```bash
cd mobile
flutter pub get
```

### Configure Server URL

Edit `lib/api_service.dart` and change the base URL:

```dart
// For Android Emulator connecting to host machine:
static String baseUrl = 'http://10.0.2.2:8000/api';

// For physical device on same network:
static String baseUrl = 'http://192.168.1.XX:8000/api';

// For production:
static String baseUrl = 'https://yourdomain.com/api';
```

Or use the **Server Config** button on the login screen to change it at runtime.

### Run on Android Device

```bash
# Debug mode
flutter run

# Specific device
flutter devices
flutter run -d <device-id>
```

### Build Release APK

```bash
flutter build apk --release --split-per-abi
```

The APK will be at `build/app/outputs/flutter-apk/`.

---

## 3. Testing the System

### Quick Test Flow (Without NFC)

1. Start the Django backend: `python manage.py runserver 0.0.0.0:8000`
2. Run the Flutter app on your Android device/emulator
3. Login with `admin` / `admin123`
4. Tap the **"Enter UID manually"** button on the Scan Screen
5. **Simulate a Blank Tag:** Enter `NEWTAG111`. A bottom sheet will open letting you create a new team or assign to an existing pre-registered slot.
6. **Simulate an Existing Tag:** Enter a sample UID from the seed output.
7. Tap the distribution buttons (Breakfast, Lunch, Dinner, Goodie)
8. Try tapping the same button again — should show "Already Collected" (red)

### With Real NFC Tags

1. Enable NFC on your Android device
2. Hold an NXP MIFARE/Ultralight tag near the device
3. The app reads the hardware UID automatically
4. **Blank Tag:** If unregistered, the Registration bottom-sheet appears.
5. **Registered Tag:** Participant info appears.
6. Use the buttons to distribute items


### API Testing with curl

See [API_TESTS.md](API_TESTS.md) for curl examples.

---

## 4. Registering Real NFC Tags (Production Workflow)

To register real NFC UIDs in the database, follow the two-step Pre-Registration Workflow:

### Step 1: Bulk Import via CSV
Before the event, prepare a CSV file with columns: `Name`, `College`, `Team Name` (optional).
Load them into the backend:
```bash
python manage.py import_prereg /path/to/data.csv
```
This sets up `PreRegisteredMember` slots.

### Step 2: Physical Tag Linking (Event Day)
1. Open the Flutter app to the **Scan** tab.
2. Tap a physical (blank) NFC tag to the phone.
3. The screen will prompt the Registration Bottom Sheet.
4. Select the Team and Name of the participant standing in front of you.
5. Tap **Register Tag**. The tag is now permanently bound to the participant in the database!

*(Optional)* You can also still use the **Django Admin** (`http://localhost:8000/admin/events/participant/add/`) or **Django Shell** for emergency manual overrides.


---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `NFC not available` | Enable NFC in Android Settings |
| `Network error` on app | Check server URL, ensure firewall allows port 8000 |
| `Connection refused` (emulator) | Use `10.0.2.2:8000` instead of `localhost` |
| `Connection refused` (device) | Use your computer's LAN IP, run server with `0.0.0.0:8000` |
| `401 Unauthorized` | Login again, the token might be expired |
| Django `ModuleNotFoundError` | Activate the virtual environment first |
