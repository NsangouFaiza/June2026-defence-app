import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/repositories/donor_repository.dart';
import '../../../data/models/donor_model.dart';
import '../../../data/services/api_service.dart';

class DigitalDonorBadgeScreen extends ConsumerWidget {
  const DigitalDonorBadgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donorRepo = ref.watch(donorRepositoryProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Verified Donor Badge Credential'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<DonorModel?>(
        future: donorRepo.getCurrentDonorProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Failed to load donor profile. Please try again.'),
              ),
            );
          }

          final donor = snapshot.data!;
          final hasDonated = donor.totalDonations > 0;
          final donorLevel = donor.level;
          final verificationUrl = '${ApiService.serverBaseUrl}/api/donors/verify-badge/${donor.donorIdCode}/';
          final levelTheme = _getLevelTheme(donorLevel, donor.totalDonations);

          final dobFormatted = user?.dateOfBirth != null
              ? DateFormat('dd/MM/yyyy').format(user!.dateOfBirth!)
              : '15/08/1995';
          final pobFormatted = user?.city != null && user!.city!.isNotEmpty
              ? '${user.city}, ${user.region ?? "Cameroon"}'
              : 'Douala, Cameroon';

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Warning / Unlocked info banner
                if (!hasDonated)
                  Container(
                    margin: EdgeInsets.only(bottom: 20.h),
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppTheme.error.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: AppTheme.error, size: 24.w),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Text(
                            'Official verification, validation seal, and sharing credentials will unlock automatically upon your first completed blood donation at any LifeLink partner hospital.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.error,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Redesigned Card Front UI
                Center(
                  child: Container(
                    width: 330.w,
                    height: 570.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(
                        color: hasDonated ? levelTheme.accentColor.withOpacity(0.4) : Colors.grey.shade300,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        if (hasDonated)
                          BoxShadow(
                            color: levelTheme.accentColor.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22.r),
                      child: Stack(
                        children: [
                          // Background security stripes pattern
                          Positioned.fill(
                            child: CustomPaint(
                              painter: CardPatternPainter(),
                            ),
                          ),
                          
                          // Medical watermark
                          Positioned(
                            right: -40.w,
                            bottom: 120.h,
                            child: Opacity(
                              opacity: 0.03,
                              child: Icon(
                                Icons.local_hospital_rounded,
                                size: 220.w,
                                color: Colors.red,
                              ),
                            ),
                          ),

                          // Top Header Panel
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: hasDonated
                                      ? [const Color(0xFFD32F2F), const Color(0xFFB71C1C)]
                                      : [Colors.grey.shade600, Colors.grey.shade800],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _buildDropletLogo(22.h),
                                      SizedBox(width: 8.w),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'LIFELINK',
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                          Text(
                                            'OFFICIAL MEDICAL CREDENTIAL',
                                            style: TextStyle(
                                              fontSize: 7.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white.withOpacity(0.8),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                    decoration: BoxDecoration(
                                      color: hasDonated ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      hasDonated ? 'VERIFIED DONOR' : 'DRAFT CARD',
                                      style: TextStyle(
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Main Info Content
                          Positioned.fill(
                            top: 52.h,
                            child: Padding(
                              padding: EdgeInsets.all(16.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(height: 12.h),
                                  // Profile picture and verification badge
                                  Center(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 96.w,
                                          height: 96.w,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: hasDonated ? levelTheme.cardGradients : [Colors.grey.shade400, Colors.grey.shade600],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 88.w,
                                          height: 88.w,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: Builder(
                                            builder: (context) {
                                              final pic = user?.fullProfilePictureUrl;
                                              return pic != null && pic.isNotEmpty
                                                  ? ClipOval(
                                                      child: CachedNetworkImage(
                                                        imageUrl: pic,
                                                        fit: BoxFit.cover,
                                                        errorWidget: (context, url, error) => Icon(
                                                          Icons.person,
                                                          size: 40.w,
                                                          color: Colors.grey.shade300,
                                                        ),
                                                      ),
                                                    )
                                                  : Icon(
                                                      Icons.person,
                                                      size: 40.w,
                                                      color: Colors.grey.shade300,
                                                    );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 10.h),

                                  // Name and Status
                                  Text(
                                    user?.fullName ?? 'Donor Name',
                                    style: TextStyle(
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1F2937),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 4.h),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        hasDonated ? Icons.verified_user_rounded : Icons.pending_outlined,
                                        size: 13.sp,
                                        color: hasDonated ? const Color(0xFF2E7D32) : Colors.grey.shade600,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        hasDonated ? 'Official LifeLink Verified Donor' : 'Pending Activation Seal',
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w600,
                                          color: hasDonated ? const Color(0xFF2E7D32) : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.h),

                                  // Unique Donor ID & Blood Group Info Panel
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: hasDonated
                                          ? const Color(0xFFB71C1C).withOpacity(0.04)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: hasDonated
                                            ? const Color(0xFFB71C1C).withOpacity(0.12)
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'DONOR UNIQUE ID',
                                              style: TextStyle(
                                                fontSize: 8.sp,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              donor.donorIdCode,
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF1F2937),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.bloodtype_rounded,
                                              color: const Color(0xFFD32F2F),
                                              size: 16.sp,
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              donor.bloodGroup ?? 'O+',
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w900,
                                                color: const Color(0xFFD32F2F),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 10.h),

                                  // Information details grid table
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(12.r),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildInfoRow('Full Name', user?.fullName ?? 'N/A'),
                                          _buildInfoRow('Date of Birth (DOB)', dobFormatted),
                                          _buildInfoRow('Place of Birth (POB)', pobFormatted),
                                          _buildInfoRow('Phone Number', user?.phoneNumber ?? 'N/A'),
                                          _buildInfoRow('Donor Level', '${donor.level} ${levelTheme.emoji}'),
                                          _buildInfoRow('Successful Donations', '${donor.totalDonations} Completed'),
                                          _buildInfoRow(
                                            'Last Donation Date',
                                            donor.lastDonationDate != null
                                                ? DateFormat('dd/MM/yyyy').format(donor.lastDonationDate!)
                                                : 'No record found',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 10.h),

                                  // Bottom Row: QR verification and seal stamp
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Verification QR
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 68.w,
                                            height: 68.w,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10.r),
                                              border: Border.all(color: Colors.grey.shade300),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.04),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            padding: EdgeInsets.all(6.w),
                                            child: CustomPaint(
                                              size: Size(56.w, 56.w),
                                              painter: QRCodePainter(verificationUrl),
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            'SCAN TO VERIFY',
                                            style: TextStyle(
                                              fontSize: 7.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Authenticity Seal
                                      _buildAuthenticitySeal(
                                        hasDonated ? levelTheme.accentColor : Colors.grey,
                                        hasDonated,
                                      ),
                                    ],
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
                SizedBox(height: 24.h),

                // Buttons container
                Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 400.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: hasDonated 
                              ? () => _simulateSharing(context, user)
                              : () {
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sharing is disabled until your first successful blood donation.'),
                                      backgroundColor: AppTheme.error,
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasDonated ? AppTheme.primaryColor : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            elevation: hasDonated ? 3 : 0,
                            shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: Text(
                            'Share Credential Certificate',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        OutlinedButton.icon(
                          onPressed: hasDonated 
                              ? () => _simulateDownload(context)
                              : () {
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Downloads are disabled until your first successful blood donation.'),
                                      backgroundColor: AppTheme.error,
                                    ),
                                  );
                                },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            side: BorderSide(color: hasDonated ? AppTheme.primaryColor : Colors.grey.shade400, width: 1.5),
                            foregroundColor: hasDonated ? AppTheme.primaryColor : Colors.grey.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                          label: Text(
                            'Download Official PDF / Image',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropletLogo(double size) {
    return Image.asset(
      'assets/images/logo.png',
      height: size,
      fit: BoxFit.contain,
    );
  }

  // Circular detailed Authenticity Seal Stamp "Official LifeLink Verified Donor"
  Widget _buildAuthenticitySeal(Color accentColor, bool hasDonated) {
    return Container(
      width: 76.w,
      height: 76.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: accentColor.withOpacity(0.7), width: 2),
      ),
      padding: EdgeInsets.all(4.w),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accentColor.withOpacity(0.5), width: 1, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hasDonated ? 'OFFICIAL' : 'PENDING',
              style: TextStyle(
                fontSize: 6.sp,
                fontWeight: FontWeight.bold,
                color: accentColor,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 2.h),
            Icon(
              hasDonated ? Icons.verified_rounded : Icons.lock_reset_rounded,
              color: accentColor,
              size: 16.w,
            ),
            SizedBox(height: 2.h),
            Text(
              hasDonated ? 'VERIFIED' : 'INACTIVE',
              style: TextStyle(
                fontSize: 6.sp,
                fontWeight: FontWeight.bold,
                color: accentColor,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  _BadgeLevelTheme _getLevelTheme(String level, int totalDonations) {
    if (totalDonations == 0) {
      return _BadgeLevelTheme(
        emoji: '🔒',
        accentColor: const Color(0xFF78909C),
        cardGradients: [
          Colors.grey.shade400,
          Colors.grey.shade500,
          Colors.grey.shade600,
        ],
      );
    }

    switch (level.toLowerCase()) {
      case 'platinum':
        return _BadgeLevelTheme(
          emoji: '💎',
          accentColor: const Color(0xFF00ACC1),
          cardGradients: [
            const Color(0xFF00ACC1),
            const Color(0xFF00838F),
            const Color(0xFF006064),
          ],
        );
      case 'gold':
        return _BadgeLevelTheme(
          emoji: '🥇',
          accentColor: const Color(0xFFF57F17),
          cardGradients: [
            const Color(0xFFFFD54F),
            const Color(0xFFF9A825),
            const Color(0xFFF57F17),
          ],
        );
      case 'silver':
        return _BadgeLevelTheme(
          emoji: '🥈',
          accentColor: const Color(0xFF607D8B),
          cardGradients: [
            const Color(0xFF90A4AE),
            const Color(0xFF78909C),
            const Color(0xFF546E7A),
          ],
        );
      default: // Bronze
        return _BadgeLevelTheme(
          emoji: '🥉',
          accentColor: const Color(0xFF8D6E63),
          cardGradients: [
            const Color(0xFFA1887F),
            const Color(0xFF8D6E63),
            const Color(0xFF6D4C41),
          ],
        );
    }
  }

  // Simulating high quality PDF/Image rendering and download
  void _simulateDownload(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const _ProgressDialog(
          title: 'Generating High-Resolution Certificate',
          message: 'Rendering vector graphics & signatures...',
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Pop dialog
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8.w),
              const Expanded(child: Text('Official credential PDF saved to Downloads successfully!')),
            ],
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    });
  }

  // Simulating sharing process
  void _simulateSharing(BuildContext context, dynamic user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const _ProgressDialog(
          title: 'Packaging Digital Credential',
          message: 'Preparing shareable secure metadata card...',
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      Navigator.pop(context); // Pop dialog
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Credential certificate shared successfully for ${user?.fullName}!'),
          backgroundColor: AppTheme.success,
        ),
      );
    });
  }
}

class _BadgeLevelTheme {
  final String emoji;
  final Color accentColor;
  final List<Color> cardGradients;

  _BadgeLevelTheme({
    required this.emoji,
    required this.accentColor,
    required this.cardGradients,
  });
}

// 3D Flip Card Widget
class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  const FlipCard({super.key, required this.front, required this.back});

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * 3.141592653589793;
          final isBack = angle >= 3.141592653589793 / 2;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 3D Perspective
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.identity()..rotateY(3.141592653589793),
                    alignment: Alignment.center,
                    child: widget.back,
                  )
                : widget.front,
          );
        },
      ),
    );
  }
}

// Animated download progress dialog
class _ProgressDialog extends StatelessWidget {
  final String title;
  final String message;
  const _ProgressDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      content: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(width: 20.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    message,
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter to draw elegant background stripes on the back of the card
class CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double gap = 20.0;
    for (double i = -size.height; i < size.width; i += gap) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CardPatternPainter oldDelegate) => false;
}

class QRCodePainter extends CustomPainter {
  final String data;
  QRCodePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    double markerSize = size.width * 0.25;

    // Top-Left Anchor
    canvas.drawRect(Rect.fromLTWH(0, 0, markerSize, markerSize), paint);
    canvas.drawRect(Rect.fromLTWH(2, 2, markerSize - 4, markerSize - 4), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(6, 6, markerSize - 12, markerSize - 12), paint);

    // Top-Right Anchor
    canvas.drawRect(Rect.fromLTWH(size.width - markerSize, 0, markerSize, markerSize), paint);
    canvas.drawRect(Rect.fromLTWH(size.width - markerSize + 2, 2, markerSize - 4, markerSize - 4), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(size.width - markerSize + 6, 6, markerSize - 12, markerSize - 12), paint);

    // Bottom-Left Anchor
    canvas.drawRect(Rect.fromLTWH(0, size.height - markerSize, markerSize, markerSize), paint);
    canvas.drawRect(Rect.fromLTWH(2, size.height - markerSize + 2, markerSize - 4, markerSize - 4), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(6, size.height - markerSize + 6, markerSize - 12, markerSize - 12), paint);

    for (int i = 0; i < 15; i++) {
      for (int j = 0; j < 15; j++) {
        if (i < 5 && j < 5) continue;
        if (i > 9 && j < 5) continue;
        if (i < 5 && j > 9) continue;

        int hash = (i * 37 + j * 17 + data.hashCode) % 5;
        if (hash == 0 || hash == 2) {
          canvas.drawRect(
            Rect.fromLTWH(
              i * (size.width / 15),
              j * (size.height / 15),
              size.width / 15 - 1,
              size.height / 15 - 1,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(QRCodePainter oldDelegate) => oldDelegate.data != data;
}
