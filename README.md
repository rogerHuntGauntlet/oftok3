# OHFtok - Video Project Management App

OHFtok is a Flutter-based video project management application that allows users to create, manage, and collaborate on video projects. Users can upload videos, organize them into projects, and share them with collaborators.

## Features

- 📱 Cross-platform support (Android)
- 🎥 Video upload and playback
- 👥 User authentication and management
- 📁 Project organization
- 🤝 Collaboration features
- 🔒 Public/private project visibility
- 🎯 Drag-and-drop video reordering
- 💾 Cloud storage integration

## Prerequisites

Before you begin, ensure you have the following installed:
- [Flutter](https://flutter.dev/docs/get-started/install) (latest stable version)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/)
- [Git](https://git-scm.com/)
- [Firebase CLI](https://firebase.google.com/docs/cli)

## Getting Started

1. Clone the repository:
```bash
git clone https://github.com/yourusername/ohftok.git
cd ohftok
```

2. Install dependencies:
```bash
flutter pub get
```

3. Set up Firebase:
   - Create a new Firebase project
   - Enable Authentication, Firestore, and Storage
   - Download `google-services.json` and place it in `android/app/`
   - Set up Cloud Functions by following the instructions in the `functions` directory

4. Configure environment variables:
   - Create a `.env` file in the root directory
   - Add necessary environment variables (see `.env.example`)

5. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── models/         # Data models
├── screens/        # UI screens
├── services/       # Business logic and API calls
├── widgets/        # Reusable UI components
└── main.dart       # App entry point

functions/          # Firebase Cloud Functions
android/           # Android-specific code
```

## Development Setup

### Android Studio
1. Open the project in Android Studio
2. Install the Flutter and Dart plugins
3. Configure an Android emulator or connect a physical device
4. Run the app using the play button

### VS Code
1. Install the Flutter and Dart extensions
2. Open the command palette (Ctrl+Shift+P / Cmd+Shift+P)
3. Select "Flutter: Run Flutter Doctor" to verify setup
4. Run the app using F5 or the Run menu

## Building for Release

### Android
1. Generate a keystore:
```bash
cd android/app
./generate_keystore.bat  # Windows
```

2. Set environment variables for signing:
```bash
./set_signing_env.bat  # Windows
```

3. Build the release APK:
```bash
flutter build apk --release
```

The APK will be available at `build/app/outputs/flutter-apk/app-release.apk`

## Contributing

1. Fork the repository
2. Create a new branch for your feature
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please open an issue in the GitHub repository or contact the development team.

## Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- All contributors who have helped with the project
