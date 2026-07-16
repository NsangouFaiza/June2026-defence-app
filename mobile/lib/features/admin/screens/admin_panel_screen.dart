import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/models/user_model.dart';
import '../../../../features/auth/providers/auth_providers.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final adminRepo = ref.watch(adminRepositoryProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user != null ? 'Welcome Back, ${user.fullName}' : 'Welcome Back',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 20.h,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      localization.translate('admin_panel'),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outlined),
              onPressed: () {
                Navigator.of(context).pushNamed('/profile');
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: localization.translate('users')),
              Tab(text: localization.translate('hospitals')),
              Tab(text: localization.translate('statistics')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsersTab(context, ref, adminRepo, localization),
            _buildHospitalsTab(context, ref, adminRepo, localization),
            _buildStatisticsTab(context, ref, adminRepo, localization),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(
    BuildContext context,
    WidgetRef ref,
    AdminRepository adminRepo,
    LocalizationService localization,
  ) {
    return FutureBuilder<List<UserModel>>(
      future: adminRepo.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data ?? [];

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: EdgeInsets.only(bottom: 12.h),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(user.role),
                  child: Text(
                    user.fullName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user.fullName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email),
                    Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        color: _getRoleColor(user.role),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.isActive)
                      IconButton(
                        icon: const Icon(Icons.block, color: AppTheme.warning),
                        onPressed: () => _suspendUser(context, adminRepo, user.id),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: AppTheme.success),
                        onPressed: () => _activateUser(context, adminRepo, user.id),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppTheme.error),
                      onPressed: () => _deleteUser(context, adminRepo, user.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHospitalsTab(
    BuildContext context,
    WidgetRef ref,
    AdminRepository adminRepo,
    LocalizationService localization,
  ) {
    return FutureBuilder<List<dynamic>>(
      future: adminRepo.getAllHospitals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final hospitals = snapshot.data ?? [];

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: hospitals.length,
          itemBuilder: (context, index) {
            final hospital = hospitals[index];
            return Card(
              margin: EdgeInsets.only(bottom: 12.h),
              child: ListTile(
                leading: const Icon(Icons.local_hospital, color: AppTheme.primaryColor),
                title: Text(hospital['name'] ?? 'Unknown'),
                subtitle: Text(hospital['address'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                      onPressed: () {
                        // Edit hospital
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppTheme.error),
                      onPressed: () {
                        // Delete hospital
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatisticsTab(
    BuildContext context,
    WidgetRef ref,
    AdminRepository adminRepo,
    LocalizationService localization,
  ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: adminRepo.getSystemStatistics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('No data available'));
        }

        final stats = snapshot.data!;
        return GridView.count(
          padding: EdgeInsets.all(16.w),
          crossAxisCount: 2,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 16.w,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(context, 'Total Users', stats['total_users']?.toString() ?? '0', Icons.people, AppTheme.primaryColor),
            _buildStatCard(context, 'Total Donors', stats['total_donors']?.toString() ?? '0', Icons.volunteer_activism, AppTheme.success),
            _buildStatCard(context, 'Total Patients', stats['total_patients']?.toString() ?? '0', Icons.person, AppTheme.warning),
            _buildStatCard(context, 'Total Hospitals', stats['total_hospitals']?.toString() ?? '0', Icons.local_hospital, AppTheme.error),
            _buildStatCard(context, 'Total Donations', stats['total_donations']?.toString() ?? '0', Icons.favorite, Colors.purple),
            _buildStatCard(context, 'Active Requests', stats['active_requests']?.toString() ?? '0', Icons.assignment, Colors.orange),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32.w, color: color),
            SizedBox(height: 8.h),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'donor':
        return AppTheme.success;
      case 'patient':
        return AppTheme.warning;
      case 'hospital_staff':
        return AppTheme.primaryColor;
      case 'lab_technician':
        return Colors.purple;
      case 'blood_bank_admin':
        return Colors.orange;
      case 'system_admin':
        return AppTheme.error;
      default:
        return Colors.grey;
    }
  }

  void _suspendUser(BuildContext context, AdminRepository adminRepo, int userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend User'),
        content: const Text('Are you sure you want to suspend this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await adminRepo.suspendUser(userId);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User suspended')),
                );
              }
            },
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  void _activateUser(BuildContext context, AdminRepository adminRepo, int userId) async {
    await adminRepo.activateUser(userId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User activated')),
      );
    }
  }

  void _deleteUser(BuildContext context, AdminRepository adminRepo, int userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await adminRepo.deleteUser(userId);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
