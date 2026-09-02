import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/providers.dart';
import 'core/utils/localization_service.dart';
import 'features/onboarding/screens/splash_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/auth/screens/language_selection_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/home/screens/home_dashboard_screen.dart';
import 'features/donor/screens/donor_dashboard_screen.dart';
import 'features/patient/screens/patient_dashboard_screen.dart';
import 'features/hospital/screens/hospital_dashboard_screen.dart';
import 'features/hospital/screens/blood_inventory_screen.dart';
import 'features/hospital/screens/manage_appointments_screen.dart';
import 'features/patient/screens/blood_request_screen.dart';
import 'features/patient/screens/blood_search_screen.dart';
import 'features/patient/screens/emergency_request_screen.dart';
import 'features/patient/screens/available_blood_packs_screen.dart';
import 'features/donors/screens/donor_list_screen.dart';
import 'features/donors/screens/donor_details_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/map/screens/hospital_locator_screen.dart';
import 'features/appointments/screens/appointment_booking_screen.dart';
import 'features/appointments/screens/appointment_history_screen.dart';
import 'features/campaigns/screens/campaigns_screen.dart';
import 'features/campaigns/screens/campaign_details_screen.dart';
import 'features/campaigns/screens/campaign_feed_screen.dart';
import 'features/profile/screens/profile_settings_screen.dart';
import 'features/profile/screens/rewards_screen.dart';
import 'features/community/screens/leaderboard_screen.dart';
import 'features/community/screens/impact_statistics_screen.dart';
import 'features/reports/screens/reports_screen.dart';
import 'features/admin/screens/admin_panel_screen.dart';
import 'features/donor/screens/eligibility_check_screen.dart';
import 'features/donor/screens/donation_history_screen.dart';
import 'features/lab/screens/lab_dashboard_screen.dart';
import 'features/payment/screens/payment_screen.dart';
import 'core/providers/theme_provider.dart';
import 'features/patient/screens/blood_requests_list_screen.dart';
import 'features/donor/screens/digital_donor_badge_screen.dart';
import 'features/donor/screens/health_records_screen.dart';
import 'features/payment/screens/hospital_subscription_payment_screen.dart';
import 'features/hospital/screens/hospital_subscription_history_screen.dart';
import 'features/payment/screens/receipt_history_screen.dart';
import 'features/auth/screens/change_password_screen.dart';
import 'features/profile/screens/security_settings_screen.dart';
import 'core/widgets/role_guard.dart';

void main() {
  runApp(
    const ProviderScope(
      child: LifeLinkApp(),
    ),
  );
}

class LifeLinkApp extends ConsumerWidget {
  const LifeLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localizationProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'LifeLink',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          locale: locale,
          supportedLocales: const [
            Locale('en', ''),
            Locale('fr', ''),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/language': (context) => const LanguageSelectionScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/home': (context) => const RoleGuard(allowedRoles: [], child: HomeDashboardScreen()),
            '/donor-dashboard': (context) => const RoleGuard(allowedRoles: ['donor'], child: DonorDashboardScreen()),
            '/patient-dashboard': (context) => const RoleGuard(allowedRoles: ['patient'], child: PatientDashboardScreen()),
            '/hospital-dashboard': (context) => const RoleGuard(allowedRoles: ['hospital_staff', 'blood_bank_staff'], child: HospitalDashboardScreen()),
            '/lab-dashboard': (context) => const RoleGuard(allowedRoles: ['hospital_staff', 'blood_bank_staff', 'system_admin', 'blood_bank_admin'], child: LabDashboardScreen()),
            '/blood-inventory': (context) => const BloodInventoryScreen(),
            '/blood-request': (context) => const BloodRequestScreen(),
            '/blood-requests': (context) => const BloodRequestsListScreen(),
            '/blood-search': (context) => const BloodSearchScreen(),
            '/emergency-request': (context) => const EmergencyRequestScreen(),
            '/donor-list': (context) => const DonorListScreen(),
            '/donor-details': (context) {
              final donorId = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
              return DonorDetailsScreen(donorId: donorId);
            },
            '/chat': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return ChatScreen(
                conversationId: args?['conversationId'] as int?,
                otherUserId: args?['otherUserId'] as int?,
              );
            },
            '/notifications': (context) => const NotificationsScreen(),
            '/hospital-locator': (context) => const HospitalLocatorScreen(),
            '/available-blood-packs': (context) => const AvailableBloodPacksScreen(),
            '/chat-list': (context) => const ChatListScreen(),
            '/book-appointment': (context) => const AppointmentBookingScreen(),
            '/appointment-history': (context) => const AppointmentHistoryScreen(),
            '/campaigns': (context) => const CampaignsScreen(),
            '/campaign-details': (context) {
              final campaignId = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
              return CampaignDetailsScreen(campaignId: campaignId);
            },
            '/campaign-feed': (context) => const CampaignFeedScreen(),
            '/profile': (context) => const ProfileSettingsScreen(),
            '/rewards': (context) => const RewardsScreen(),
            '/leaderboard': (context) => const LeaderboardScreen(),
            '/impact-statistics': (context) => const ImpactStatisticsScreen(),
            '/reports': (context) => const ReportsScreen(),
            '/manage-appointments': (context) => const ManageAppointmentsScreen(),
            '/admin-panel': (context) => const RoleGuard(allowedRoles: ['system_admin', 'blood_bank_admin'], child: AdminPanelScreen()),
            '/eligibility-check': (context) => const EligibilityCheckScreen(),
            '/donation-history': (context) => const DonationHistoryScreen(),
            '/digital-donor-badge': (context) => const DigitalDonorBadgeScreen(),
            '/health-records': (context) => const HealthRecordsScreen(),
            '/payment': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return PaymentScreen(
                requestId: args?['requestId'] as int? ?? 0,
                amount: args?['amount'] as double? ?? 0.0,
              );
            },
            '/hospital-subscription-payment': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return HospitalSubscriptionPaymentScreen(
                hospitalId: args?['hospitalId'] as int?,
                hospitalName: args?['hospitalName'] as String?,
                currentExpiryDate: args?['currentExpiryDate'] as String?,
              );
            },
            '/hospital-subscription-history': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return HospitalSubscriptionHistoryScreen(
                hospitalId: args?['hospitalId'] as int?,
              );
            },
            '/payment-history': (context) => const ReceiptHistoryScreen(),
            '/change-password': (context) => const ChangePasswordScreen(),
            '/security-settings': (context) => const SecuritySettingsScreen(),
          },
        );
      },
    );
  }
}

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = AppLocalizationsDelegate();

  String translate(String key) {
    final Map<String, Map<String, String>> translations = {
      'en': LocalizationService.englishTranslations,
      'fr': LocalizationService.frenchTranslations,
    };
    return translations[locale.languageCode]?[key] ??
           translations['en']?[key] ??
           key;
  }

  String get currentLanguage => locale.languageCode;
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'fr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
