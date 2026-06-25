# LifeLink - Blood Donation and Blood Bank Management Mobile Application

## Overview

LifeLink is a comprehensive blood donation and blood bank management platform that connects donors, patients, hospitals, blood banks, laboratory technicians, and administrators. The application simplifies blood donation, blood inventory management, emergency blood requests, donor communication, appointment scheduling, and hospital geolocation.

## Features

### User Roles
1. **Donor** - Donate blood, check eligibility, book appointments, track donations
2. **Patient** - Search blood, request blood packs, emergency requests, hospital locator
3. **Hospital Staff** - Manage blood inventory, process requests, validate appointments
4. **Laboratory Technician** - Validate donations, record screening results, approve blood units
5. **Blood Bank Administrator** - Manage blood banks, view statistics
6. **System Administrator** - Manage all users, hospitals, system settings

### Core Features
- JWT Authentication with role-based access control
- Blood inventory management with low stock alerts
- Emergency blood request system
- Donation eligibility checking
- Appointment booking and management
- Real-time chat between donors and patients
- Push notifications
- Google Maps integration for hospital location
- Multi-language support (English/French)
- Payment integration (MTN Mobile Money, Orange Money)
- Donor rewards and badges system
- Community leaderboard
- Campaign management
- Reporting and analytics

## Tech Stack

### Frontend
- **Flutter** (latest stable version)
- **Material 3 Design**
- **Riverpod** for state management
- **Dio** for HTTP requests
- **Google Maps Flutter** for maps
- **Firebase Cloud Messaging** for push notifications

### Backend
- **Django REST Framework**
- **JWT Authentication**
- **SQLite** database
- **Django Channels** for WebSocket

## Project Structure

```
lifelink-flutter/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   ├── utils/
│   │   │   └── localization_service.dart
│   │   └── providers/
│   │       └── providers.dart
│   ├── data/
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   ├── hospital_model.dart
│   │   │   ├── blood_inventory_model.dart
│   │   │   ├── blood_request_model.dart
│   │   │   ├── appointment_model.dart
│   │   │   ├── donation_model.dart
│   │   │   ├── eligibility_check_model.dart
│   │   │   ├── campaign_model.dart
│   │   │   ├── notification_model.dart
│   │   │   ├── message_model.dart
│   │   │   ├── conversation_model.dart
│   │   │   ├── payment_model.dart
│   │   │   ├── badge_model.dart
│   │   │   └── donor_reward_model.dart
│   │   ├── repositories/
│   │   │   ├── auth_repository.dart
│   │   │   ├── hospital_repository.dart
│   │   │   ├── inventory_repository.dart
│   │   │   ├── request_repository.dart
│   │   │   ├── appointment_repository.dart
│   │   │   ├── donation_repository.dart
│   │   │   ├── eligibility_repository.dart
│   │   │   ├── notification_repository.dart
│   │   │   ├── campaign_repository.dart
│   │   │   ├── reward_repository.dart
│   │   │   ├── payment_repository.dart
│   │   │   ├── message_repository.dart
│   │   │   ├── admin_repository.dart
│   │   │   ├── community_repository.dart
│   │   │   └── report_repository.dart
│   │   └── services/
│   │       └── api_service.dart
│   └── features/
│       ├── auth/
│       │   ├── screens/
│       │   │   ├── login_screen.dart
│       │   │   ├── register_screen.dart
│       │   │   ├── forgot_password_screen.dart
│       │   │   └── language_selection_screen.dart
│       │   └── providers/
│       │       └── auth_providers.dart
│       ├── onboarding/
│       │   └── screens/
│       │       ├── splash_screen.dart
│       │       └── onboarding_screen.dart
│       ├── home/
│       │   └── screens/
│       │       └── home_dashboard_screen.dart
│       ├── donor/
│       │   └── screens/
│       │       ├── donor_dashboard_screen.dart
│       │       ├── eligibility_check_screen.dart
│       │       ├── donation_history_screen.dart
│       │       └── appointment_booking_screen.dart
│       ├── patient/
│       │   └── screens/
│       │       ├── patient_dashboard_screen.dart
│       │       ├── blood_request_screen.dart
│       │       ├── blood_search_screen.dart
│       │       └── emergency_request_screen.dart
│       ├── hospital/
│       │   └── screens/
│       │       ├── hospital_dashboard_screen.dart
│       │       └── blood_inventory_screen.dart
│       ├── donors/
│       │   └── screens/
│       │       ├── donor_list_screen.dart
│       │       └── donor_details_screen.dart
│       ├── chat/
│       │   └── screens/
│       │       └── chat_screen.dart
│       ├── notifications/
│       │   └── screens/
│       │       └── notifications_screen.dart
│       ├── map/
│       │   └── screens/
│       │       ├── hospital_map_screen.dart
│       │       └── hospital_locator_screen.dart
│       ├── appointments/
│       │   └── screens/
│       │       ├── appointment_booking_screen.dart
│       │       └── appointment_history_screen.dart
│       ├── campaigns/
│       │   └── screens/
│       │       ├── campaigns_screen.dart
│       │       ├── campaign_details_screen.dart
│       │       └── campaign_feed_screen.dart
│       ├── profile/
│       │   └── screens/
│       │       ├── profile_settings_screen.dart
│       │       └── rewards_screen.dart
│       ├── community/
│       │   └── screens/
│       │       ├── leaderboard_screen.dart
│       │       └── impact_statistics_screen.dart
│       ├── reports/
│       │   └── screens/
│       │       └── reports_screen.dart
│       ├── admin/
│       │   └── screens/
│       │       └── admin_panel_screen.dart
│       └── payment/
│           └── screens/
│               └── payment_screen.dart
├── assets/
│   ├── images/
│   ├── icons/
│   └── translations/
│       ├── en.json
│       └── fr.json
└── pubspec.yaml
```

## Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0 <4.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode
- Google Maps API Key

### Installation

1. Clone the repository
2. Navigate to the Flutter project directory
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Configure Google Maps API key in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/AppDelegate.swift`
5. Run the app:
   ```bash
   flutter run
   ```

## Backend Setup

See the `lifelink-backend/README.md` for backend setup instructions.

## API Documentation

See the `lifelink-backend/API_DOCUMENTATION.md` for API documentation.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License.

## Support

For support, email support@lifelink.com or create an issue in the repository.
