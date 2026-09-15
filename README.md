# Senior Safety

Senior Safety is a Flutter Android application designed to help elderly people quickly notify their family members when they need assistance.

The application connects an elderly person with family members using a unique 6-digit family code. When the elderly person requests help, connected family members receive a push notification on their Android devices.

## Features

- Two user roles:
  - Elderly person
  - Family member
- Automatic generation of a unique 6-digit family code
- Family members can connect using the family code
- Separation of data between different families
- "TREBA MI POMOĆ" (I need help) emergency request
- "DOBRO SAM" (I'm OK) status update
- Real-time status synchronization using Cloud Firestore
- Push notifications using Firebase Cloud Messaging
- Push notifications work while the application is in the background or the phone is locked
- User role and family connection are remembered after restarting the application
- Support for multiple family members connected to the same elderly person

## How It Works

### Elderly person

1. Open the application.
2. Select **Starija osoba**.
3. The application generates a unique 6-digit family code.
4. Share the code with family members.
5. Press **TREBA MI POMOĆ** when assistance is needed.
6. Connected family members receive an emergency push notification.
7. Press **DOBRO SAM** to update the current status.

### Family member

1. Open the application.
2. Select **Član obitelji**.
3. Enter the 6-digit code provided by the elderly person.
4. Connect to the family.
5. Monitor the elderly person's current status.
6. Receive push notifications when the elderly person requests help.

## Technologies

- Flutter
- Dart
- Firebase Cloud Firestore
- Firebase Cloud Messaging (FCM)
- Firebase Cloud Functions
- Node.js
- Android

## Firebase Backend

Cloud Firestore is used to store family data, registered family members and help requests.

Firebase Cloud Functions monitor new help requests and use Firebase Cloud Messaging to send push notifications only to devices belonging to the corresponding family.

This allows multiple families to use the application independently.

## Installation

The application can be installed on an Android device using the provided `SeniorSafety.apk`.

1. Transfer `SeniorSafety.apk` to the Android device.
2. Open the APK file.
3. If required, allow installation from unknown sources.
4. Install and open Senior Safety.
5. Choose the appropriate user role.

Android may ask for notification permission. This permission should be enabled so emergency notifications can be received.

## Running the Project

Requirements:

- Flutter SDK
- Android Studio / Android SDK
- Android device or emulator
- Firebase project configuration

Clone the repository:

```bash
git clone https://github.com/lukaMM16/senior-safety.git
cd senior-safety
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

## Building the APK

To create a release APK:

```bash
flutter build apk --release
```

The generated APK can be found at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Project Structure

```text
lib/          Flutter application source code
functions/    Firebase Cloud Functions
android/      Android configuration
test/         Flutter tests
```

## Security Note

Senior Safety is currently a prototype/demo application. Firestore access is restricted to the collections required by the application, but the current version does not implement Firebase Authentication.

For a production deployment, Firebase Authentication and stricter user-based Firestore Security Rules should be implemented.

## Author

**Luka Mikac**

Computer Science student  
Međimursko veleučilište u Čakovcu