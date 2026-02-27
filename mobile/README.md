# BREACH GATE — Mobile App (Flutter V3)

The Flutter mobile application for the BREACH GATE NFC Event Distribution System. Provides a 5-tab admin interface for NFC scanning, team-aware distribution, real-time dashboards, attendee management, and manual distribution.

---

## Screens & Navigation

The app uses a `HomeShell` with a 5-tab `NavigationBar` and `IndexedStack` for tab state preservation.

### 1. Splash Screen (`splash_screen.dart`)
- Animated Trojan Horse logo with elastic scale, pulsing green glow, and slide-up "BREACH GATE" text.
- Auto-detects saved auth token and navigates accordingly.

### 2. Login Screen (`login_screen.dart`)
- BREACH GATE branded authentication with Trojan Horse logo.
- Admin enters credentials → `POST /api/login/` → Token cached in `SharedPreferences`.

### 3. Scan Tab (`scan_screen.dart`)
- Initializes NFC hardware via `nfc_manager`. Pulsing green icon indicates readiness.
- Reads UID from multiple tag technologies (NFCA, MIFARE, ISO-DEP, NFCV).
- **Participant Profile Card**: Name, college, team badge (color dot + name), team size, UID.
- **Chronological Matrix**: 6 distribution slots dynamically sorted by state:
  - 🟢 AVAILABLE → 🔒 LOCKED → ✅ COLLECTED → ❌ EXPIRED
- **Team Context Section**: Per-item progress bars, "View Members" modal, "Distribute to Entire Team" button.
- Manual UID entry popup for emulator testing.

### 4. Dashboard Tab (`dashboard_screen.dart`)
- **Stats Row**: 3 cards showing Participants, Teams, and Solo counts.
- **Distribution Progress**: 6 rows with emoji icons, progress bars, and `given/total (%)` labels.
- **Team Leaderboard**: Ranked by completion rate with 🥇🥈🥉 medals and team color dots.
- Pull-to-refresh support.

### 5. Attendees Tab (`attendees_screen.dart`)
- **Debounced Search**: Filter by name, UID, or team name (400ms debounce).
- **View Toggle**: Individual list vs Team groups.
- **Filter Chips**: All / Complete / Missing items.
- **Attendee Cards**: Avatar with team color, UID badge, collection progress bar.
- **Expandable Team Groups**: Tap to reveal members with individual collection counts.

### 6. Manual Tab (`manual_screen.dart`)
- UID text entry with monospace input and search button.
- Participant info card with team context.
- 2-column item grid with GIVE/✓ states and collection timestamps.
- Tap-to-distribute without NFC hardware.

### 7. Settings Tab (`settings_screen.dart`)
- **Server Configuration**: Backend URL input with Save button and visual "Saved!" feedback.
- **Event Timing**: Date picker for Event Start Date, Day 1/Day 2 slot display.
- **About**: Trojan Horse logo, BREACH GATE branding, version info.
- **Sign Out**: Red button with confirmation dialog.

---

## Architecture

### File Structure
```text
lib/
├── main.dart                 # BreachGateApp entry, dark theme, Google Fonts
├── splash_screen.dart        # Animated Trojan Horse splash
├── login_screen.dart         # BREACH GATE branded auth
├── home_shell.dart           # 5-tab NavigationBar + IndexedStack
├── scan_screen.dart          # NFC scanning, team context, distribution
├── dashboard_screen.dart     # Stats, progress bars, team leaderboard
├── attendees_screen.dart     # Search, filters, individual/team views
├── manual_screen.dart        # UID-based manual distribution
├── settings_screen.dart      # Server config, event timing, about
├── models.dart               # Team, Participant, TeamMember, TeamDetails,
│                             # TeamDistributionResponse, DashboardStats
├── api_service.dart          # HTTP client, token persistence, 12+ methods
└── utils/
    └── time_manager.dart     # 48-hour event slot calculations
```

### Key Dependencies
| Package | Purpose |
|---|---|
| `nfc_manager` | NFC tag reading across multiple technologies |
| `google_fonts` | Inter font family for modern typography |
| `shared_preferences` | Local token + config persistence |
| `intl` | Date/time formatting |
| `http` | REST API communication |

### The `TimeManager` (`lib/utils/time_manager.dart`)
Singleton that maps absolute clock time against relative offsets from the Event Start Date. Determines which of the 6 slots are available, locked, collected, or expired across a 48-hour window.

---

## Running

### Requirements
- Flutter SDK `3.x`
- Android device with NFC (manual entry popup available for emulator testing)

### Commands
```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Static analysis
flutter analyze

# Build APK
flutter build apk --release --split-per-abi
```
