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

## iOS Physical Device Deployment (Running on iPhone)

Since building iOS apps requires Xcode and Apple SDKs, compilation must be completed on a macOS environment. Follow these steps to build and run the application on your physical iPhone.

### Prerequisites
1. A Mac computer with **macOS** and the latest version of **Xcode** installed.
2. An **Apple ID** (free or paid Apple Developer account).
3. A physical **iPhone** and a USB connection cable.
4. **CocoaPods** installed on the Mac (`sudo gem install cocoapods` or via Homebrew).

### Steps to Run on a Physical iPhone

1. **Clone and Open the Project on Mac**
   Clone the repository to your Mac and navigate into the `lifelink-flutter` folder.
   ```bash
   flutter pub get
   ```

2. **Install Native Dependencies**
   Navigate to the `ios` directory and run `pod install` to download CocoaPods dependencies:
   ```bash
   cd ios
   pod install --repo-update
   cd ..
   ```

3. **Open Xcode Workspace**
   Open the iOS project in Xcode. Always open the `.xcworkspace` file (not the `.xcodeproj` file):
   ```bash
   open ios/Runner.xcworkspace
   ```

4. **Configure Apple Signing**
   - In the left sidebar of Xcode, select the root **Runner** project.
   - Select the **Runner** target in the targets list.
   - Go to the **Signing & Capabilities** tab.
   - Check **Automatically manage signing**.
   - Under **Team**, select your Apple account (if not listed, add your Apple ID in *Xcode > Settings > Accounts*).
   - Update the **Bundle Identifier** to a unique value if you get a wildcard error (e.g., `com.yourname.lifelink`).

5. **Trust Developer Certificate on iPhone**
   - Connect your iPhone to your Mac via USB. Select **Trust This Computer** on your iPhone screen.
   - In Xcode's target device menu (top bar), select your physical **iPhone**.
   - Click the **Run** button (Play icon) or run `flutter run` in your terminal.
   - *Note*: If this is your first time deploying, it will fail and prompt you to trust the profile. On your iPhone, go to **Settings > General > VPN & Device Management**, tap your developer certificate (your Apple ID email), and tap **Trust**.
   - Press the Run button in Xcode again, and the app will open on your iPhone.

---

## Troubleshooting: Why the iOS Build Takes Too Long

If the iOS build seems stuck or takes an unusually long time, it is typically due to one of the following reasons:

### 1. Large Native SDK Downloads (Google Maps & Firebase)
LifeLink includes native libraries for Google Maps and Firebase. 
- The iOS Google Maps SDK framework is **150MB+** in size.
- During the first execution of `pod install` or `flutter run`, CocoaPods must download these large binary dependencies from Google's servers.
- **Fix**: Wait for the download to finish. It will only take long on the first build, as subsequent builds will use the cached framework files.

### 2. Slow CocoaPods Repo Updates
By default, CocoaPods updates its entire local spec repository on builds. This cloning process can take 10-20 minutes depending on connection speeds.
- **Fix**: Skip repository updates on daily builds by appending the `--no-repo-update` flag:
  ```bash
  cd ios
  pod install --no-repo-update
  ```

### 3. Apple Silicon (M1/M2/M3) Translation Overhead
If building on an Apple Silicon Mac without native CocoaPods setup, translations can slow compile times.
- **Fix**: Run `pod install` using the native x86_64 arch wrapper:
  ```bash
  arch -x86_64 pod install
  ```

