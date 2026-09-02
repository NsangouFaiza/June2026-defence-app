import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/campaign_repository.dart';
import '../../../../data/models/campaign_model.dart';
import '../../../../widgets/lifelink_app_bar.dart';

class CampaignDetailsScreen extends ConsumerStatefulWidget {

  final int campaignId;

  const CampaignDetailsScreen({super.key, required this.campaignId});

  @override
  ConsumerState<CampaignDetailsScreen> createState() => _CampaignDetailsScreenState();
}

class _CampaignDetailsScreenState extends ConsumerState<CampaignDetailsScreen> {
  bool _isLoading = false;
  late Future<CampaignModel> _campaignFuture;

  @override
  void initState() {
    super.initState();
    _loadCampaign();
  }

  void _loadCampaign() {
    _campaignFuture = ref.read(campaignRepositoryProvider).getCampaignById(widget.campaignId);
  }

  Future<void> _toggleRegister(CampaignModel campaign) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(campaignRepositoryProvider);
      if (campaign.isRegistered) {
        await repo.unregisterFromCampaign(campaign.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('RSVP cancelled successfully.'), backgroundColor: Colors.orange),
          );
        }
      } else {
        await repo.registerForCampaign(campaign.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully registered RSVP for this campaign!'), backgroundColor: AppTheme.success),
          );
        }
      }
      setState(() {
        _loadCampaign();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getDeadlineCountdown(DateTime? deadline) {
    if (deadline == null) return 'No registration deadline set';
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) {
      return 'Registration deadline has passed';
    }
    if (diff.inDays > 0) {
      return 'Registration ends in ${diff.inDays} days ${diff.inHours % 24} hours';
    }
    if (diff.inHours > 0) {
      return 'Registration ends in ${diff.inHours} hours ${diff.inMinutes % 60} minutes';
    }
    return 'Registration ends in ${diff.inMinutes} minutes';
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      appBar: LifeLinkAppBar(
        title: localization.translate('campaign_details'),
      ),

      body: FutureBuilder<CampaignModel>(
        future: _campaignFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final campaign = snapshot.data!;
          final bool isPastDeadline = campaign.registrationDeadline != null &&
              DateTime.now().isAfter(campaign.registrationDeadline!);

          return Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 16.h, bottom: 100.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20.r),
                      child: Container(
                        height: 180.h,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getCampaignTypeColor(campaign.category),
                              _getCampaignTypeColor(campaign.category).withOpacity(0.6),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Icon(Icons.campaign, size: 100.w, color: Colors.white.withOpacity(0.2)),
                            ),
                            Positioned(
                              top: 16.h,
                              left: 16.w,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Text(
                                  campaign.category,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: _getCampaignTypeColor(campaign.category),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Title
                    Text(
                      campaign.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (campaign.subtitle.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        campaign.subtitle,
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ],
                    SizedBox(height: 12.h),

                    // Priority / Countdown Bar
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 18.w, color: AppTheme.primaryColor),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              _getDeadlineCountdown(campaign.registrationDeadline),
                              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: campaign.priority.toUpperCase() == 'EMERGENCY' 
                                  ? AppTheme.error 
                                  : campaign.priority.toUpperCase() == 'URGENT' ? AppTheme.warning : Colors.grey,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              campaign.priority.toUpperCase(),
                              style: TextStyle(fontSize: 8.sp, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Description Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localization.translate('description'),
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              campaign.description,
                              style: TextStyle(fontSize: 13.sp, height: 1.4, color: AppTheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Target Blood groups Card
                    if (campaign.targetBloodGroupsList.isNotEmpty) ...[
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Needed Blood Groups',
                                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                              SizedBox(height: 10.h),
                              Wrap(
                                spacing: 8.w,
                                children: campaign.targetBloodGroupsList.map((bg) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      bg,
                                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // GPS locator component
                    Text(
                      'Campaign Location & GPS Route',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                    ),
                    SizedBox(height: 8.h),
                    _buildMapWidget(campaign),
                    SizedBox(height: 16.h),

                    // Date & timing Details Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date & Time Schedule',
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                            const Divider(height: 24),
                            _buildTimingRow(
                              Icons.calendar_today_outlined,
                              'Campaign Period',
                              '${DateFormat('MMMM dd, yyyy').format(campaign.startDate)} to ${DateFormat('MMMM dd, yyyy').format(campaign.endDate)}',
                            ),
                            _buildTimingRow(
                              Icons.access_time_outlined,
                              'Daily Timings',
                              '${campaign.eventStartTime ?? "08:00"} - ${campaign.eventEndTime ?? "17:00"}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Instructions & Benefits Info
                    if ((campaign.benefitsRewards != null && campaign.benefitsRewards!.isNotEmpty) ||
                        (campaign.participationInstructions != null && campaign.participationInstructions!.isNotEmpty)) ...[
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instructions & Rewards',
                                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                              const Divider(height: 20),
                              if (campaign.participationInstructions != null && campaign.participationInstructions!.isNotEmpty) ...[
                                Text('Donor Instructions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp)),
                                SizedBox(height: 4.h),
                                Text(campaign.participationInstructions!, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade800)),
                                SizedBox(height: 12.h),
                              ],
                              if (campaign.benefitsRewards != null && campaign.benefitsRewards!.isNotEmpty) ...[
                                Text('Rewards & Benefits:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp)),
                                SizedBox(height: 4.h),
                                Text(campaign.benefitsRewards!, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade800)),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // Required documents Checklist Card
                    if (campaign.requiredDocumentsList.isNotEmpty) ...[
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Required Documents Checklist',
                                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                              const Divider(height: 20),
                              ...campaign.requiredDocumentsList.map((doc) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4.h),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 18),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(doc, style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade800)),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // Contacts Card
                    if (campaign.contactInfo != null && campaign.contactInfo!.isNotEmpty) ...[
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contact & Notes',
                                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                              const Divider(height: 20),
                              Text('Organizer Contacts:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp)),
                              SizedBox(height: 4.h),
                              Text(campaign.contactInfo!, style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade800)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // Hashtags
                    if (campaign.hashtagsList.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Wrap(
                          spacing: 8.w,
                          children: campaign.hashtagsList.map((tag) {
                            return Text(
                              tag.startsWith('#') ? tag : '#$tag',
                              style: TextStyle(color: Colors.blue[800], fontSize: 12.sp, fontWeight: FontWeight.w600),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Sticky RSVP Trigger Button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              campaign.isRegistered ? 'Registered RSVP' : 'Not Registered',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: campaign.isRegistered ? AppTheme.success : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${campaign.participantsCount ?? 0} donors',
                              style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: isPastDeadline ? null : () => _toggleRegister(campaign),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: campaign.isRegistered ? Colors.orange[850] : AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                            child: Text(
                              isPastDeadline 
                                  ? 'RSVP Closed' 
                                  : campaign.isRegistered ? 'Cancel RSVP' : 'Register RSVP Now',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.15),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapWidget(CampaignModel campaign) {
    final hasCoords = campaign.latitude != null && campaign.longitude != null;
    return Container(
      height: 150.h,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Opacity(
                opacity: 0.8,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue.shade100, Colors.green.shade50, Colors.blue.shade50],
                    ),
                  ),
                  child: GridPaper(
                    color: Colors.blue.withOpacity(0.05),
                    divisions: 1,
                    subdivisions: 1,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_pin, size: 36.w, color: AppTheme.error),
                  SizedBox(height: 6.h),
                  Text(
                    campaign.location ?? 'No location address set',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.black),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasCoords) ...[
                    Text(
                      'GPS: ${campaign.latitude!.toStringAsFixed(4)}, ${campaign.longitude!.toStringAsFixed(4)}',
                      style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade700),
                    ),
                    SizedBox(height: 6.h),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue[800],
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.navigation, size: 14),
                      label: const Text('Open in Google Maps', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${campaign.latitude},${campaign.longitude}');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingRow(IconData icon, String title, String val) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.w, color: AppTheme.primaryColor),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500)),
                SizedBox(height: 2.h),
                Text(val, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCampaignTypeColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'EMERGENCY BLOOD DRIVE':
      case 'EMERGENCY_APPEAL':
        return AppTheme.error;
      case 'AWARENESS':
      case 'DONATION_AWARENESS':
      case 'HEALTH_EDUCATION':
        return AppTheme.success;
      case 'MOBILE COLLECTION':
      case 'MOBILE_COLLECTION':
        return AppTheme.primaryColor;
      case 'HOSPITAL EVENT':
      case 'HOSPITAL_EVENT':
      case 'COMMUNITY_EVENT':
        return AppTheme.warning;
      default:
        return Colors.teal;
    }
  }
}
