import 'dart:io';

class AppConstants {
  // API Configuration
  static String get apiBaseUrl {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000/api';
  }
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Blood Groups
  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  // Payment Methods
  static const List<Map<String, String>> paymentMethods = [
    {
      'name': 'MTN Mobile Money',
      'description': 'Pay with MTN Mobile Money',
      'code': 'MTN',
    },
    {
      'name': 'Orange Money',
      'description': 'Pay with Orange Money',
      'code': 'ORANGE',
    },
  ];

  // Urgency Levels
  static const List<String> urgencyLevels = [
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL',
  ];

  // Appointment Status
  static const List<String> appointmentStatuses = [
    'PENDING',
    'CONFIRMED',
    'COMPLETED',
    'CANCELLED',
  ];

  // Donation Status
  static const List<String> donationStatuses = [
    'PENDING',
    'COMPLETED',
    'CANCELLED',
  ];

  // Request Status
  static const List<String> requestStatuses = [
    'PENDING',
    'APPROVED',
    'REJECTED',
    'FULFILLED',
  ];

  // Eligibility Status
  static const List<String> eligibilityStatuses = [
    'ELIGIBLE',
    'TEMPORARY_INELIGIBLE',
    'PERMANENT_INELIGIBLE',
  ];

  // Badge Types
  static const List<String> badgeTypes = [
    'bronze',
    'silver',
    'gold',
    'platinum',
    'life_saver',
    'emergency_hero',
    'top_community',
  ];

  // Campaign Types
  static const List<String> campaignTypes = [
    'donation',
    'emergency',
    'education',
    'event',
  ];

  // User Roles
  static const List<String> userRoles = [
    'donor',
    'patient',
    'hospital_staff',
    'lab_technician',
    'blood_bank_admin',
    'system_admin',
  ];

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String isLoggedInKey = 'is_logged_in';
  static const String hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String languageKey = 'language';
  static const String themeKey = 'theme';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Validation
  static const int minPasswordLength = 8;
  static const int minDonorAge = 18;
  static const int maxDonorAge = 65;
  static const double minDonorWeight = 50.0;
}
