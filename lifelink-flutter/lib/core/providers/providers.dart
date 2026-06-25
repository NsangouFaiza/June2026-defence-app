import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/providers.dart';
import '../../features/auth/providers/auth_providers.dart';
export '../../features/auth/providers/auth_providers.dart';
import '../../data/repositories/hospital_repository.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../data/repositories/donation_repository.dart';
import '../../data/repositories/eligibility_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/campaign_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/donor_repository.dart';
import '../../core/utils/localization_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// Repository Providers
final hospitalRepositoryProvider = Provider<HospitalRepository>((ref) {
  return HospitalRepository();
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository();
});

final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  return RequestRepository();
});

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return AppointmentRepository();
});

final donationRepositoryProvider = Provider<DonationRepository>((ref) {
  return DonationRepository();
});

final eligibilityRepositoryProvider = Provider<EligibilityRepository>((ref) {
  return EligibilityRepository();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final campaignRepositoryProvider = Provider<CampaignRepository>((ref) {
  return CampaignRepository();
});

final rewardRepositoryProvider = Provider<RewardRepository>((ref) {
  return RewardRepository();
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository();
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository();
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

final donorRepositoryProvider = Provider<DonorRepository>((ref) {
  return DonorRepository();
});

// Localization Provider
final localizationProvider = StateNotifierProvider<LocalizationService, Locale>((ref) {
  return LocalizationService();
});

final localizationServiceProvider = Provider<LocalizationService>((ref) {
  ref.watch(localizationProvider);
  return ref.read(localizationProvider.notifier);
});
