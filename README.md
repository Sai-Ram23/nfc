# NFC Event Manager (V2)

A robust, cross-platform NFC event management system designed to track attendee distribution logic (Registration, Meals, Snacks) across a multi-day event. Built with a Django backend and a Flutter frontend.

## Table of Contents
- [App Flow & Architecture](#app-flow--architecture)
- [Backend Structure](#backend-structure)
- [Frontend Structure](#frontend-structure)
- [Time-Based Distribution Logic](#time-based-distribution-logic)
- [Setup & Deployment](#setup--deployment)

---

## App Flow & Architecture

The application workflow bridges a physical NFC tag scan on a mobile device to a secured database transaction on a local or cloud server.

### 1. Initialization & Configuration
When the Administrator opens the mobile app, the `AppInitializer` checks `SharedPreferences` for an existing authentication token.
- **Unauthenticated**: The user is routed to the Login Screen.
- **Server Configuration**: The system defaults to `http://10.0.2.2:8000/api` (Android emulator localhost). If connecting via Mobile Hotspot or a Cloud Domain, the user taps the settings gear icon to update the **Server URL** (e.g., `http://192.168.1.100:8000/api`).
- **Event Timing Configuration**: Under the Server URL input, the admin designates the **Event Start Date (Day 1)** using a native Date Picker. This instantly recalculates all backend interaction windows locking or unlocking specific meals.

### 2. Administrator Login
- The admin inputs their credentials (`admin` / `admin123`).
- A `POST` payload is fired to Django's `/api/login/` endpoint.
- Django validates the user, issues a unique Auth Token, and returns `{ status: 'success', token: '...' }`.
- The Mobile App securely caches this token and navigates to the **Scan Screen**.

### 3. NFC Tag Scanning & Discovery
- The device initializes the NFC hardware. A pulsing glowing green logo indicates readiness.
- An attendee taps their smart-card or NFC wristband to the administrator's device.
- The `nfc_manager` intercepts the hardware payload, attempting to read standard identifiers (NFCA, MIFARE, ISO-DEP, NFCV).
- The raw byte array is parsed into a standardized Uppercase Hexadecimal `UID` (e.g., `04A23B1C5D6E80`).

### 4. Participant Validation
- The Mobile App fires a `POST /api/scan/` payload with the `uid` parameter to the Django server.
- The Backend queries `Participant.objects.get(uid=uid)`.
- If a match is found, Django serializes all biographical data (Name, College) alongside 6 distinct Booleans and Timestamps for each distribution slot (Registration, Breakfast, Lunch, Snacks, Dinner, Midnight Snacks).
- The App parses the data into the local `Participant` data model and redraws the UI.

### 5. Dynamic Time-Based UI (Chronological Matrix)
The app calculates exactly what the administrator *should* be doing at that very second.
- The `TimeManager` maps the 6 distribution slots against the current clock time relative to the chosen **Event Start Date**.
- The UI builds 6 chronological cards, intelligently sorted:
  1. **AVAILABLE NOW** (Top of list, bright green border, glowing pulse, active collect button)
  2. **LOCKED** (Below available items, greyscaled, explicit countdown string like `Opens in 14h 22m`)
  3. **COLLECTED** (Bottom half, muted dark green, stamped with exact collection timestamp)
  4. **EXPIRED** (Absolute bottom, strike-through text, opacity reduced)
- A dynamic segment bar instantly visualizes progress (e.g., `2 of 6 items collected`).

### 6. Atomic Food Distribution
- The administrator taps **"Collect Lunch"**.
- A `POST /api/give-lunch/` request is fired containing the `UID`.
- **CRITICAL**: The backend wraps this query in a `transaction.atomic()` block and queries `Participant.objects.select_for_update()`. This literally locks the SQL row natively in the database.
- The server checks if the user has already collected Lunch. If so, it rejects the request instantly (preventing duplicate food given out by two simultaneous admins).
- If clear, it sets `lunch = True`, injects `timezone.now()` into `lunch_time`, saves the model, releases the lock, and returns a success payload.
- The Flutter app triggers an aggressive Haptic Feedback vibration and a Top-Anchor green Toast notification dropping from the roof of the screen, confirming success and updating the UI card to **✓ COLLECTED**.

---

## Backend Structure

Built using **Django 5.0** and **Django REST Framework (DRF)**.

**Models (`events/models.py`)**
- `Participant`: The core entity.
  - Characteristics: `uid` (Unique Hex String), `name`, `college`.
  - States (Booleans): `registration_goodies`, `breakfast`, `lunch`, `snacks`, `dinner`, `midnight_snacks`.
  - Timestamps (DateTimeFields): Corresponding tracking variables for exact collection times.

**Endpoints (`events/views.py`)**
- `/api/login/`: Auth token generation.
- `/api/scan/`: Retreives participant state natively.
- `/api/give-X/`: 6 isolated endpoints orchestrating atomic SQL writes for the specific physical item (`give-registration`, `give-lunch`, etc.).
- `/api/stats/`: Returns comprehensive analytical dashboard numbers (Total registered, total meals served).

---

## Frontend Structure

Built using **Flutter 3+** executing the **Black & Green** Modern Aesthetic (`#00E676` primary green, `#1C1C1C` dark layouts).

**Core Files (`lib/`)**
- `main.dart`: MaterialApp entry point, global layout theming, and `AppInitializer` routing.
- `models.dart`: JSON-to-Dart translation objects (`Participant`, `DistributionResponse`).
- `api_service.dart`: Rest HTTP client injected safely with `auth_token` standard headers.
- `login_screen.dart`: Authentication boundary and Local Environment variable modifier (Server IP & Event Date).
- `scan_screen.dart`: The core chronological UI, hardware scanner listener, Toast master, and Animation Controller manager.
- `utils/time_manager.dart`: A sophisticated stateless utility determining exactly how the current timezone correlates against the exact offset specifications required for a 48-hour event window.

---

## Time-Based Distribution Logic

The application natively accounts for Day 1 and Day 2 transitions, leveraging 5-minute leeway grace boundaries.

*Relative to "Event Start Date"*
* **Registration & Goodies**: Day 1 | `08:00 AM - 12:00 PM`
* **Lunch**: Day 1 | `12:30 PM - 04:00 PM`
* **Evening Snacks**: Day 1 | `04:30 PM - 07:00 PM`
* **Dinner**: Day 1 | `08:00 PM - 11:00 PM`
* **Midnight Snacks**: Day 2 | `12:00 AM - 02:00 AM`
* **Breakfast**: Day 2 | `07:30 AM - 10:30 AM`

*Note: The Flutter UI determines these thresholds dynamically, but the physical backend Django Database will manually accept distribution POSTs at any time from an authenticated admin token. Time enforcement is handled organically at the UX level.*

---

## Setup & Deployment

### Backend (Django)
```bash
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_data --count 20
python manage.py runserver 0.0.0.0:8000
```
*Note: Make sure your Windows Defender firewall allows ingress traffic to Port 8000 to enable Hotspot LAN scanning.*

### Frontend (Flutter)
```bash
cd mobile
flutter clean
flutter pub get
flutter run
```
*Note: The NFC capability must be manually triggered on iOS within Xcode permissions, while Android merely requires standard `AndroidManifest.xml` hardware permissions.*
