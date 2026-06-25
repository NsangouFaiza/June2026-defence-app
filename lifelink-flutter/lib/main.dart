import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/localization_service.dart';
import 'core/providers/providers.dart';
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
import 'features/patient/screens/blood_request_screen.dart';
import 'features/patient/screens/blood_search_screen.dart';
import 'features/patient/screens/emergency_request_screen.dart';
import 'features/donors/screens/donor_list_screen.dart';
import 'features/donors/screens/donor_details_screen.dart';
import 'features/chat/screens/chat_screen.dart';
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
          themeMode: ThemeMode.system,
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
            '/home': (context) => const HomeDashboardScreen(),
            '/donor-dashboard': (context) => const DonorDashboardScreen(),
            '/patient-dashboard': (context) => const PatientDashboardScreen(),
            '/hospital-dashboard': (context) => const HospitalDashboardScreen(),
            '/lab-dashboard': (context) => const LabDashboardScreen(),
            '/blood-inventory': (context) => const BloodInventoryScreen(),
            '/blood-request': (context) => const BloodRequestScreen(),
            '/blood-search': (context) => const BloodSearchScreen(),
            '/emergency-request': (context) => const EmergencyRequestScreen(),
            '/donor-list': (context) => const DonorListScreen(),
            '/donor-details': (context) => const DonorDetailsScreen(donorId: 0),
            '/chat': (context) => const ChatScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            '/hospital-locator': (context) => const HospitalLocatorScreen(),
            '/book-appointment': (context) => const AppointmentBookingScreen(),
            '/appointment-history': (context) => const AppointmentHistoryScreen(),
            '/campaigns': (context) => const CampaignsScreen(),
            '/campaign-details': (context) => const CampaignDetailsScreen(campaignId: 0),
            '/campaign-feed': (context) => const CampaignFeedScreen(),
            '/profile': (context) => const ProfileSettingsScreen(),
            '/rewards': (context) => const RewardsScreen(),
            '/leaderboard': (context) => const LeaderboardScreen(),
            '/impact-statistics': (context) => const ImpactStatisticsScreen(),
            '/reports': (context) => const ReportsScreen(),
            '/admin-panel': (context) => const AdminPanelScreen(),
            '/eligibility-check': (context) => const EligibilityCheckScreen(),
            '/donation-history': (context) => const DonationHistoryScreen(),
            '/payment': (context) => const PaymentScreen(requestId: 0, amount: 0),
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

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'welcome': 'Welcome',
      'welcome_back': 'Welcome back',
      'login': 'Login',
      'register': 'Register',
      'forgot_password': 'Forgot Password?',
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'full_name': 'Full Name',
      'phone': 'Phone',
      'home': 'Home',
      'donor_dashboard': 'Donor Dashboard',
      'patient_dashboard': 'Patient Dashboard',
      'hospital_dashboard': 'Hospital Dashboard',
      'blood_inventory': 'Blood Inventory',
      'blood_request': 'Request Blood',
      'search_blood': 'Search Blood',
      'emergency_request': 'Emergency Request',
      'donor_list': 'Donor List',
      'chat': 'Chat',
      'notifications': 'Notifications',
      'hospital_locator': 'Hospital Locator',
      'book_appointment': 'Book Appointment',
      'campaigns': 'Campaigns',
      'profile_settings': 'Profile Settings',
      'rewards': 'Rewards',
      'leaderboard': 'Leaderboard',
      'reports': 'Reports',
      'admin_panel': 'Admin Panel',
      'logout': 'Logout',
      'total_donations': 'Total Donations',
      'total_units': 'Total Units',
      'lives_saved': 'Lives Saved',
      'eligibility_status': 'Eligibility',
      'eligible': 'Eligible',
      'ineligible': 'Ineligible',
      'quick_actions': 'Quick Actions',
      'recent_activity': 'Recent Activity',
      'no_donations_yet': 'No donations yet',
      'no_appointments': 'No appointments',
      'no_notifications': 'No notifications',
      'no_requests': 'No requests',
      'no_data_available': 'No data available',
      'submit': 'Submit',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'view': 'View',
      'search': 'Search',
      'filter': 'Filter',
      'sort': 'Sort',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'warning': 'Warning',
      'active': 'Active',
      'inactive': 'Inactive',
      'pending': 'Pending',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'blood_group': 'Blood Group',
      'quantity': 'Quantity',
      'urgency': 'Urgency',
      'hospital': 'Hospital',
      'date': 'Date',
      'time': 'Time',
      'location': 'Location',
      'description': 'Description',
      'notes': 'Notes',
      'reason': 'Reason',
      'status': 'Status',
      'amount': 'Amount',
      'payment': 'Payment',
      'pay_now': 'Pay Now',
      'select_payment_method': 'Select Payment Method',
      'amount_to_pay': 'Amount to Pay',
      'emergency': 'Emergency',
      'send_emergency_request': 'Send Emergency Request',
      'emergency_warning': 'This is an emergency request. All nearby hospitals and donors will be notified immediately.',
      'check_eligibility': 'Check Eligibility',
      'health_questionnaire': 'Health Questionnaire',
      'age': 'Age',
      'weight_kg': 'Weight (kg)',
      'recent_surgeries': 'Recent Surgeries',
      'pregnancy_status': 'Pregnancy Status',
      'infectious_diseases': 'Infectious Diseases',
      'medication_use': 'Medication Use',
      'medical_condition': 'Medical Condition',
      'temporary_ineligible': 'Temporarily Ineligible',
      'permanent_ineligible': 'Permanently Ineligible',
      'donation_history': 'Donation History',
      'appointment_history': 'Appointment History',
      'impact_statistics': 'Impact Statistics',
      'total_points': 'Total Points',
      'current_level': 'Current Level',
      'my_badges': 'My Badges',
      'earned_badges': 'Earned Badges',
      'no_rewards_yet': 'No rewards yet',
      'no_leaderboard_data': 'No leaderboard data',
      'top_donors': 'Top Donors',
      'top_regions': 'Top Regions',
      'community_rank': 'Community Rank',
      'donation_streak': 'Donation Streak',
      'hospital_contributions': 'Hospital Contributions',
      'monthly_impact': 'Monthly Impact',
      'monthly_donations': 'Monthly Donations',
      'blood_stock_by_group': 'Blood Stock by Group',
      'personal_information': 'Personal Information',
      'preferences': 'Preferences',
      'push_notifications': 'Push Notifications',
      'email_notifications': 'Email Notifications',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'change_password': 'Change Password',
      'security_settings': 'Security Settings',
      'users': 'Users',
      'hospitals': 'Hospitals',
      'statistics': 'Statistics',
      'total_users': 'Total Users',
      'total_donors': 'Total Donors',
      'total_patients': 'Total Patients',
      'total_hospitals': 'Total Hospitals',
      'active_requests': 'Active Requests',
      'low_stock': 'Low Stock',
      'available': 'Available',
      'hospitals_nearby': 'Hospitals Nearby',
      'no_donors_found': 'No donors found',
      'no_campaigns': 'No campaigns',
      'no_results': 'No results found',
      'book': 'Book',
      'register_now': 'Register Now',
      'back_to_login': 'Back to Login',
      'check_email': 'Check Your Email',
      'reset_email_sent': 'We have sent you a password reset link. Please check your email.',
      'forgot_password_title': 'Forgot Password?',
      'forgot_password_subtitle': 'Enter your email address and we will send you a link to reset your password.',
      'reset_password': 'Reset Password',
      'already_have_account': 'Already have an account?',
      'dont_have_account': "Don't have an account?",
      'create_profile': 'Create Profile',
      'no_donor_profile': 'No donor profile',
      'no_hospital_assigned': 'No hospital assigned',
      'total_blood_units': 'Total Blood Units',
      'low_stock_alerts': 'Low Stock Alerts',
      'pending_appointments': 'Pending Appointments',
      'donor_details': 'Donor Details',
      'contact_information': 'Contact Information',
      'donation_statistics': 'Donation Statistics',
      'call': 'Call',
      'campaign_details': 'Campaign Details',
      'details': 'Details',
      'start_date': 'Start Date',
      'end_date': 'End Date',
      'participants': 'Participants',
    },
    'fr': {
      'welcome': 'Bienvenue',
      'welcome_back': 'Bon retour',
      'login': 'Connexion',
      'register': 'Inscription',
      'forgot_password': 'Mot de passe oublié?',
      'email': 'Email',
      'password': 'Mot de passe',
      'confirm_password': 'Confirmer le mot de passe',
      'full_name': 'Nom complet',
      'phone': 'Téléphone',
      'home': 'Accueil',
      'donor_dashboard': 'Tableau de bord des donneurs',
      'patient_dashboard': 'Tableau de bord des patients',
      'hospital_dashboard': 'Tableau de bord des hôpitaux',
      'blood_inventory': 'Inventaire sanguin',
      'blood_request': 'Demande de sang',
      'search_blood': 'Rechercher du sang',
      'emergency_request': 'Demande d\'urgence',
      'donor_list': 'Liste des donneurs',
      'chat': 'Chat',
      'notifications': 'Notifications',
      'hospital_locator': 'Localisateur d\'hôpitaux',
      'book_appointment': 'Prendre rendez-vous',
      'campaigns': 'Campagnes',
      'profile_settings': 'Paramètres du profil',
      'rewards': 'Récompenses',
      'leaderboard': 'Classement',
      'reports': 'Rapports',
      'admin_panel': 'Panneau d\'administration',
      'logout': 'Déconnexion',
      'total_donations': 'Total des dons',
      'total_units': 'Unités totales',
      'lives_saved': 'Vies sauvées',
      'eligibility_status': 'Éligibilité',
      'eligible': 'Éligible',
      'ineligible': 'Non éligible',
      'quick_actions': 'Actions rapides',
      'recent_activity': 'Activité récente',
      'no_donations_yet': 'Pas encore de dons',
      'no_appointments': 'Pas de rendez-vous',
      'no_notifications': 'Pas de notifications',
      'no_requests': 'Pas de demandes',
      'no_data_available': 'Aucune donnée disponible',
      'submit': 'Soumettre',
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'view': 'Voir',
      'search': 'Rechercher',
      'filter': 'Filtrer',
      'sort': 'Trier',
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',
      'warning': 'Avertissement',
      'active': 'Actif',
      'inactive': 'Inactif',
      'pending': 'En attente',
      'approved': 'Approuvé',
      'rejected': 'Rejeté',
      'completed': 'Terminé',
      'cancelled': 'Annulé',
      'blood_group': 'Groupe sanguin',
      'quantity': 'Quantité',
      'urgency': 'Urgence',
      'hospital': 'Hôpital',
      'date': 'Date',
      'time': 'Heure',
      'location': 'Emplacement',
      'description': 'Description',
      'notes': 'Notes',
      'reason': 'Raison',
      'status': 'Statut',
      'amount': 'Montant',
      'payment': 'Paiement',
      'pay_now': 'Payer maintenant',
      'select_payment_method': 'Sélectionner le mode de paiement',
      'amount_to_pay': 'Montant à payer',
      'emergency': 'Urgence',
      'send_emergency_request': 'Envoyer la demande d\'urgence',
      'emergency_warning': 'Ceci est une demande d\'urgence. Tous les hôpitaux et donneurs à proximité seront notifiés immédiatement.',
      'check_eligibility': 'Vérifier l\'éligibilité',
      'health_questionnaire': 'Questionnaire de santé',
      'age': 'Âge',
      'weight_kg': 'Poids (kg)',
      'recent_surgeries': 'Chirurgies récentes',
      'pregnancy_status': 'État de grossesse',
      'infectious_diseases': 'Maladies infectieuses',
      'medication_use': 'Utilisation de médicaments',
      'medical_condition': 'Condition médicale',
      'temporary_ineligible': 'Temporairement non éligible',
      'permanent_ineligible': 'Définitivement non éligible',
      'donation_history': 'Historique des dons',
      'appointment_history': 'Historique des rendez-vous',
      'impact_statistics': 'Statistiques d\'impact',
      'total_points': 'Points totaux',
      'current_level': 'Niveau actuel',
      'my_badges': 'Mes badges',
      'earned_badges': 'Badges gagnés',
      'no_rewards_yet': 'Pas encore de récompenses',
      'no_leaderboard_data': 'Aucune donnée de classement',
      'top_donors': 'Meilleurs donneurs',
      'top_regions': 'Meilleures régions',
      'community_rank': 'Rang communautaire',
      'donation_streak': 'Série de dons',
      'hospital_contributions': 'Contributions des hôpitaux',
      'monthly_impact': 'Impact mensuel',
      'monthly_donations': 'Dons mensuels',
      'blood_stock_by_group': 'Stock sanguin par groupe',
      'personal_information': 'Informations personnelles',
      'preferences': 'Préférences',
      'push_notifications': 'Notifications push',
      'email_notifications': 'Notifications par email',
      'dark_mode': 'Mode sombre',
      'language': 'Langue',
      'change_password': 'Changer le mot de passe',
      'security_settings': 'Paramètres de sécurité',
      'users': 'Utilisateurs',
      'hospitals': 'Hôpitaux',
      'statistics': 'Statistiques',
      'total_users': 'Total des utilisateurs',
      'total_donors': 'Total des donneurs',
      'total_patients': 'Total des patients',
      'total_hospitals': 'Total des hôpitaux',
      'active_requests': 'Demandes actives',
      'low_stock': 'Stock faible',
      'available': 'Disponible',
      'hospitals_nearby': 'Hôpitaux à proximité',
      'no_donors_found': 'Aucun donneur trouvé',
      'no_campaigns': 'Aucune campagne',
      'no_results': 'Aucun résultat',
      'book': 'Réserver',
      'register_now': 'S\'inscrire maintenant',
      'back_to_login': 'Retour à la connexion',
      'check_email': 'Vérifiez votre email',
      'reset_email_sent': 'Nous vous avons envoyé un lien de réinitialisation du mot de passe. Veuillez vérifier votre email.',
      'forgot_password_title': 'Mot de passe oublié?',
      'forgot_password_subtitle': 'Entrez votre adresse email et nous vous enverrons un lien pour réinitialiser votre mot de passe.',
      'reset_password': 'Réinitialiser le mot de passe',
      'already_have_account': 'Vous avez déjà un compte?',
      'dont_have_account': 'Vous n\'avez pas de compte?',
      'create_profile': 'Créer un profil',
      'no_donor_profile': 'Aucun profil de donneur',
      'no_hospital_assigned': 'Aucun hôpital assigné',
      'total_blood_units': 'Unités de sang totales',
      'low_stock_alerts': 'Alertes de stock faible',
      'pending_appointments': 'Rendez-vous en attente',
      'donor_details': 'Détails du donneur',
      'contact_information': 'Informations de contact',
      'donation_statistics': 'Statistiques de dons',
      'call': 'Appeler',
      'campaign_details': 'Détails de la campagne',
      'details': 'Détails',
      'start_date': 'Date de début',
      'end_date': 'Date de fin',
      'participants': 'Participants',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']?[key] ?? key;
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
