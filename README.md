# BREACH GATE — NFC Event Distribution System (V3)

A robust NFC-based event management system for **Siege of Troy** at **Malla Reddy University**. Built with a Django backend and Flutter frontend, it orchestrates team-aware item distribution (Registration, Meals, Snacks) across a 48-hour event using physical NFC tags and atomic database transactions.

## Table of Contents
- [App Flow & Architecture](#app-flow--architecture)
- [Backend Structure](#backend-structure)
- [Frontend Structure](#frontend-structure)
- [Team System](#team-system)
- [Time-Based Distribution Logic](#time-based-distribution-logic)
- [Setup & Deployment](#setup--deployment)
- [Testing](#testing)

---

## App Flow & Architecture

### 1. Splash & Authentication
- The app launches with an animated **Trojan Horse** splash screen.
- `SharedPreferences` is checked for a saved auth token.
  - **Authenticated** → Navigates to the 5-tab Home Shell.
  - **Unauthenticated** → Navigates to the BREACH GATE Login Screen.
- Admin inputs credentials → `POST /api/login/` → Token is issued and cached locally.

### 2. NFC Tag Scanning
- The **Scan** tab initializes NFC hardware. A pulsing green NFC icon indicates readiness.
- When an NFC tag is tapped, the `nfc_manager` plugin reads the hardware UID across multiple technologies (NFCA, MIFARE, ISO-DEP, NFCV).
- The raw byte array is parsed into an **uppercase hexadecimal UID** (e.g., `5337EACC730001`).
- A `POST /api/scan/` request validates the UID and returns participant + team data.

### 3. Participant & Team Context
- The participant's **profile card** shows name, college, team badge (color dot + name), team size, and UID.
- If the participant belongs to a team, a **Team Context Section** appears showing:
  - Per-item progress bars (`Registration 2/4`, `Lunch 3/4`, etc.)
  - **"View Members"** modal with each member's collection progress.
  - **"Distribute to Entire Team"** button for bulk distribution.

### 4. Dynamic Time-Based UI (Chronological Matrix)
The `TimeManager` maps 6 distribution slots against the current clock relative to the **Event Start Date**:
1. 🟢 **AVAILABLE NOW** — bright green border, pulsing animation, active "Collect" button.
2. 🔒 **LOCKED** — greyscale, countdown text (`Opens in 14h 22m`).
3. ✅ **COLLECTED** — muted dark green, stamped with exact collection timestamp.
4. ❌ **EXPIRED** — strike-through text, reduced opacity.

### 5. Atomic Distribution
- Admin taps **"Collect Lunch"** → `POST /api/give-lunch/` with UID.
- Backend wraps the query in `transaction.atomic()` + `select_for_update()`, preventing race conditions across simultaneous admin devices.
- Success → green toast + haptic vibration. Duplicate → red toast + error message.

### 6. Team Bulk Distribution
- Admin taps **"Distribute to Entire Team"** → selects an item → `POST /api/distribute-team/`.
- Backend iterates all team members, skipping those who already collected, and returns a summary.

---

## Backend Structure

Built on **Django 5.0** + **Django REST Framework (DRF)**.

### Models
| Model | Purpose |
|---|---|
| `Team` | Team identity: `name`, `color` (hex), auto-generated `team_id` |
| `Participant` | Attendee with `uid`, `name`, `college`, FK to `Team`, 6 distribution booleans + timestamps |

### API Endpoints
| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/api/login/` | Auth token generation |
| `POST` | `/api/scan/` | Validate UID, return participant + team data |
| `POST` | `/api/give-registration/` | Atomic registration distribution |
| `POST` | `/api/give-breakfast/` | Atomic breakfast distribution |
| `POST` | `/api/give-lunch/` | Atomic lunch distribution |
| `POST` | `/api/give-snacks/` | Atomic snacks distribution |
| `POST` | `/api/give-dinner/` | Atomic dinner distribution |
| `POST` | `/api/give-midnight-snacks/` | Atomic midnight snacks distribution |
| `GET` | `/api/team/<team_id>/` | Team details + member list + progress |
| `POST` | `/api/distribute-team/` | Bulk distribute to entire team |
| `GET` | `/api/stats/` | Dashboard statistics (totals, per-item counts, team/solo breakdown) |
| `GET` | `/api/teams/stats/` | Team leaderboard (completion rates, rankings) |
| `GET` | `/api/attendees/` | Searchable attendee list with filters |

---

## Frontend Structure

Built with **Flutter 3+** using the **Black & Green** aesthetic (`#00E676` primary, `#000000` background).

### 5-Tab Navigation
| Tab | Screen | Purpose |
|---|---|---|
| **Scan** | `scan_screen.dart` | NFC scanning, participant view, team context, distribution |
| **Dashboard** | `dashboard_screen.dart` | Stats cards, distribution progress bars, team leaderboard |
| **Attendees** | `attendees_screen.dart` | Searchable list, filter chips, individual/team views |
| **Manual** | `manual_screen.dart` | UID text entry for non-NFC distribution |
| **Settings** | `settings_screen.dart` | Server URL config, event date picker, about, logout |

### File Structure
```text
lib/
├── main.dart                 # BreachGateApp entry point, dark theme
├── splash_screen.dart        # Animated Trojan Horse logo splash
├── login_screen.dart         # BREACH GATE branded auth screen
├── home_shell.dart           # 5-tab NavigationBar + IndexedStack
├── scan_screen.dart          # NFC scanning, team context, distribution
├── dashboard_screen.dart     # Stats, progress, team leaderboard
├── attendees_screen.dart     # Search, filters, individual/team views
├── manual_screen.dart        # UID-based manual distribution
├── settings_screen.dart      # Server config, event timing, about
├── models.dart               # Data classes (Team, Participant, etc.)
├── api_service.dart          # HTTP client + token persistence
└── utils/
    └── time_manager.dart     # Dynamic 48-hour event slot calculations
```

---

## Team System

Teams are a V3 addition enabling grouped distribution and progress tracking.

- **Team Model**: Each team has a `name`, `color` (hex), and auto-generated `team_id` (UUID).
- **Participant Link**: Participants can optionally belong to a team via FK.
- **Team Details API**: Returns all members with individual collection status + aggregated progress.
- **Bulk Distribution**: A single request distributes an item to all uncollected team members atomically.
- **Leaderboard**: Teams are ranked by overall completion rate across all 6 items.

---

## Time-Based Distribution Logic

All timing is relative to the configurable **Event Start Date (Day 1)**:

| Slot | Day | Time Window |
|---|---|---|
| Registration & Goodies | Day 1 | `08:00 AM – 12:00 PM` |
| Lunch | Day 1 | `12:30 PM – 04:00 PM` |
| Evening Snacks | Day 1 | `04:30 PM – 07:00 PM` |
| Dinner | Day 1 | `08:00 PM – 11:00 PM` |
| Midnight Snacks | Day 2 | `12:00 AM – 02:00 AM` |
| Breakfast | Day 2 | `07:30 AM – 10:30 AM` |

> **Note**: Time enforcement is handled at the UX level. The backend accepts distribution POSTs at any time from an authenticated admin, remaining agile for override scenarios.

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
> **Firewall**: Allow inbound traffic on Port 8000 for mobile hotspot LAN scanning.

### Frontend (Flutter)
```bash
cd mobile
flutter pub get
flutter run
```
> **NFC**: Android requires `AndroidManifest.xml` hardware permission. iOS requires Xcode NFC capability.

### Build APK
```bash
flutter build apk --release --split-per-abi
```

---

## Testing

### Backend (32 Tests)
```bash
cd backend
python manage.py test events -v 2
```
Covers: authentication, NFC scan, 6 distribution endpoints, duplicate collision detection, team details, bulk distribution, dashboard stats, team leaderboard, attendee search/filters.

### Frontend
```bash
cd mobile
flutter analyze
flutter test
```
