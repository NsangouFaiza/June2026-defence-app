import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/repositories/donor_repository.dart';
import '../../../data/models/donor_model.dart';

class DigitalDonorCardScreen extends ConsumerWidget {
  const DigitalDonorCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donorRepo = ref.watch(donorRepositoryProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Digital Donor Card'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: const Text('Failed to load donor card. Make sure your donor profile is completed.'),
              ),
            );
          }

          final donor = snapshot.data!;
          final donorIdCode = donor.donorIdCode;
          final qrData = "LIFELINK-DONOR-ID:${donor.donorIdCode}-${user?.fullName ?? 'Unknown'}";

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your Digital Membership',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4.h),
                Text(
                  'Present this digital card or QR code when checking in for a donation.',
                  style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                
                // GLASSMORPHIC DONOR CARD
                Container(
                  height: 220.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.r),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFE57373),
                        AppTheme.primaryColor,
                        const Color(0xFFC62828),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Chip logo mock
                      Positioned(
                        top: 24.h,
                        left: 24.w,
                        child: Container(
                          width: 45.w,
                          height: 35.h,
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: const Icon(Icons.credit_card, color: Colors.white30),
                        ),
                      ),
                      // Blood Type badge
                      Positioned(
                        top: 24.h,
                        right: 24.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(
                            donor.bloodGroup ?? 'O+',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Card details
                      Positioned(
                        bottom: 24.h,
                        left: 24.w,
                        right: 24.w,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName.toUpperCase() ?? 'DONOR NAME',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DONOR ID',
                                      style: TextStyle(fontSize: 9.sp, color: Colors.white70),
                                    ),
                                    Text(
                                      donorIdCode,
                                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'LEVEL',
                                      style: TextStyle(fontSize: 9.sp, color: Colors.white70),
                                    ),
                                    Text(
                                      donor.level?.toUpperCase() ?? 'BRONZE',
                                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'POINTS',
                                      style: TextStyle(fontSize: 9.sp, color: Colors.white70),
                                    ),
                                    Text(
                                      donor.points.toString(),
                                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Action buttons: Copy & Share Card
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: donorIdCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Donor ID copied to clipboard!')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy ID'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sharing donor card for ${user?.fullName}...'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.share),
                        label: const Text('Share Card'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // QR CODE SCANNER CHECKIN
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      children: [
                        Text(
                          'Hospital Check-In QR',
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 16.h),
                        Container(
                          width: 180.w,
                          height: 180.w,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300, width: 2),
                            borderRadius: BorderRadius.circular(16.r),
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.all(12.w),
                          child: CustomPaint(
                            size: Size(150.w, 150.w),
                            painter: QRCodePainter(qrData),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          donorIdCode,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurfaceVariant,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          );
        },
      ),
    );
  }
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
