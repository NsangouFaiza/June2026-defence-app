import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/models/user_model.dart';
import '../../../../features/auth/providers/auth_providers.dart';
import '../../payment/screens/receipt_history_screen.dart';
import '../../../../widgets/lifelink_app_bar.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final adminRepo = ref.watch(adminRepositoryProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: LifeLinkAppBar(
          title: localization.translate('admin_panel'),
          subtitle: user != null ? 'Welcome Back, ${user.fullName}' : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outlined, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pushNamed('/profile');
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: localization.translate('users')),
              Tab(text: localization.translate('hospitals')),
              Tab(text: localization.translate('subscriptions')),
              const Tab(text: 'Analytics'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsersTab(context, ref, adminRepo, localization),
            _buildHospitalsTab(context, ref, adminRepo, localization),
            _buildFinanceTab(context, ref, adminRepo, localization),
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
            final bool isSubActive = hospital['is_subscription_active'] as bool? ?? (hospital['is_active'] ?? true);
            final String? subEndDate = hospital['subscription_end_date'] != null ? hospital['subscription_end_date'].toString().substring(0, 10) : null;
            final bool isActive = hospital['is_active'] ?? true;

            return Card(
              margin: EdgeInsets.only(bottom: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isSubActive ? AppTheme.success.withOpacity(0.15) : AppTheme.error.withOpacity(0.15),
                          child: Icon(
                            Icons.local_hospital,
                            color: isSubActive ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hospital['name'] ?? 'Unknown Hospital',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                '${hospital['city'] ?? ''}, ${hospital['region'] ?? ''}',
                                style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: isSubActive ? AppTheme.success.withOpacity(0.15) : AppTheme.error.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            isSubActive ? 'Active' : 'Expired',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: isSubActive ? AppTheme.success : AppTheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    const Divider(),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          subEndDate != null ? 'Valid until: $subEndDate' : 'No active subscription',
                          style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                        ),
                        Text(
                          'Rate: 25 FCFA/mo',
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                '/hospital-subscription-history',
                                arguments: {'hospitalId': hospital['id']},
                              );
                            },
                            icon: const Icon(Icons.receipt_long, size: 16),
                            label: const Text('Invoices', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(isActive ? 'Deactivate Hospital Access?' : 'Activate Hospital Access?'),
                                  content: Text(
                                    isActive
                                        ? 'Deactivating "${hospital['name']}" will block all staff members from logging in until subscription is renewed.'
                                        : 'Activate access for "${hospital['name']}"?',
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                try {
                                  final api = ApiService();
                                  await api.post('/hospitals/${hospital['id']}/toggle_active/', {
                                    'action': isActive ? 'deactivate' : 'activate',
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Updated hospital status for ${hospital['name']}')),
                                  );
                                  // Refresh tab
                                  (context as Element).markNeedsBuild();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: ${e.toString()}')),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isActive ? AppTheme.error : AppTheme.success,
                            ),
                            icon: Icon(isActive ? Icons.block : Icons.check_circle, size: 16),
                            label: Text(isActive ? 'Deactivate' : 'Activate', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
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
        content: const Text('Are you sure you want to permanently delete this user? This action cannot be undone.'),
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
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceTab(
    BuildContext context,
    WidgetRef ref,
    AdminRepository adminRepo,
    LocalizationService localization,
  ) {
    return FutureBuilder<List<dynamic>>(
      future: ApiService().get('/payments/history/').then((res) => res.data as List),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading finance records: ${snapshot.error}'));
        }

        final List<dynamic> allPayments = snapshot.data ?? [];
        final successfulPayments = allPayments.where((p) => p['status'] == 'SUCCESS').toList();
        
        final double totalRevenue = successfulPayments.fold(0.0, (sum, p) => sum + (p['amount'] as num).toDouble());
        final double subRevenue = successfulPayments
            .where((p) => p['payment_type'] == 'Hospital Subscription')
            .fold(0.0, (sum, p) => sum + (p['amount'] as num).toDouble());
        final double reqRevenue = successfulPayments
            .where((p) => p['payment_type'] != 'Hospital Subscription')
            .fold(0.0, (sum, p) => sum + (p['amount'] as num).toDouble());

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FINANCIAL SYSTEM STATS',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.success, Colors.teal.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.success.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Revenue Collected',
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                              ),
                              Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 24.w),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            '${totalRevenue.toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.card_membership_rounded, color: AppTheme.primaryColor, size: 18.w),
                                    SizedBox(width: 6.w),
                                    Text(
                                      'Subscriptions',
                                      style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  '${subRevenue.toStringAsFixed(0)} FCFA',
                                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.local_hospital_rounded, color: AppTheme.accentColor, size: 18.w),
                                    SizedBox(width: 6.w),
                                    Text(
                                      'Blood Request',
                                      style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  '${reqRevenue.toStringAsFixed(0)} FCFA',
                                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    
                    Text(
                      'TRANSACTION LOG & RECEIPTS',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            allPayments.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 48.w, color: Colors.grey.shade300),
                          SizedBox(height: 12.h),
                          const Text('No transactions recorded yet', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final payment = allPayments[index] as Map<String, dynamic>;
                          final amount = (payment['amount'] ?? 0.0) as double;
                          final dateStr = payment['created_at'] ?? '';
                          final parsedDate = dateStr.isNotEmpty ? DateTime.parse(dateStr) : DateTime.now();
                          final dateFormatted = dateStr.isNotEmpty 
                              ? "${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}"
                              : '';
                          final status = (payment['status'] ?? 'PENDING').toString().toUpperCase();
                          final isSuccess = status == 'SUCCESS' || status == 'PAID';
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: 12.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              leading: CircleAvatar(
                                backgroundColor: isSuccess 
                                    ? AppTheme.success.withOpacity(0.12)
                                    : AppTheme.warning.withOpacity(0.12),
                                child: Icon(
                                  payment['payment_type'] == 'Hospital Subscription'
                                      ? Icons.card_membership_rounded
                                      : Icons.local_hospital_rounded,
                                  color: isSuccess ? AppTheme.success : AppTheme.warning,
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      payment['payment_type'] ?? 'Payment',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                                    ),
                                  ),
                                  Text(
                                    '${amount.toStringAsFixed(0)} FCFA',
                                    style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.onSurface, fontSize: 14.sp),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: EdgeInsets.only(top: 6.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Payer: ${payment['user_name']} (${payment['user_role']})'),
                                    SizedBox(height: 2.h),
                                    Text('Ref: ${payment['transaction_reference'] ?? "N/A"}'),
                                    SizedBox(height: 2.h),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(dateFormatted, style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: isSuccess 
                                                ? AppTheme.success.withOpacity(0.1)
                                                : AppTheme.warning.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 9.sp, 
                                              fontWeight: FontWeight.bold, 
                                              color: isSuccess ? AppTheme.success : AppTheme.warning
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () {
                                const ReceiptHistoryScreen().showReceiptDetailsSheetFromContext(context, payment);
                              },
                            ),
                          );
                        },
                        childCount: allPayments.length,
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}
