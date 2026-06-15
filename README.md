# Guardian

A full-featured mobile safety application designed to provide instant emergency assistance through SOS alerts, shake detection, live location sharing, emergency contact notifications, and automated evidence collection.

**GitHub Repository:** https://github.com/kaifansari-11/guardian_app

---

## Overview

Guardian helps users stay protected during emergencies by providing a centralized personal safety platform. The application continuously monitors for emergency situations, enables instant SOS activation, shares live location with trusted contacts, records evidence automatically, and provides multiple emergency response modes for different scenarios.

---

## Features

### Secure Authentication

* User registration and login using Firebase Authentication
* Persistent user sessions
* Secure account management
* User-specific emergency data storage

### Emergency SOS System

* One-tap SOS activation
* Automatic shake-to-trigger emergency alerts
* Full-screen emergency alerts
* Background emergency detection
* Continuous SOS monitoring

### Live Location Tracking

* Real-time GPS location sharing
* Continuous location updates during emergencies
* Live tracking dashboard link generation
* Automatic location synchronization with Firebase

### Trusted Contacts Management

* Add and manage emergency contacts
* Cloud-synced contact storage
* Automatic SOS notifications
* Emergency contact dashboard

### Background Protection Service

* Foreground and background monitoring
* Continuous shake detection engine
* Persistent safety monitoring
* Emergency detection even when the app is minimized

### Emergency Response Modes

* **Loud Mode** – Activates siren and emergency calling
* **Ghost Mode** – Silent SOS activation with disguise screen
* **Custom Mode** – User-configurable emergency settings

### Safety Features

* Automatic emergency SMS alerts
* Emergency calling support (112)
* High-volume siren activation
* Full-screen emergency warning system
* Disguise mode for stealth protection

### Evidence Collection

* Automatic audio recording during emergencies
* Continuous recording loop
* Cloud-based evidence storage
* Secure evidence uploads using Cloudinary

### Customizable Settings

* Adjustable shake detection sensitivity
* Dark mode support
* Siren toggle
* Auto-call toggle
* Disguise mode toggle
* Master protection switch

---

## Technology Stack

| Layer               | Technology                  |
| ------------------- | --------------------------- |
| Framework           | Flutter                     |
| Language            | Dart                        |
| Authentication      | Firebase Authentication     |
| Database            | Cloud Firestore             |
| Storage             | Cloudinary                  |
| Location Services   | Geolocator                  |
| SMS Integration     | Telephony                   |
| Background Services | Flutter Background Service  |
| Notifications       | Flutter Local Notifications |
| Audio Recording     | Record Package              |
| Audio Playback      | Audioplayers                |
| State Storage       | Shared Preferences          |

---

## Installation and Setup

### Prerequisites

* Flutter SDK (Latest Stable Version)
* Firebase Project
* Android Studio
* Cloudinary Account

### Installation

```bash
# Clone the repository
git clone https://github.com/kaifansari-11/guardian_app.git

# Navigate to project folder
cd guardian_app

# Install dependencies
flutter pub get

# Configure Firebase
flutterfire configure

# Run the application
flutter run
```

---

## Firebase Configuration

1. Create a Firebase Project.
2. Enable Firebase Authentication.
3. Enable Cloud Firestore Database.
4. Download the Firebase configuration files:

   * google-services.json (Android)
   * GoogleService-Info.plist (iOS)
5. Add the files to the project.
6. Configure Firebase rules and collections.

---

## Core Application Flow

1. User logs into Guardian.
2. User adds trusted emergency contacts.
3. User enables Master Protection.
4. Guardian continuously monitors for shake events.
5. During an emergency:

   * SOS is triggered manually or by shake detection.
   * Emergency SMS alerts are sent.
   * Live location sharing begins.
   * Audio evidence recording starts.
   * Siren and emergency call actions execute based on selected mode.
6. Emergency data remains available for later review.

---

## Project Structure

```text
guardian_app/
├── lib/
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── login_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── trusted_contacts_screen.dart
│   │   └── disguise_screen.dart
│   │
│   ├── services/
│   │   ├── background_service.dart
│   │   ├── storage_service.dart
│   │   ├── audio_recorder_service.dart
│   │   └── fullscreen_alert_service.dart
│   │
│   └── main.dart
│
├── assets/
│   └── siren.mp3
│
├── android/
├── ios/
├── pubspec.yaml
└── README.md
```

---

## Future Enhancements

* AI-powered emergency risk prediction
* Real-time video evidence recording
* Nearby police station integration
* Emergency contact acknowledgement system
* Smartwatch emergency trigger support
* Offline emergency alert backup system

---

## Author

**Kaif Ansari**

Portfolio: https://kaifansari-dev.netlify.app

GitHub: https://github.com/kaifansari-11

---

## License

This project is intended for educational, portfolio, and learning purposes.
