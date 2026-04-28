Guardian: Your Personal Safety Shield
Guardian is a modern, high-stakes personal safety application designed to provide immediate assistance during emergencies. Built with Flutter and Firebase, the app combines intuitive UI/UX with robust background services to ensure help is always just a shake away.

🛡️ Key Features
Shake-to-SOS: A background-listening engine that triggers an emergency state when a specific shake pattern is detected, even if the app is not open.

Live Location Tracking: Automatically broadcasts your real-time coordinates to your trusted contacts via a live dashboard link.

Automatic SMS Alerts: Sends urgent messages to your pre-defined emergency list the moment danger is detected.

Audio Evidence Recording: Silently captures audio in 15-second chunks and uploads them to secure cloud storage for later use as evidence.

Safety Modes:

Loud Mode: Triggers a high-decibel siren and auto-dials emergency services.

Ghost Mode: Stealth activation with a fake "Disguise Screen" to hide app activity from attackers.

Master Privacy Control: A central switch to fully arm or disarm the system according to user needs.

🎨 Design Philosophy
The app utilizes a Glassmorphic and high-contrast design.

Dynamic Visual States: The background transitions from a calm Emerald Green when protected to a high-alert Crimson Red during an SOS.

Dark Mode Support: A fully integrated dark theme for low-light environments and battery saving.

Contextual Help: Integrated information triggers across all settings to guide users on how each security feature works.

🛠️ Technical Stack
Frontend: Flutter (Dart)

Backend: Firebase Authentication & Cloud Firestore

Storage: Firebase Storage (for audio evidence)

Hardware Integration: Accelerometer (Sensors Plus), GPS (Geolocator), and Telephony API

Background Services: flutter_background_service for persistent monitoring

🚀 Installation
Clone the repository.

Add your own google-services.json (Android) and GoogleService-Info.plist (iOS) into the respective directories.

Run flutter pub get.

Execute flutter run to start the app.