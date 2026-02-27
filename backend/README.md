# NFC Event Manager — Backend Server (Django V2)

This is the Django backend for the NFC Event Management System. It serves as the single source of truth for the Android scanner app, orchestrating authentication, participant validation, atomic food distribution, and analytical statistics.

---

## Core Architecture

Built on **Django 5.0** alongside the **Django REST Framework (DRF)**.

### Models (`events/models.py`)
- **Participant**: Tracks the attendees and their event presence.
  - `uid` (CharField): The primary lookup key. This corresponds to the Physical hex identifier of the NFC card/wristband.
  - `name` & `college`: Basic biographical info.
  - **Distribution Booleans**: 6 distinct slots ensuring an item is only granted once (`registration_goodies`, `breakfast`, `lunch`, `snacks`, `dinner`, `midnight_snacks`).
  - **Distribution Timestamps** (`DateTimeField`): Records the exact `timezone.now()` when the boolean flips to True, preventing ambiguity.

### API Routing (`events/urls.py` & `events/views.py`)
- `POST /api/login/`: Validates standard User models and issues a `Token` for REST authorization.
- `POST /api/scan/`: Receives a physical `uid` and returns the serialized user model containing context about what they have and haven't collected.
- `POST /api/give-<X>/`: 6 distinct endpoints handling distribution logic.
- `GET /api/stats/`: Returns summation aggregates for the front-facing administrator dashboard.

---

## Technical Highlights

### 1. Atomic Database Locking
The event involves multiple administrators using different devices at the same physical counter. To prevent a "race condition" where two devices scan the exact same wristband at the exact same millisecond to give out "Lunch", the distribution requests are heavily guarded natively in the SQL database.

All distribution endpoints use the dual combination of:
1. `with transaction.atomic():` -> Guarantees the entire block either succeeds as a whole or fails completely without half-writing.
2. `Participant.objects.select_for_update().get(uid=uid)` -> Locks the physical SQL row natively. Any concurrent hits are queued, checked to see if it was already collected, and formally rejected as `already_collected`.

### 2. Time-Agnostic Processing
The backend acts as an absolute authority on *Data Safety* rather than *Data Timing*. The mobile application handles all "chronological lockouts" internally by comparing physical time to the "Event Start Date". The backend merely verifies the token, verifies the lock, and sets the timestamp, remaining agile enough to accept overrides if the admin forces an action.

---

## Setup & Deployment

1. **Activate Environment**
```bash
python -m venv venv
.\venv\Scripts\activate
```

2. **Install Dependencies**
```bash
pip install -r requirements.txt
```

3. **Database Migrations**
```bash
python manage.py makemigrations
python manage.py migrate
```

4. **Seed Mock Data**
(Generates the admin, secondary counter staff, and 20 sample participants)
```bash
python manage.py seed_data --count 20
```

5. **Run Development Server**
```bash
# To allow mobile hotspot connectivity, bind to 0.0.0.0
python manage.py runserver 0.0.0.0:8000
```

6. **Automated Testing**
Run the 14 integrated unit tests to verify authorization, atomic locks, duplicate collision detection, and invalid UID queries.
```bash
python manage.py test events
```
