import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/blood_request_model.dart';
import '../../../../data/models/blood_inventory_model.dart';
import '../../../../data/models/hospital_model.dart';
import '../../../../data/models/donor_model.dart';

class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final requestRepo = ref.watch(requestRepositoryProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          requestRepo.getMyRequests().catchError((_) => <BloodRequestModel>[]),
          ref.watch(inventoryRepositoryProvider).getInventory().catchError((_) => <BloodInventoryModel>[]),
          ref.watch(hospitalRepositoryProvider).getHospitals().catchError((_) => <HospitalModel>[]),
          ref.watch(donorRepositoryProvider).getDonors().catchError((_) => <DonorModel>[]),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading dashboard: ${snapshot.error}'));
          }

          final results = snapshot.data ?? [[], [], [], []];
          final requests = results[0] as List<BloodRequestModel>;
          final inventory = results[1] as List<BloodInventoryModel>;
          final hospitals = results[2] as List<HospitalModel>;
          final donors = results[3] as List<DonorModel>;

          final totalBloodPacks = inventory.fold<int>(0, (sum, item) => sum + item.quantity);
          final nearbyHospitals = hospitals.length;
          final activeDonors = donors.length;

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
                    bottom: false,
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
                                      'Patient Care Hub',
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

              // Live Statistics Overview
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BLOOD SUPPLY & NETWORK STATUS',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              totalBloodPacks.toString(),
                              'Available Blood Units',
                              Icons.bloodtype_rounded,
                              AppTheme.primaryColor,
                              onTap: () => Navigator.of(context).pushNamed('/available-blood-packs'),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildStatCard(
                              nearbyHospitals.toString(),
                              'Hospitals & Banks',
                              Icons.local_hospital_rounded,
                              AppTheme.accentColor,
                              onTap: () => Navigator.of(context).pushNamed('/hospital-locator'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _buildStatCard(
                        activeDonors.toString(),
                        'Registered Active Donors Nearby',
                        Icons.people_rounded,
                        AppTheme.success,
                        onTap: () => Navigator.of(context).pushNamed('/donor-list'),
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
                        'PATIENT SERVICES & ACTIONS',
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
                            title: 'Request Blood',
                            description: 'Submit a new request for blood units',
                            icon: Icons.bloodtype_rounded,
                            gradient: const [Color(0xFFE53935), Color(0xFFC62828)],
                            onTap: () => Navigator.of(context).pushNamed('/blood-request'),
                          ),
                          _buildActionCard(
                            title: 'Find Hospitals',
                            description: 'Locate blood banks & hospital map',
                            icon: Icons.local_hospital_rounded,
                            gradient: const [Color(0xFF1E88E5), Color(0xFF1565C0)],
                            onTap: () => Navigator.of(context).pushNamed('/hospital-locator'),
                          ),
                          _buildActionCard(
                            title: 'Contact Donors',
                            description: 'Browse & connect with compatible donors',
                            icon: Icons.people_rounded,
                            gradient: const [Color(0xFF43A047), Color(0xFF2E7D32)],
                            onTap: () => Navigator.of(context).pushNamed('/donor-list'),
                          ),
                          _buildActionCard(
                            title: 'My Requests',
                            description: 'Track request status & make payments',
                            icon: Icons.assignment_rounded,
                            gradient: const [Color(0xFFFB8C00), Color(0xFFEF6C00)],
                            onTap: () => Navigator.of(context).pushNamed('/blood-requests'),
                          ),
                          _buildActionCard(
                            title: 'Direct Chats',
                            description: 'Message donors & hospital staff',
                            icon: Icons.forum_rounded,
                            gradient: const [Color(0xFF8E24AA), Color(0xFF6A1B9A)],
                            onTap: () => Navigator.of(context).pushNamed('/chat-list'),
                          ),
                          _buildActionCard(
                            title: 'Appointments',
                            description: 'Manage clinic & screening visits',
                            icon: Icons.calendar_month_rounded,
                            gradient: const [Color(0xFF00ACC1), Color(0xFF00838F)],
                            onTap: () => Navigator.of(context).pushNamed('/appointment-history'),
                          ),
                          _buildActionCard(
                            title: 'Emergency SOS',
                            description: 'Broadcast urgent emergency alert',
                            icon: Icons.emergency_rounded,
                            gradient: const [Color(0xFFFF1744), Color(0xFFD50000)],
                            onTap: () => Navigator.of(context).pushNamed('/emergency-request'),
                          ),
                          _buildActionCard(
                            title: 'Available Stock',
                            description: 'Search live blood inventory packs',
                            icon: Icons.inventory_2_rounded,
                            gradient: const [Color(0xFF3F51B5), Color(0xFF303F9F)],
                            onTap: () => Navigator.of(context).pushNamed('/available-blood-packs'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 24.h)),

              // Recent Patient Blood Requests
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
                            'Recent Blood Requests',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pushNamed('/blood-requests'),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      requests.isEmpty
                          ? Container(
                              padding: EdgeInsets.symmetric(vertical: 40.h),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 56.w,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      'No active blood requests logged.',
                                      style: TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: requests.length > 3 ? 3 : requests.length,
                              itemBuilder: (context, index) {
                                final request = requests[index];
                                return _buildRequestCard(context, request);
                              },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed('/emergency-request'),
        backgroundColor: AppTheme.error,
        icon: const Icon(Icons.emergency_rounded, color: Colors.white),
        label: const Text('EMERGENCY SOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 6,
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
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
                      value,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildRequestCard(BuildContext context, BloodRequestModel request) {
    final showPayButton = request.status.toUpperCase() == 'APPROVED' && request.paymentStatus.toUpperCase() == 'PENDING';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  _getStatusIcon(request.status),
                  color: _getStatusColor(request.status),
                  size: 24.w,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.bloodGroup} • ${request.quantity} unit(s)',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      request.hospitalName ?? 'Unknown hospital',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(request.status),
                  ),
                ),
              ),
            ],
          ),
          if (showPayButton) ...[
            const Divider(height: 20, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment: PENDING',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      '/payment',
                      arguments: {
                        'requestId': request.id,
                        'amount': request.quantity * 15000.0,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: const Text('Pay Now'),
                ),
              ],
            ),
          ] else if (request.status.toUpperCase() == 'APPROVED' && request.paymentStatus.toUpperCase() == 'PAID') ...[
            const Divider(height: 20, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 16),
                SizedBox(width: 4.w),
                Text(
                  'Payment: PAID (${request.paymentReference ?? ""})',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppTheme.warning;
      case 'approved':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.error;
      case 'fulfilled':
        return AppTheme.primaryColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_rounded;
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'fulfilled':
        return Icons.task_alt_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
