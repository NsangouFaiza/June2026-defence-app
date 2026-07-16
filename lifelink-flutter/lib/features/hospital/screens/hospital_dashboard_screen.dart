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

class HospitalDashboardScreen extends ConsumerStatefulWidget {
  const HospitalDashboardScreen({super.key});

  @override
  ConsumerState<HospitalDashboardScreen> createState() => _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState extends ConsumerState<HospitalDashboardScreen> {
  HospitalModel? _hospital;
  bool _isInitialized = false;
  late Future<HospitalModel?> _hospitalFuture;

  @override
  void initState() {
    super.initState();
    _hospitalFuture = ref.read(hospitalRepositoryProvider).getMyHospital();
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
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  TextFormField(
                    controller: cityController,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  TextFormField(
                    controller: regionController,
                    decoration: const InputDecoration(labelText: 'Region'),
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                  ),
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
                    const SnackBar(content: Text('Hospital details updated successfully')),
                  );
                }
              },
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<HospitalModel?>(
        future: _hospitalFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !_isInitialized) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!_isInitialized) {
            _hospital = snapshot.data ?? HospitalModel(
              id: 1,
              name: 'Central Hospital',
              address: '123 Main Street, City Centre',
              city: 'Yaounde',
              region: 'Centre',
              phoneNumber: '+237 600 000 000',
              email: 'contact@centralhospital.org',
              description: 'Main medical facility and blood bank coordination center.',
              isActive: true,
            );
            _isInitialized = true;
          }

          final hospital = _hospital!;

          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
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
                    bottom: false,
                    child: Row(
                      children: [
                        // Hospital Icon
                        InkWell(
                          onTap: () => Navigator.of(context).pushNamed('/profile'),
                          child: Container(
                            width: 56.w,
                            height: 56.w,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: ClipOval(
                              child: Padding(
                                padding: EdgeInsets.all(4.w),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user != null ? 'Welcome Back, ${user.fullName}' : 'Welcome Back',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Hospital Dashboard - ${hospital.name}',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Notification Icon
                        Container(
                          width: 48.w,
                          height: 48.w,
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
                                size: 24.w,
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
                        SizedBox(width: 8.w),
                        // Logout Button
                        Container(
                          width: 48.w,
                          height: 48.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.white,
                            ),
                            iconSize: 20.w,
                            onPressed: () async {
                              await ref.read(authRepositoryProvider).logout();
                              ref.invalidate(currentUserProvider);
                              if (context.mounted) {
                                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 24.h)),
              
              // Hospital Info Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_hospital, color: AppTheme.primaryColor, size: 24.w),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                hospital.name,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 20.w),
                              onPressed: () => _showEditHospitalDialog(context, hospital),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const Divider(height: 20, thickness: 1),
                        if (hospital.description != null && hospital.description!.isNotEmpty) ...[
                          Text(
                            hospital.description!,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 12.h),
                        ],
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, color: Colors.grey, size: 16.w),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                [hospital.address, hospital.city, hospital.region]
                                    .where((e) => e != null && e.isNotEmpty)
                                    .join(', '),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 16.w,
                          runSpacing: 8.h,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_outlined, color: Colors.grey, size: 16.w),
                                SizedBox(width: 8.w),
                                Text(
                                  hospital.phoneNumber ?? 'No phone contact',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.email_outlined, color: Colors.grey, size: 16.w),
                                SizedBox(width: 8.w),
                                Flexible(
                                  child: Text(
                                    hospital.email ?? 'No email contact',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppTheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 24.h)),
              
              // Blood Inventory Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Blood Inventory',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pushNamed('/blood-inventory'),
                            child: Text('View All'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        mainAxisSpacing: 12.w,
                        crossAxisSpacing: 12.w,
                        childAspectRatio: 0.8,
                        children: [
                          _buildBloodGroupCard('A+', 45, AppTheme.success),
                          _buildBloodGroupCard('A-', 23, AppTheme.warning),
                          _buildBloodGroupCard('B+', 38, AppTheme.success),
                          _buildBloodGroupCard('B-', 15, AppTheme.error),
                          _buildBloodGroupCard('O+', 67, AppTheme.success),
                          _buildBloodGroupCard('O-', 31, AppTheme.warning),
                          _buildBloodGroupCard('AB+', 12, AppTheme.success),
                          _buildBloodGroupCard('AB-', 8, AppTheme.error),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 32.h)),
              
              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12.w,
                        crossAxisSpacing: 12.w,
                        childAspectRatio: 1.1,
                        children: [
                          _buildActionCard(
                            'Update Inventory',
                            Icons.inventory_2,
                            AppTheme.primaryColor,
                            () => Navigator.of(context).pushNamed('/blood-inventory'),
                          ),
                          _buildActionCard(
                            'Manage Requests',
                            Icons.assignment,
                            AppTheme.success,
                            () => Navigator.of(context).pushNamed('/blood-requests'),
                          ),
                          _buildActionCard(
                            'Contact Donors',
                            Icons.people,
                            AppTheme.accentColor,
                            () => Navigator.of(context).pushNamed('/donor-list'),
                          ),
                          _buildActionCard(
                            'Manage Appointments',
                            Icons.event,
                            Colors.indigo,
                            () => Navigator.of(context).pushNamed('/manage-appointments'),
                          ),
                          _buildActionCard(
                            'Send Alerts',
                            Icons.notifications_active,
                            Colors.orange,
                            () => Navigator.of(context).pushNamed('/manage-appointments'),
                          ),
                          _buildActionCard(
                            'Reports',
                            Icons.analytics,
                            Colors.purple,
                            () => Navigator.of(context).pushNamed('/reports'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 32.h)),
              
              // Analytics Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _buildAnalyticsCard(
                        'Daily Requests',
                        '24 requests today',
                        Icons.trending_up,
                        AppTheme.primaryColor,
                        '+12%',
                      ),
                      SizedBox(height: 12.h),
                      _buildAnalyticsCard(
                        'Blood Usage',
                        '156 units this week',
                        Icons.water_drop,
                        AppTheme.accentColor,
                        '+8%',
                      ),
                      SizedBox(height: 12.h),
                      _buildAnalyticsCard(
                        'Inventory Trends',
                        'Stable levels',
                        Icons.show_chart,
                        AppTheme.success,
                        '+2%',
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 100.h)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBloodGroupCard(String bloodGroup, int units, Color statusColor) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  bloodGroup,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '$units',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              'units',
              style: TextStyle(
                fontSize: 10.sp,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
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
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(icon, color: color, size: 28.w),
              ),
              SizedBox(height: 12.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface,
                ),
                textAlign: TextAlign.center,
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
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 24.w),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              trend,
              style: TextStyle(
                fontSize: 12.sp,
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
