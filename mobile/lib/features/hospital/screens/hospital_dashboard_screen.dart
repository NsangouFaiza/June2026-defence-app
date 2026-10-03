import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/hospital_repository.dart';
import '../../../../data/models/hospital_model.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../features/auth/providers/auth_providers.dart';
import '../../payment/screens/receipt_history_screen.dart';
import '../../../widgets/floating_ai_assistant_button.dart';
import '../../../../data/models/blood_inventory_model.dart';
import '../../../../core/constants/app_constants.dart';

class HospitalDashboardScreen extends ConsumerStatefulWidget {
  const HospitalDashboardScreen({super.key});

  @override
  ConsumerState<HospitalDashboardScreen> createState() => _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState extends ConsumerState<HospitalDashboardScreen> {
  HospitalModel? _hospital;
  bool _isInitialized = false;
  late Future<HospitalModel?> _hospitalFuture;
  late Future<List<BloodInventoryModel>> _inventoryFuture;

  @override
  void initState() {
    super.initState();
    _hospitalFuture = ref.read(hospitalRepositoryProvider).getMyHospital();
    _inventoryFuture = ref.read(inventoryRepositoryProvider).getInventory();
  }

  void _refreshData() {
    setState(() {
      _hospitalFuture = ref.read(hospitalRepositoryProvider).getMyHospital();
      _inventoryFuture = ref.read(inventoryRepositoryProvider).getInventory();
      _isInitialized = false;
    });
  }

  void _showEditHospitalDialog(BuildContext context, HospitalModel currentHospital) {
    final nameController = TextEditingController(text: currentHospital.name);
    final descriptionController = TextEditingController(text: currentHospital.description);
    final addressController = TextEditingController(text: currentHospital.address);
    final cityController = TextEditingController(text: currentHospital.city);
    final regionController = TextEditingController(text: currentHospital.region);
    final phoneController = TextEditingController(text: currentHospital.phoneNumber);
    final emailController = TextEditingController(text: currentHospital.email);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: const Text('Edit Hospital Details'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Hospital Name'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: cityController,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: regionController,
                    decoration: const InputDecoration(labelText: 'Region'),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    _hospital = HospitalModel(
                      id: currentHospital.id,
                      name: nameController.text,
                      description: descriptionController.text,
                      address: addressController.text,
                      city: cityController.text,
                      region: regionController.text,
                      phoneNumber: phoneController.text,
                      email: emailController.text,
                      isActive: currentHospital.isActive,
                      createdAt: currentHospital.createdAt,
                    );
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hospital details updated successfully'), backgroundColor: AppTheme.success),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        floatingActionButton: const FloatingAiAssistantButton(),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: TabBar(
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 12.sp),
              tabs: [
                Tab(
                  icon: const Icon(Icons.dashboard_rounded),
                  text: localization.translate('dashboard'),
                ),
                Tab(
                  icon: const Icon(Icons.receipt_long_rounded),
                  text: localization.translate('receipts'),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            FutureBuilder<HospitalModel?>(
              future: _hospitalFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !_isInitialized && _hospital == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.connectionState == ConnectionState.waiting && _hospital == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError && _hospital == null) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
                          SizedBox(height: 16.h),
                          Text('Failed to load hospital profile', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8.h),
                          Text('${snapshot.error}', style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant), textAlign: TextAlign.center),
                          SizedBox(height: 16.h),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {
                              _hospitalFuture = ref.read(hospitalRepositoryProvider).getMyHospital();
                            }),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasData && snapshot.data != null) {
                  _hospital = snapshot.data;
                  _isInitialized = true;
                }

                if (_hospital == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final hospital = _hospital!;


                final now = DateTime.now();
                final difference = hospital.subscriptionEndDate != null ? hospital.subscriptionEndDate!.difference(now) : null;
                final daysRemaining = difference != null ? difference.inDays : 0;
                final hoursRemaining = difference != null ? difference.inHours % 24 : 0;

                String countdownText = '';
                if (difference != null) {
                  if (daysRemaining > 0) {
                    countdownText = '$daysRemaining ${localization.translate(daysRemaining > 1 ? "days_remaining" : "day_remaining")}';
                  } else if (hoursRemaining > 0) {
                    countdownText = '$hoursRemaining ${localization.translate(hoursRemaining > 1 ? "hours_remaining" : "hour_remaining")}';
                  } else {
                    countdownText = localization.translate('expires_today');
                  }
                }

                return CustomScrollView(
                  slivers: [
                    // Header Banner
                    SliverToBoxAdapter(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.secondaryColor,
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(30.r),
                            bottomRight: Radius.circular(30.r),
                          ),
                        ),
                        child: SafeArea(
                          child: Row(
                            children: [
                              if (Navigator.canPop(context)) ...[
                                IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                SizedBox(width: 4.w),
                              ],
                              // Profile Avatar
                              InkWell(
                                onTap: () => Navigator.of(context).pushNamed('/profile'),
                                child: Container(
                                  width: 54.w,
                                  height: 54.w,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: user?.fullProfilePictureUrl != null && user!.fullProfilePictureUrl!.isNotEmpty
                                      ? ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: user.fullProfilePictureUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget: (context, url, error) => Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 28.w,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 28.w,
                                        ),
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user != null ? 'Welcome Back, ${user.fullName}' : 'Welcome Back',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: EdgeInsets.all(4.w),
                                          child: Image.asset(
                                            'assets/images/logo.png',
                                            height: 20.w,
                                            width: 20.w,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            hospital.name,
                                            style: TextStyle(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Notification Icon
                              InkWell(
                                onTap: () => Navigator.of(context).pushNamed('/notifications'),
                                child: Container(
                                  width: 42.w,
                                  height: 42.w,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        Icons.notifications_outlined,
                                        color: Colors.white,
                                        size: 22.w,
                                      ),
                                      Positioned(
                                        top: 8.w,
                                        right: 8.w,
                                        child: Container(
                                          width: 8.w,
                                          height: 8.w,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 20.h)),

                    // Hospital Info Card (Address, Phone, Subscription status)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                            side: BorderSide(color: Colors.grey.shade100, width: 1),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hospital.address ?? '',
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.onSurface,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            '${hospital.city}, ${hospital.region}',
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: AppTheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                                      onPressed: () => _showEditHospitalDialog(context, hospital),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Wrap(
                                  spacing: 16.w,
                                  runSpacing: 8.h,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.phone_outlined, size: 16.w, color: Colors.grey),
                                        SizedBox(width: 8.w),
                                        Text(
                                          hospital.phoneNumber ?? '',
                                          style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurface),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.email_outlined, size: 16.w, color: Colors.grey),
                                        SizedBox(width: 8.w),
                                        Text(
                                          hospital.email ?? '',
                                          style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurface),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Container(
                                  padding: EdgeInsets.all(12.w),
                                  decoration: BoxDecoration(
                                    color: hospital.computedIsSubscriptionActive
                                        ? AppTheme.success.withOpacity(0.08)
                                        : AppTheme.error.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            hospital.computedIsSubscriptionActive
                                                ? Icons.verified_user
                                                : Icons.gpp_maybe,
                                            color: hospital.computedIsSubscriptionActive
                                                ? AppTheme.success
                                                : AppTheme.error,
                                            size: 22.w,
                                          ),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  hospital.computedIsSubscriptionActive
                                                      ? 'Subscription Status: Active'
                                                      : 'Subscription Status: Inactive / Not Subscribed',
                                                  style: TextStyle(
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: hospital.computedIsSubscriptionActive
                                                        ? AppTheme.success
                                                        : AppTheme.error,
                                                  ),
                                                ),
                                                SizedBox(height: 4.h),
                                                if (hospital.computedIsSubscriptionActive) ...[
                                                  if (hospital.subscriptionEndDate != null) ...[
                                                    Text(
                                                      '${localization.translate('valid_until')}: ${hospital.subscriptionEndDate.toString().substring(0, 10)}',
                                                      style: TextStyle(
                                                        fontSize: 11.sp,
                                                        color: AppTheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                  SizedBox(height: 2.h),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.hourglass_bottom_rounded, size: 12.sp, color: AppTheme.success),
                                                      SizedBox(width: 4.w),
                                                      Text(
                                                        countdownText,
                                                        style: TextStyle(
                                                          fontSize: 11.sp,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppTheme.success,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ] else ...[
                                                  Text(
                                                    'Your hospital is currently not visible to other users. Complete your subscription payment to make your hospital available in the system.',
                                                    style: TextStyle(
                                                      fontSize: 11.sp,
                                                      color: AppTheme.error.withOpacity(0.9),
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12.h),
                                      Wrap(
                                        spacing: 8.w,
                                        runSpacing: 8.h,
                                        alignment: WrapAlignment.end,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).pushNamed(
                                                '/hospital-subscription-history',
                                                arguments: {'hospitalId': hospital.id},
                                              );
                                            },
                                            icon: const Icon(Icons.receipt_long_rounded, size: 14),
                                            label: Text(localization.translate('invoices'), style: TextStyle(fontSize: 11.sp)),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).pushNamed(
                                                '/hospital-subscription-payment',
                                                arguments: {
                                                  'hospitalId': hospital.id,
                                                  'hospitalName': hospital.name,
                                                },
                                              ).then((_) {
                                                _refreshData();
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                                              backgroundColor: AppTheme.primaryColor,
                                              foregroundColor: Colors.white,
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            icon: const Icon(Icons.autorenew_rounded, size: 14),
                                            label: Text(
                                              hospital.computedIsSubscriptionActive
                                                  ? 'Extend Subscription'
                                                  : 'Pay / Activate Subscription',
                                              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 12.h),

                                if (hospital.description != null && hospital.description!.isNotEmpty) ...[
                                  Text(
                                    hospital.description!,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppTheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 24.h)),

                    // Blood Stock Overview (8 Groups)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Blood Bank Inventory',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.onSurface,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await Navigator.of(context).pushNamed('/blood-inventory');
                                    _refreshData();
                                  },
                                  child: const Text('View All'),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            FutureBuilder<List<BloodInventoryModel>>(
                              future: _inventoryFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return SizedBox(
                                    height: 120.h,
                                    child: const Center(child: CircularProgressIndicator()),
                                  );
                                }
                                final inventory = snapshot.data ?? [];
                                final stockMap = <String, int>{};
                                for (final item in inventory) {
                                  if (item.status.toLowerCase() == 'available' &&
                                      !item.expirationDate.isBefore(DateTime.now())) {
                                    stockMap[item.bloodGroup] =
                                        (stockMap[item.bloodGroup] ?? 0) + item.quantity;
                                  }
                                }

                                return GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 4,
                                  mainAxisSpacing: 10.w,
                                  crossAxisSpacing: 10.w,
                                  childAspectRatio: 0.85,
                                  children: AppConstants.bloodGroups.map((group) {
                                    final count = stockMap[group] ?? 0;
                                    final Color color = count >= 10
                                        ? AppTheme.success
                                        : count >= 5
                                            ? AppTheme.warning
                                            : AppTheme.error;
                                    return _buildBloodGroupCard(group, count, color);
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 24.h)),

                    // Responsive 2-Column Grid of Large Clickable Icon Cards
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STAFF MANAGEMENT CENTER',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 14.h,
                              crossAxisSpacing: 14.w,
                              childAspectRatio: 1.1,
                              children: [
                                _buildActionCard(
                                  title: 'Update Inventory',
                                  description: 'Manage blood stock & expiration dates',
                                  icon: Icons.inventory_2_rounded,
                                  gradient: const [Color(0xFFE53935), Color(0xFFC62828)],
                                  onTap: () => Navigator.of(context).pushNamed('/blood-inventory'),
                                ),
                                _buildActionCard(
                                  title: 'Manage Requests',
                                  description: 'Approve or fulfill patient blood needs',
                                  icon: Icons.assignment_rounded,
                                  gradient: const [Color(0xFF43A047), Color(0xFF2E7D32)],
                                  onTap: () => Navigator.of(context).pushNamed('/blood-requests'),
                                ),
                                _buildActionCard(
                                  title: 'Contact Donors',
                                  description: 'Search & reach out to local donors',
                                  icon: Icons.people_rounded,
                                  gradient: const [Color(0xFF1E88E5), Color(0xFF1565C0)],
                                  onTap: () => Navigator.of(context).pushNamed('/donor-list'),
                                ),
                                _buildActionCard(
                                  title: 'Appointments',
                                  description: 'Schedule & confirm donation visits',
                                  icon: Icons.calendar_month_rounded,
                                  gradient: const [Color(0xFF3F51B5), Color(0xFF303F9F)],
                                  onTap: () => Navigator.of(context).pushNamed('/manage-appointments'),
                                ),
                                _buildActionCard(
                                  title: 'Send Alerts',
                                  description: 'Broadcast urgent shortage alerts',
                                  icon: Icons.notifications_active_rounded,
                                  gradient: const [Color(0xFFFF9800), Color(0xFFF57C00)],
                                  onTap: () => Navigator.of(context).pushNamed('/manage-appointments'),
                                ),
                                _buildActionCard(
                                  title: 'Reports & Analytics',
                                  description: 'View blood usage & supply trends',
                                  icon: Icons.analytics_rounded,
                                  gradient: const [Color(0xFF8E24AA), Color(0xFF6A1B9A)],
                                  onTap: () => Navigator.of(context).pushNamed('/reports'),
                                ),
                                _buildActionCard(
                                  title: 'Blood Campaigns',
                                  description: 'Organize & promote donation drives',
                                  icon: Icons.campaign_rounded,
                                  gradient: const [Color(0xFF00ACC1), Color(0xFF00838F)],
                                  onTap: () => Navigator.of(context).pushNamed('/campaigns'),
                                ),
                                _buildActionCard(
                                  title: 'Lab Control Center',
                                  description: 'Full lab testing, sample analysis & screening portal',
                                  icon: Icons.biotech_rounded,
                                  gradient: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
                                  onTap: () => Navigator.of(context).pushNamed('/lab-dashboard'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 24.h)),

                    // Analytics Summary Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weekly Performance & Analytics',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            _buildAnalyticsCard(
                              'Daily Requests',
                              '24 requests today',
                              Icons.trending_up_rounded,
                              AppTheme.primaryColor,
                              '+12%',
                            ),
                            SizedBox(height: 10.h),
                            _buildAnalyticsCard(
                              'Blood Usage',
                              '156 units issued this week',
                              Icons.water_drop_rounded,
                              AppTheme.accentColor,
                              '+8%',
                            ),
                            SizedBox(height: 10.h),
                            _buildAnalyticsCard(
                              'Inventory Reserves',
                              'Optimal stock levels maintained',
                              Icons.show_chart_rounded,
                              AppTheme.success,
                              '+2%',
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 80.h)),
                  ],
                );
              },
            ),
            const ReceiptHistoryScreen(isTab: true),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodGroupCard(String bloodGroup, int units, Color statusColor) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  bloodGroup,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '$units',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              'units',
              style: TextStyle(
                fontSize: 9.sp,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 26.w),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String trend,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 24.w),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              trend,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
