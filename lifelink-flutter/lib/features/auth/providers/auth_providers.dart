import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/models/user_model.dart';
import '../../../core/providers/providers.dart';

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Current User Provider
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final user = await authRepo.getCurrentUser();
  if (user != null) {
    final localLanguage = ref.read(localizationProvider).languageCode;
    if (user.language != localLanguage) {
      Future.microtask(() {
        ref.read(localizationProvider.notifier).changeLanguage(user.language);
      });
    }
  }
  return user;
});

// Is Authenticated Provider
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  return await authRepo.isLoggedIn();
});

// User Role Provider
final userRoleProvider = FutureProvider<String?>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.value?.role;
});

// Is Donor Provider
final isDonorProvider = FutureProvider<bool>((ref) async {
  final roleAsync = ref.watch(userRoleProvider);
  return roleAsync.value == 'donor';
});

// Is Patient Provider
final isPatientProvider = FutureProvider<bool>((ref) async {
  final roleAsync = ref.watch(userRoleProvider);
  return roleAsync.value == 'patient';
});

// Is Hospital Staff Provider
final isHospitalStaffProvider = FutureProvider<bool>((ref) async {
  final roleAsync = ref.watch(userRoleProvider);
  return roleAsync.value == 'hospital_staff' || roleAsync.value == 'lab_technician';
});

// Is Admin Provider
final isAdminProvider = FutureProvider<bool>((ref) async {
  final roleAsync = ref.watch(userRoleProvider);
  return roleAsync.value == 'system_admin' || roleAsync.value == 'blood_bank_admin';
});
