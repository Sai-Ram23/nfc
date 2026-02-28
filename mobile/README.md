# BREACH GATE — Mobile App (Flutter V3.1)

The Flutter mobile application for the BREACH GATE NFC Event Distribution System. Provides a 6-tab admin interface for NFC scanning, pre-registration mapping, team creation, team-aware distribution, real-time dashboards, attendee management, and CSV/XLSX export.

---

## Screens & Navigation

The app uses a `HomeShell` with a 6-tab `NavigationBar` and `IndexedStack` for tab state preservation.

### 1. Splash Screen (`splash_screen.dart`)
- Animated Trojan Horse logo with elastic scale, pulsing green glow, and slide-up "BREACH GATE" text.
- Auto-detects saved auth token and navigates accordingly.

### 2. Login Screen (`login_screen.dart`)
- BREACH GATE branded authentication with Trojan Horse logo.
- Admin enters credentials → `POST /api/login/` → Token cached in `SharedPreferences`.

### 3. Scan Tab (`scan_screen.dart`)
- Checks NFC availability using `NfcManager.instance.checkAvailability()`. Pulsing green Trojan Horse icon indicates readiness.
- Reads UID using platform-specific classes: `NfcTagAndroid` on Android; `MiFareIos`, `Iso7816Ios`, `Iso15693Ios`, `FeliCaIos` on iOS.
- **Participant Profile Card**: Name, college, team badge (color dot + name), team size, UID.
- **Chronological Matrix**: 6 distribution slots dynamically sorted by state:
  - 🟢 AVAILABLE → 🔒 LOCKED → ✅ COLLECTED → ❌ EXPIRED
- **Team Context Section**: Per-item progress bars, "View Members" modal, "Distribute to Entire Team" button.
- **Pre-Registration Flow**: When scanning a blank NFC tag (`unregistered` API response), an organizer flow opens via bottom sheet:
  - Fetches teams with unassigned pre-registered slots.
  - Allows organizer to link the tag to a specific team/member, creating a `Participant`.
- Manual UID entry popup for emulator testing.

### 4. Teams Tab (`teams_screen.dart`)
- **Team Management**: Displays a list of all pre-registered teams and their available `PreRegisteredMember` slots.
- **On-the-fly Creation**: Organizer can physically create a *"New Team"* right from the mobile UI.
- **Dynamic Slots**: Adds new single `PreRegisteredMember` slots to any existing team if the pre-allocated slots fill up.
- Bottom sheet driven UX for quick data entry.

### 5. Dashboard Tab (`dashboard_screen.dart`)
- **Stats Row**: 3 cards showing Participants, Teams, and Solo counts.
- **Distribution Progress**: 6 rows with emoji icons, progress bars, and `given/total (%)` labels.
- **Team Leaderboard**: Ranked by completion rate with 🥇🥈🥉 medals and team color dots.
- Pull-to-refresh support.

### 6. Attendees Tab (`attendees_screen.dart`)
- **Debounced Search**: Filter by name, UID, or team name (400ms debounce).
- **View Toggle**: Individual list vs Team groups.
- **Filter Chips**: All / Complete / Missing items.
- **Attendee Cards**: Avatar with team color, UID badge, collection progress bar.
- **Expandable Team Groups**: Tap to reveal members with individual collection counts.

### 7. Manual Tab (`manual_screen.dart`)
- **Dynamic Search**: Debounced search across name, UID, and team name.
- **Filter Chips**: All / Teams / Solo.
- **Team Cards**: Expandable with member list, per-item progress, and inline GIVE buttons.
- **Solo Cards**: Individual participant view with item grid and GIVE buttons.
- **Export Button**: Opens a bottom sheet to choose CSV or XLSX export format.

### 8. Settings Tab (`settings_screen.dart`)
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
├── home_shell.dart           # 6-tab NavigationBar + IndexedStack
├── scan_screen.dart          # NFC scanning, registration sheet, distribution
├── teams_screen.dart         # Manage pre-reg teams, create teams/members
├── dashboard_screen.dart     # Stats, progress bars, team leaderboard
├── attendees_screen.dart     # Search, filters, individual/team views
├── manual_screen.dart        # Participant browser + inline distribute + export
├── settings_screen.dart      # Server config, event timing, about
├── export_service.dart       # CSV / multi-sheet XLSX + native share sheet
├── models.dart               # Team, Participant, PreregTeam, PreregMember
├── api_service.dart          # HTTP client, token persistence, 16 APIs
└── utils/
    └── time_manager.dart     # 48-hour event slot calculations
```

### Key Dependencies
| Package | Version | Purpose |
|---|---|---|
| `nfc_manager` | ^4.1.1 | NFC tag reading — platform-specific tag classes for Android & iOS |
| `google_fonts` | ^6.1.0 | Inter font family for modern typography |
| `shared_preferences` | ^2.2.2 | Local token + config persistence |
| `intl` | ^0.20.2 | Date/time formatting |
| `http` | ^1.1.0 | REST API communication |
| `excel` | ^4.0.3 | Multi-sheet XLSX file generation |
| `csv` | ^6.0.0 | CSV string generation |
| `share_plus` | ^7.2.1 | Native share sheet for file export |
| `path_provider` | ^2.1.1 | Temp directory for export files |

### The `ExportService` (`lib/export_service.dart`)
Handles all export logic:
- `exportToCsv(data)` — generates a CSV with UID, Name, College, Team, and YES/NO per item.
- `exportToExcel(data)` — generates an XLSX with 3 sheets:
  - **Participants**: basic info list.
  - **Distribution Status**: ✓ for each collected item.
  - **Team Summary**: team completion stats and percentage.
- Both methods save to a temp file and invoke the native share sheet via `share_plus`.

### The `TimeManager` (`lib/utils/time_manager.dart`)
Singleton that maps absolute clock time against relative offsets from the Event Start Date. Determines which of the 6 slots are available, locked, collected, or expired across a 48-hour window.

---

## Running

### Requirements
- Flutter SDK `3.x`
- Kotlin `2.1.0+` (configured in `android/settings.gradle.kts`)
- Android device with NFC (manual entry popup available for emulator testing)

### Commands
```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Static analysis
flutter analyze

# Build release APKs (split by ABI)
flutter build apk --release --split-per-abi

# Regenerate app icons (after changing Trojan_Horse_Icon.png)
dart run flutter_launcher_icons:main
```
