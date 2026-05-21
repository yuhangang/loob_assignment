# Loob Unified App: Mobile (Flutter)

This directory contains the cross-platform mobile application for the Loob Unified App, supporting both Tealive and Baskbear through a dynamic "Twin App" theming system.

## Architecture

The app follows a **Feature-Driven (Domain-Driven)** modular structure to ensure maintainability as it scales across multiple countries.

### Tech Stack
*   **Framework:** Flutter
*   **State Management:** BLoC (for complex, asynchronous flows) & Cubit (for simple UI toggles).
*   **Dependency Injection:** `get_it` + `injectable`
*   **Networking:** `dio`
*   **Authentication:** `firebase_auth` (Phone/OTP)
*   **Local Caching (Relational):** `drift` (SQL) for Cart and Active Orders.
*   **Local Caching (Key-Value):** `shared_preferences` / `hive` for localized copy and app settings.

## Local Setup

### Prerequisites
*   Flutter SDK (Stable Channel)
*   Android Studio / Xcode for emulators/simulators

### Installation
1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

### Running the App
To run the application on a connected device or emulator:
```bash
flutter run
```

## Core Concepts

*   **The "Switch" Theme Engine:** The app does not display both brands in a generic list. Instead, users toggle between a "Tealive Mode" (Purple/Playful) and a "Baskbear Mode" (Orange/Urban). This is handled via a global `ThemeCubit` that injects the appropriate `ThemeData` down the widget tree.
*   **API Interceptors:** The Dio client is configured with interceptors that automatically inject the Firebase JWT token, the `X-Country-Code`, and the `Accept-Language` headers required by the Go backend.
*   **Mobile-First Layout:** The app is strictly locked to Portrait Mode. It uses responsive constraints (`Flexible`, `Expanded`) rather than fixed heights to ensure that verbose Southeast Asian languages (like Thai) and OS-level accessibility font scaling do not break the UI.