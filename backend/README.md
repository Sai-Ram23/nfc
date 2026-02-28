# BREACH GATE — Backend Server (Django V3.1)

The Django REST API backend for the BREACH GATE NFC Event Distribution System. Serves as the single source of truth for participant validation, atomic food distribution, team management, and analytical statistics.

---

## Core Architecture

Built on **Django 5.0** + **Django REST Framework (DRF)** with SQLite (development) or any Django-supported database.

### Models (`events/models.py`)

| Model | Fields | Purpose |
|---|---|---|
| **Team** | `team_id` (UUID), `name`, `color` (hex) | Group identity with visual color coding |
| **PreRegisteredMember** | `team` (FK), `name`, `college`, `is_linked` | A placeholder slot for a participant before an NFC UID is assigned |
| **Participant** | `uid`, `name`, `college`, `team` (FK), 6 distribution booleans + timestamps | Attendee state tracking following successful NFC assignment |

- `Team.team_id` is auto-generated (`uuid4`) for API-safe lookups.
- `PreRegisteredMember` slots are created in bulk via CSV or created on-the-fly from the mobile app.
- `Participant.uid` is the physical NFC tag hex identifier (uppercase, unique). Once linked, a `PreRegisteredMember` slot is marked `is_linked=True`.
- Each distribution slot has a boolean (`lunch`) and a timestamp (`lunch_time`) recording exact collection time.

### API Endpoints (`events/urls.py` & `events/views.py`)

| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| `POST` | `/api/login/` | No | Validate credentials, issue DRF Token |
| `POST` | `/api/scan/` | Token | Look up participant by UID, return full state + team info (or `'unregistered'`) |
| `GET` | `/api/prereg/teams/` | Token | Sub-list of teams containing unlinked `PreRegisteredMember` slots |
| `POST` | `/api/prereg/register/` | Token | Atomically link a blank NFC tag to a `PreRegisteredMember`, creating a `Participant` |
| `POST` | `/api/prereg/teams/create/` | Token | Create a new `Team` on-the-fly from the mobile app |
| `POST` | `/api/prereg/teams/<team_id>/add-member/` | Token | Add a single `PreRegisteredMember` to an existing team |
| `POST` | `/api/give-registration/` | Token | Atomic registration goodies distribution |
| `POST` | `/api/give-breakfast/` | Token | Atomic breakfast distribution |
| `POST` | `/api/give-lunch/` | Token | Atomic lunch distribution |
| `POST` | `/api/give-snacks/` | Token | Atomic snacks distribution |
| `POST` | `/api/give-dinner/` | Token | Atomic dinner distribution |
| `POST` | `/api/give-midnight-snacks/` | Token | Atomic midnight snacks distribution |
| `GET` | `/api/team/<team_id>/` | Token | Team details, members, per-item progress |
| `POST` | `/api/distribute-team/` | Token | Bulk distribute one item to entire team |
| `GET` | `/api/stats/` | Token | Dashboard stats (totals, per-item counts, team breakdown) |
| `GET` | `/api/teams/stats/` | Token | Team leaderboard (completion rates, rankings) |
| `GET` | `/api/attendees/` | Token | Searchable attendee list (supports `?search=`, `?filter=`, `?view=team\|individual`) |

> The `/api/attendees/` endpoint is also used by the Flutter export feature to fetch all participant data for CSV/XLSX generation.

---

## Technical Highlights

### 1. Atomic Database Locking
All 6 distribution endpoints use:
```python
with transaction.atomic():
    participant = Participant.objects.select_for_update().get(uid=uid)
```
This locks the SQL row natively, preventing race conditions when multiple admin devices scan the same tag simultaneously.

### 2. Team Bulk Distribution
`POST /api/distribute-team/` accepts `team_id` + `item` and iterates all team members. Members who already collected the item are skipped. Returns a summary: `"Breakfast given to 3 of 4 members (1 already collected)"`.

### 3. Time-Agnostic Processing
The backend is the authority on **data safety**, not timing. Time-based slot locking is handled entirely on the mobile client. The backend accepts any authenticated distribution request, enabling admin overrides when needed.

---

## Setup

```bash
# 1. Create & activate virtual environment
python -m venv venv
.\venv\Scripts\activate        # Windows
source venv/bin/activate       # Linux/macOS

# 2. Install dependencies
pip install -r requirements.txt

# 3. Run migrations
python manage.py migrate

# 4. Import teams and members from a CSV (Pre-registration)
python manage.py import_prereg data.csv

# 5. Start server (bind to 0.0.0.0 for LAN/hotspot access)
python manage.py runserver 0.0.0.0:8000
```

> **Firewall**: Ensure inbound traffic on Port 8000 is allowed for mobile hotspot scanning.

---

## Testing

**48 automated tests** covering authorization, NFC scan, pre-registration flows (linking, team creation), all 6 distribution endpoints, duplicate collision detection, team CRUD, bulk distribution, dashboard stats, team leaderboard, and attendee search/filtering.

**Coverage: 100% across all API views, models, and serializers.**

```bash
python manage.py test events -v 2
```
