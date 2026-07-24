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

                // Redesigned CR80 Landscape Flippable ID Card UI
                Center(
                  child: FlipCard(
                    front: _buildCardFront(context, donor, user, levelTheme, dobFormatted, pobFormatted, hasDonated),
                    back: _buildCardBack(context, donor, user, levelTheme, hasDonated, verificationUrl),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flip_camera_android_rounded, size: 14.sp, color: Colors.grey),
                    SizedBox(width: 6.w),
                    Text(
                      'Tap card to flip / Appuyez pour retourner',
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ],
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
                            'Share Credential Card',
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
                            'Download Official ID Card',
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

  Widget _buildCardFront(BuildContext context, DonorModel donor, dynamic user, _BadgeLevelTheme levelTheme, String dobFormatted, String pobFormatted, bool hasDonated) {
    return Container(
      width: 340.w,
      height: 215.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          children: [
            // Background gradient and stripes
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasDonated 
                        ? [const Color(0xFF8B0000), const Color(0xFF2A0000)]
                        : [Colors.grey.shade700, Colors.grey.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: CardPatternPainter(),
              ),
            ),
            
            // Medical icon watermark
            Positioned(
              right: -30.w,
              bottom: -30.h,
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  Icons.local_hospital_rounded,
                  size: 150.w,
                  color: Colors.white,
                ),
              ),
            ),

            // Top Header Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 38.h,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildDropletLogo(20.h),
                        SizedBox(width: 6.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'LIFELINK NETWORK',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              'DIGITAL HEALTH IDENTITY',
                              style: TextStyle(
                                fontSize: 6.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.6),
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
                        color: hasDonated ? AppTheme.success.withOpacity(0.25) : Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: hasDonated ? AppTheme.success.withOpacity(0.6) : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasDonated ? Icons.verified_user_rounded : Icons.pending_rounded,
                            size: 8.sp,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            hasDonated ? 'VERIFIED DONOR' : 'DRAFT CREDENTIAL',
                            style: TextStyle(
                              fontSize: 7.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Body
            Positioned.fill(
              top: 38.h,
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Row(
                  children: [
                    // Left Column: Photo & Blood Group Badge
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Profile picture with border
                        Container(
                          width: 68.w,
                          height: 68.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasDonated ? levelTheme.accentColor : Colors.grey.shade400,
                              width: 2.w,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Builder(
                              builder: (context) {
                                final pic = user?.fullProfilePictureUrl;
                                return pic != null && pic.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: pic,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey.shade300,
                                          child: Icon(Icons.person, size: 30.w, color: Colors.grey.shade600),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey.shade300,
                                        child: Icon(Icons.person, size: 30.w, color: Colors.grey.shade600),
                                      );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        // Prominent Blood Group Badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bloodtype_rounded, color: Colors.white, size: 10.sp),
                              SizedBox(width: 2.w),
                              Text(
                                donor.bloodGroup ?? 'O+',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 14.w),

                    // Right Column: Identity Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            (user?.fullName ?? 'Donor Name').toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'DONOR ID: ${donor.donorIdCode}',
                            style: TextStyle(
                              fontSize: 8.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          
                          // Grid details
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactLabelVal('DOB', dobFormatted),
                              ),
                              Expanded(
                                child: _buildCompactLabelVal('PHONE', user?.phoneNumber ?? 'N/A'),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactLabelVal('LEVEL', '${donor.level} ${levelTheme.emoji}'),
                              ),
                              Expanded(
                                child: _buildCompactLabelVal('STATUS', hasDonated ? 'ACTIVE VERIFIED' : 'PENDING DONATION'),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 10.h),
                          // Bottom badge & Script message
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Circular Official Seal
                              _buildCompactAuthenticitySeal(
                                hasDonated ? levelTheme.accentColor : Colors.grey,
                                hasDonated,
                              ),
                              Padding(
                                padding: EdgeInsets.only(right: 8.w),
                                child: Text(
                                  '"Every donation saves lives."',
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack(BuildContext context, DonorModel donor, dynamic user, _BadgeLevelTheme levelTheme, bool hasDonated, String verificationUrl) {
    final memberSince = donor.createdAt != null 
        ? DateFormat('dd/MM/yyyy').format(donor.createdAt!) 
        : '24/07/2026';
    final lastDonationFormatted = donor.lastDonationDate != null
        ? DateFormat('dd/MM/yyyy').format(donor.lastDonationDate!)
        : 'N/A';

    return Container(
      width: 340.w,
      height: 215.h,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate 800 background
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          children: [
            // Security grid pattern on background
            Positioned.fill(
              child: CustomPaint(
                painter: CardPatternPainter(),
              ),
            ),
            
            // 1. Black Magnetic Stripe at the top
            Positioned(
              top: 14.h,
              left: 0,
              right: 0,
              child: Container(
                height: 22.h,
                color: Colors.black,
              ),
            ),

            // Content body below magnetic strip
            Positioned.fill(
              top: 42.h,
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Row(
                  children: [
                    // Left Side: LifeLink Contact & Stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // LifeLink Contact info
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LIFELINK SUPPORT SYSTEM',
                                style: TextStyle(
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.red.shade400,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Phone: +237 677 889 900\nEmail: support@lifelink.org\nWeb: www.lifelink.org',
                                style: TextStyle(
                                  fontSize: 7.sp,
                                  color: Colors.white70,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                          
                          // Policy/Notice
                          Text(
                            'Notice: This digital credential remains the property of LifeLink. Presentation authorize emergency blood access checks.',
                            style: TextStyle(
                              fontSize: 6.sp,
                              color: Colors.white38,
                              height: 1.2,
                            ),
                          ),
                          
                          // Statistics Summary Row
                          Row(
                            children: [
                              _buildBackStat('TOTAL DONATIONS', '${donor.totalDonations}'),
                              SizedBox(width: 8.w),
                              _buildBackStat('LAST DONATION', lastDonationFormatted),
                              SizedBox(width: 8.w),
                              _buildBackStat('MEMBER SINCE', memberSince),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),

                    // Right Side: QR code & barcode signature
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Verification QR Code
                        Container(
                          width: 58.w,
                          height: 58.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6.r),
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          padding: EdgeInsets.all(4.w),
                          child: CustomPaint(
                            size: Size(50.w, 50.w),
                            painter: QRCodePainter(verificationUrl),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'SCAN TO VERIFY',
                          style: TextStyle(
                            fontSize: 6.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white54,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        // Holder Signature mockup line
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 70.w,
                              height: 1.h,
                              color: Colors.white38,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Holder Signature',
                              style: TextStyle(
                                fontSize: 5.sp,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        // Barcode
                        Container(
                          width: 70.w,
                          height: 12.h,
                          color: Colors.transparent,
                          child: CustomPaint(
                            painter: BarcodePainter(),
                          ),
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
    );
  }

  Widget _buildCompactLabelVal(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 6.sp,
            fontWeight: FontWeight.w900,
            color: Colors.white54,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 8.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactAuthenticitySeal(Color accentColor, bool hasDonated) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: accentColor.withOpacity(0.8), width: 1.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasDonated ? Icons.verified_rounded : Icons.lock_rounded,
            color: accentColor,
            size: 8.sp,
          ),
          SizedBox(width: 3.w),
          Text(
            hasDonated ? 'OFFICIAL SEAL' : 'PENDING SEAL',
            style: TextStyle(
              fontSize: 6.sp,
              fontWeight: FontWeight.bold,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 5.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 7.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
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

class BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.fill;
    
    // Draw vertical bars of varying widths
    double currentX = 0;
    final widths = [1, 2, 1, 3, 1, 2, 4, 1, 2, 1, 3, 2, 1, 1, 4, 2, 1, 2, 3, 1, 2, 1, 4, 1, 2, 3, 1, 1, 2, 1];
    for (int i = 0; i < widths.length; i++) {
      double w = widths[i] * 1.2;
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(currentX, 0, w, size.height), paint);
      }
      currentX += w + 1;
      if (currentX >= size.width) break;
    }
  }

  @override
  bool shouldRepaint(BarcodePainter oldDelegate) => false;
}
