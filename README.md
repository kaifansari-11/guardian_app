🛡️ Guardian: Your Personal Safety Shield
Guardian is a modern, high-stakes personal safety application designed to provide immediate assistance during emergencies. Built with Flutter and Firebase, the app combines a sleek Glassmorphic UI with robust background services to ensure help is always just a shake away.

🌐 The Guardian Ecosystem
Guardian isn't just an app; it's a full-stack security network:

Mobile Client (This Repo): The primary SOS trigger, location provider, and audio recorder.

Live Command Center: A web-based dashboard for trusted contacts to track SOS events in real-time.

Dashboard Repository: https://github.com/kaifansari-11/guardian_dashboard

Live Web Demo: https://guardian-live.netlify.app

🚀 Key Features
Shake-to-SOS: A background-listening engine that triggers an emergency state when a specific shake pattern is detected, even if the app is killed or the screen is locked.

Live Location Tracking: Automatically broadcasts precise GPS coordinates to trusted contacts via a secure, unique live dashboard link.

Automatic SMS Alerts: Instantly sends urgent messages containing your location and dashboard link to your pre-defined emergency list.

Audio Evidence Recording: Silently captures audio in 15-second chunks and uploads them to secure Firebase Storage as evidence.

Safety Modes:

Loud Mode: Triggers a high-decibel siren and auto-dials local emergency services.

Ghost Mode: Stealth activation with a "Disguise Screen" (Fake Calculator/Calendar) to hide app activity from intruders.

Master Privacy Control: A central switch to fully arm or disarm the background sensors according to user needs.

🎨 Design Philosophy
The app utilizes a Glassmorphic and high-contrast design to ensure readability and speed during high-stress situations.

Dynamic Visual States: The UI transitions from a calm Emerald Green (Protected) to a high-alert Crimson Red (Emergency) during an SOS trigger.

Dark Mode Support: Optimized for low-light environments and battery preservation.

Contextual Help: Integrated info-triggers across the settings to guide users on optimal setup.

🛠️ Technical Stack
Frontend: Flutter (Dart)

Backend: Firebase Authentication & Cloud Firestore (Real-time data sync)

Storage: Firebase Storage (Secure audio hosting)

Hardware Integration: Accelerometer (Sensors Plus), GPS (Geolocator), and Telephony API

Background Services: flutter_background_service for persistent monitoring

📦 Installation & Setup
Clone the Repository:

Bash
git clone https://github.com/kaifansari-11/guardian_app.git
Firebase Configuration:

Create a project in the Firebase Console.

Download google-services.json (Android) and place it in android/app/.

Download GoogleService-Info.plist (iOS) and place it in ios/Runner/.

Install Dependencies:

flutter pub get

Run the App:

flutter run

📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

Disclaimer: Guardian is a safety tool meant to assist in emergencies. It is not a replacement for professional emergency services (911/112/100).