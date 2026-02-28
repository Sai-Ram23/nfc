# BREACH GATE — NFC Event Distribution System (V3.1)

A robust NFC-based event management system for **Siege of Troy** at **Malla Reddy University**. Built with a Django backend and Flutter frontend, it orchestrates team-aware item distribution (Registration, Meals, Snacks) across a 48-hour event using physical NFC tags and atomic database transactions.

## Table of Contents
- [App Flow & Architecture](#app-flow--architecture)
- [Backend Structure](#backend-structure)
- [Frontend Structure](#frontend-structure)
- [Team System](#team-system)
- [Time-Based Distribution Logic](#time-based-distribution-logic)
- [Export Functionality](#export-functionality)
- [Setup & Deployment](#setup--deployment)
- [Testing](#testing)

---

## Complete Application Flow

The life cycle of the application is broken down into two main phases: **Pre-Event Preparation** and **Event Day Operations**.

### Phase 1: Pre-Event Preparation
Before the event starts, the organizers use the backend to define the teams and the expected participants.
1. **Bulk Import:** Organizers upload a CSV containing Team Names, Participant Names, and College details. 
2. **Backend Processing:** `import_prereg.py` script parses the file, creates `Team` records, and provisions blank `PreRegisteredMember` slots for every member on the list.
3. *Alternative:* Organizers can also use the mobile app's **Teams Tab** to manually create new teams and append `PreRegisteredMember` slots on the fly if last-minute additions arise.

### Phase 2: Event Day Operations
During the event, blank NFC tags are rapidly assigned and then utilized for atomic distribution tracking.

#### Step 1: Authentication
- The app launches. If no token is found, the admin inputs credentials → `POST /api/login/` → Token is issued and cached locally.

#### Step 2: Tag Linking (The Registration Desk)
- A participant arrives and receives a **blank NFC ID card**.
- The organizer taps the blank card on their phone using the mobile app's **Scan** tab.
- **Backend Response:** Returns an `unregistered` status.
- **Mobile Action:** The app detects this and pops open a bottom sheet.
  - The organizer sees a list of all Teams with empty slots.
  - The organizer selects the requested Team, selects the Participant's pre-loaded Name, and confirms.
- **Atomic Linking:** A `POST /api/prereg/register/` call links the physical NFC UID to that pre-recorded slot, finalizing them as a true `Participant` in the system.

#### Step 3: Distribution Tracking (The Food Stalls)
- Now fully registered, whenever the participant taps their NFC tag at a food stall, the app pulls their **Profile Card** (Name, College, Team).
- **Chronological Matrix:** The app displays 6 distribution slots.
  - 🟢 **AVAILABLE NOW** — bright green border, active "Collect" button.
  - 🔒 **LOCKED** — greyed out (e.g. `Opens in 14h 22m`).
  - ✅ **COLLECTED** — stamped with collection time.
  - ❌ **EXPIRED** — strike-through text.
- **Atomic Distribution:** Tapping "Collect Lunch" sends a POST request. The backend locks the database row using `transaction.atomic()`, preventing double-scans if multiple admins tap the card simultaneously.

#### Step 4: Team Bulk Operations (Optional)
- From the Scan tab, an organizer can hit **"Distribute to Entire Team"**.
- This sweeps through the participant's team array and bulk-approves an item for all uncollected members at once.

#### Step 5: Oversight & Export (The Admin Dashboard)
- Organizers monitor real-time completion charts and team leaderboards in the **Dashboard** Tab.
- At the end of the event, organizers extract the records using the **Export** button in the **Manual** Tab, which generates a comprehensive XLSX audit log of all distribution timestamps to send via native share sheet.

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
| `POST` | `/api/prereg/register/` | Link a blank NFC UID to a pre-registered member slot |
| `GET` | `/api/prereg/teams/` | List all teams with unlinked member slots for registration dropdowns |
| `POST` | `/api/prereg/teams/create/` | Create a new team on the fly from the mobile app |
| `POST` | `/api/prereg/teams/<team_id>/add-member/` | Add a single pre-registered member slot to an existing team |
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

### 6-Tab Navigation
| Tab | Screen | Purpose |
|---|---|---|
| **Scan** | `scan_screen.dart` | NFC scanning, tag registration, team context, distribution |
| **Teams** | `teams_screen.dart` | Manage pre-registered teams, create teams on the fly, add member slots |
| **Dashboard** | `dashboard_screen.dart` | Stats cards, distribution progress bars, team leaderboard |
| **Attendees** | `attendees_screen.dart` | Searchable list, filter chips, individual/team views |
| **Manual** | `manual_screen.dart` | Participant browser with search/filter/distribute + CSV/XLSX export |
| **Settings** | `settings_screen.dart` | Server URL config, event date picker, about, logout |

### File Structure
```text
lib/
├── main.dart                 # BreachGateApp entry point, dark theme
├── splash_screen.dart        # Animated Trojan Horse logo splash
├── login_screen.dart         # BREACH GATE branded auth screen
├── home_shell.dart           # 6-tab NavigationBar + IndexedStack
├── scan_screen.dart          # NFC scanning, tag registration sheet, team context, distribution
├── teams_screen.dart         # Bottom-sheet heavy screen for on-the-fly team creation/slot addition
├── dashboard_screen.dart     # Stats, progress, team leaderboard
├── attendees_screen.dart     # Search, filters, individual/team views
├── manual_screen.dart        # Participant browser + inline distribute + export
├── settings_screen.dart      # Server config, event timing, about
├── export_service.dart       # CSV/XLSX generation + share sheet
├── models.dart               # Data classes (Team, Participant, PreregTeam, etc.)
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

## Export Functionality

The **Manual** tab includes an export button that generates a file and opens the native share sheet:

| Format | Contents |
|---|---|
| **CSV** | Single sheet with all participants, UID, Name, College, Team, and item collection status (YES/NO) |
| **XLSX** | 3 sheets — "Participants", "Distribution Status" (✓ per item), "Team Summary" (completion %) |

Files are named `BreachGate_Export_YYYYMMDD_HHmmss.csv/.xlsx` and saved to a temp directory before sharing.

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
> **Requirements**: Flutter SDK 3.x · Android device with NFC · Kotlin 2.1.0+ in Gradle

### Build APK
```bash
flutter build apk --release --split-per-abi
```

---

## Testing

### Backend (48 Tests, 100% Coverage)
```bash
cd backend
python manage.py test events -v 2
```
Covers: authentication, NFC scan, pre-registration linking, on-the-fly team creation, 6 distribution endpoints, duplicate collision detection, team details, bulk distribution, dashboard stats, team leaderboard, attendee search/filters.

### Frontend
```bash
cd mobile
flutter analyze      # Zero issues
flutter test
```
