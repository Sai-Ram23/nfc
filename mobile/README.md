# NFC Event Manager — Mobile App (Flutter V2)

This is the Flutter mobile application for the NFC Event Management System. It allows event organizers (counter staff) to use their Android devices as NFC readers to distribute timed food and goodies based on a synchronized 48-hour event window.

---

## App Flow & Screens

### 1. Initialization (`main.dart`)
- **AppInitializer**: The app always starts here. It initializes the `TimeManager` and checks `SharedPreferences` for a saved authentication token.
- **Routing**: 
  - If a valid token exists, it routes directly to the **Scan Screen**.
  - If no token exists, it routes to the **Login Screen**.

### 2. Authentication (`login_screen.dart`)
- Administrators enter their username and password.
- **Server Config & Timing**: A hidden settings panel allows changing the backend API URL and selecting the **Event Start Date (Day 1)** via a native Date Picker. This synchronizes all countdown logic for distribution.
- On success, the DRF Auth Token is saved to local storage, and the user is navigated to the Scan Screen.

### 3. NFC Scanning (`scan_screen.dart`)
- The app initializes the `nfc_manager` plugin and starts listening for NFC tags.
- The UI shows a pulsing glowing green NFC icon indicating it's ready to scan.
- **Hardware Handling**: When a physical NFC tag is tapped, the `onDiscovered` callback triggers.
- **UID Extraction**: The app parses the tag to extract the hardware UID. It safely handles multiple tag technologies to ensure maximum compatibility. The raw byte array is converted into an **uppercase Hex string** (e.g., `04A23B1C5D6E80`).
- The app makes a `POST /api/scan/` request to the backend.

### 4. Participant View (Chronological Matrix)
- If the backend confirms the UID is registered, the UI transitions to the participant view.
- **User Profile**: Displays the attendee Name, College, and a Monospace UID Badge.
- **Dynamic Sorted Logic**: 6 distribution slots (Registration, Breakfast, Lunch, Snacks, Dinner, Midnight Snacks) are rendered based on the current time relative to the Event Start Date:
  - 🟢 **AVAILABLE NOW**: Bumped to the top, pulsing border, active "Collect" button.
  - 🔒 **LOCKED**: Greyscale, explicit countdown text (e.g., `Opens in 14h 22m`).
  - ✅ **COLLECTED**: Stays near the bottom, stamped with exactly when it was collected.
  - ❌ **EXPIRED**: Absolute bottom, strike-through text indicating the time window was missed.

### 5. Distribution Action & Feedback
- When an active button is tapped, a POST request is sent to the corresponding backend atomic endpoint (`/api/give-lunch/`).
- **SnackBars**: Modern top-anchored Toast notifications provide instant feedback:
  - **Success**: Green border toast + heavy haptic vibration.
  - **Duplicate/Error**: Red border toast + error message.

---

## Architecture & Utilities

### The `TimeManager` (`lib/utils/time_manager.dart`)
This crucial singleton handles mapping absolute UTC clock time against relative offsets to determine exactly which of the 6 slots are open, closed, or expired gracefully across the two-day event. It stores the `eventStartDate` securely on the device.

## Folder Structure

```text
lib/
├── main.dart                 # Theme config (Black/Green) and routing boundary
├── models.dart               # Data classes (Participant, DistributionResponse)
├── api_service.dart          # HTTP client layer & Token persistence
├── login_screen.dart         # Auth UI & Environment Settings
├── scan_screen.dart          # Core NFC logic, dynamic UI, and Toasts
└── utils/
    └── time_manager.dart     # Dynamic timeframe calculations
```

## Running the App

### Requirements
- Flutter SDK `3.x`
- Android Device with NFC (The app includes a "manual entry" popup for emulator testing).

### Commands
```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build Android APK
flutter build apk --release --split-per-abi
```
