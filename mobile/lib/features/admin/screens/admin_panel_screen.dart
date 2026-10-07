import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/services/api_service.dart';
import '../../../../features/auth/providers/auth_providers.dart';
import '../../payment/screens/receipt_history_screen.dart';
import '../widgets/admin_users_tab.dart';
import '../widgets/admin_hospitals_tab.dart';
import '../widgets/admin_analytics_tab.dart';
import '../../../../widgets/lifelink_app_bar.dart';
import '../../../../widgets/floating_ai_assistant_button.dart';

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
        floatingActionButton: const FloatingAiAssistantButton(),
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
            const AdminUsersTab(),
            const AdminHospitalsTab(),
            _buildFinanceTab(context, ref, adminRepo, localization),
            const AdminAnalyticsTab(),
          ],
        ),
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
                                              color: isSuccess ? AppTheme.success : AppTheme.warning,
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
