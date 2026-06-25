# LifeLink - Installation Guide

## Prerequisites

Before installing LifeLink, ensure you have the following installed:

- **Flutter SDK** (>=3.0.0 <4.0.0) - [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Dart SDK** (>=3.0.0) - Comes with Flutter
- **Android Studio** or **Xcode** for mobile development
- **Google Maps API Key** - [Get API Key](https://developers.google.com/maps/documentation/android-sdk/get-api-key)
- **Firebase Project** (optional) - For push notifications

## Installation Steps

### 1. Clone the Repository

```bash
git clone <repository-url>
cd lifelink-flutter
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Google Maps

#### Android

1. Open `android/app/src/main/AndroidManifest.xml`
2. Add your Google Maps API key inside the `<application>` tag:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

3. Also add the required permissions in the same file:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

#### iOS

1. Open `ios/Runner/AppDelegate.swift`
2. Add your Google Maps API key:

```swift
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

3. Open `ios/Runner/Info.plist` and add:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location to show nearby hospitals.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to location to show nearby hospitals.</string>
```

### 4. Configure Firebase (Optional)

For push notifications, follow these steps:

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add Android and iOS apps to your Firebase project
3. Download `google-services.json` for Android and place it in `android/app/`
4. Download `GoogleService-Info.plist` for iOS and place it in `ios/Runner/`
5. Follow the [Firebase setup guide](https://firebase.google.com/docs/flutter/setup) for additional configuration

### 5. Configure API Endpoint

Open `lib/data/services/api_service.dart` and update the `baseUrl`:

```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:8000/api';
```

### 6. Run the App

```bash
# Check connected devices
flutter devices

# Run on connected device
flutter run

# Or run on specific device
flutter run -d <device-id>
```

## Troubleshooting

### Common Issues

1. **Gradle Build Failed (Android)**
   - Ensure you have the correct Android SDK version
   - Run `flutter clean` and try again

2. **CocoaPods Error (iOS)**
   - Run `cd ios && pod install && cd ..`
   - Ensure you have CocoaPods installed: `sudo gem install cocoapods`

3. **Google Maps Not Loading**
   - Verify your API key is correct
   - Ensure the API key has Maps SDK for Android/iOS enabled
   - Check that billing is enabled on your Google Cloud project

4. **Permission Denied**
   - Check that location permissions are properly configured in AndroidManifest.xml and Info.plist

## Building for Production

### Android

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Next Steps

1. Set up the backend server (see `lifelink-backend/README.md`)
2. Configure environment variables
3. Test all features
4. Deploy to app stores
