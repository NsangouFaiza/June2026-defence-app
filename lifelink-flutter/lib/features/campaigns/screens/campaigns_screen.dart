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
import '../../../../data/models/donor_model.dart';
import '../../../../data/repositories/donor_repository.dart';
import '../../../../data/services/api_service.dart';
import 'campaign_details_screen.dart';

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  final Set<int> _registeringIds = {};
  bool _isActionLoading = false;

  void _refresh() {
    setState(() {});
  }

  Future<void> _duplicateCampaign(int id) async {
    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(campaignRepositoryProvider);
      await repo.duplicateCampaign(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign duplicated successfully as Draft.'), backgroundColor: AppTheme.success),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _publishCampaign(int id) async {
    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(campaignRepositoryProvider);
      await repo.publishCampaign(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign published successfully to target audience!'), backgroundColor: AppTheme.success),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _unpublishCampaign(int id) async {
    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(campaignRepositoryProvider);
      await repo.unpublishCampaign(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign unpublished. Status set back to Draft.'), backgroundColor: AppTheme.success),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _archiveCampaign(int id) async {
    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(campaignRepositoryProvider);
      await repo.archiveCampaign(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign archived.'), backgroundColor: AppTheme.success),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _restoreCampaign(int id) async {
    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(campaignRepositoryProvider);
      await repo.restoreCampaign(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign restored to Published status.'), backgroundColor: AppTheme.success),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _deleteCampaign(int id) async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(campaignRepositoryProvider).deleteCampaign(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign deleted successfully.'), backgroundColor: AppTheme.success),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);
    final campaignRepo = ref.watch(campaignRepositoryProvider);
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        final isStaff = user != null &&
            (user.role == 'hospital_staff' ||
                user.role == 'blood_bank_staff' ||
                user.role == 'system_admin');

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(localization.translate('campaigns')),
              actions: [
                if (!isStaff)
                  IconButton(
                    icon: const Icon(Icons.map_outlined),
                    tooltip: 'Nearby Blood Banks',
                    onPressed: () => Navigator.of(context).pushNamed('/hospital-locator'),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                indicatorColor: Colors.white,
                indicatorWeight: 3.w,
                labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                unselectedLabelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.normal),
                tabs: isStaff
                    ? const [
                        Tab(text: 'Active Campaigns'),
                        Tab(text: 'Drafts & Scheduled'),
                        Tab(text: 'Campaign History'),
                      ]
                    : const [
                        Tab(text: 'Active Drives'),
                        Tab(text: 'My Registered'),
                        Tab(text: 'All Campaigns'),
                      ],
              ),
            ),
            floatingActionButton: isStaff
                ? FloatingActionButton.extended(
                    onPressed: () => _openCampaignFormSheet(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('New Campaign'),
                  )
                : null,
            body: Stack(
              children: [
                TabBarView(
                  children: isStaff
                      ? [
                          _buildCampaignsTab(context, campaignRepo, localization, mode: 'active', isStaff: true),
                          _buildCampaignsTab(context, campaignRepo, localization, mode: 'drafts', isStaff: true),
                          _buildCampaignsTab(context, campaignRepo, localization, mode: 'history', isStaff: true),
                        ]
                      : [
                          _buildCampaignsTab(context, campaignRepo, localization, mode: 'active', isStaff: false),
                          _buildCampaignsTab(context, campaignRepo, localization, mode: 'my', isStaff: false),
                          _buildCampaignsTab(context, campaignRepo, localization, mode: 'all', isStaff: false),
                        ],
                ),
                if (_isActionLoading)
                  Container(
                    color: Colors.black.withOpacity(0.2),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildCampaignsTab(
    BuildContext context,
    CampaignRepository campaignRepo,
    LocalizationService localization, {
    required String mode,
    required bool isStaff,
  }) {
    return FutureBuilder<List<CampaignModel>>(
      future: mode == 'my' ? campaignRepo.getMyCampaigns() : campaignRepo.getCampaigns(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var campaigns = snapshot.data ?? [];
        if (isStaff) {
          if (mode == 'active') {
            campaigns = campaigns.where((c) => c.status == 'PUBLISHED' || c.status == 'ONGOING').toList();
          } else if (mode == 'drafts') {
            campaigns = campaigns.where((c) => c.status == 'DRAFT' || c.status == 'SCHEDULED').toList();
          } else if (mode == 'history') {
            campaigns = campaigns.where((c) => c.status == 'COMPLETED' || c.status == 'CANCELLED' || c.status == 'ARCHIVED' || c.status == 'EXPIRED').toList();
          }
        } else {
          if (mode == 'active') {
            campaigns = campaigns.where((c) => c.status == 'PUBLISHED' || c.status == 'ONGOING').toList();
          }
        }

        if (campaigns.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 64.w, color: Colors.grey),
                  SizedBox(height: 16.h),
                  Text(
                    mode == 'my'
                        ? 'No registered campaigns yet.'
                        : isStaff
                            ? 'No campaigns found in this section.'
                            : localization.translate('no_campaigns'),
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 16.h, bottom: 80.h),
          itemCount: campaigns.length,
          itemBuilder: (context, index) {
            final campaign = campaigns[index];
            final bool isRegistered = campaign.isRegistered || mode == 'my';

            return Card(
              margin: EdgeInsets.only(bottom: 16.h),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  // Increments views on entry
                  campaignRepo.incrementCampaignViews(campaign.id);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => CampaignDetailsScreen(campaignId: campaign.id),
                    ),
                  ).then((_) => _refresh());
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 110.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getCampaignTypeColor(campaign.category),
                            _getCampaignTypeColor(campaign.category).withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Icon(
                              Icons.campaign,
                              size: 80.w,
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          Positioned(
                            top: 12.h,
                            left: 12.w,
                            right: 12.w,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Text(
                                    campaign.category,
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      color: _getCampaignTypeColor(campaign.category),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(campaign.priority),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Text(
                                    campaign.priority.toUpperCase(),
                                    style: TextStyle(fontSize: 9.sp, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 10.h,
                            left: 12.w,
                            child: Text(
                              'Status: ${campaign.status}',
                              style: TextStyle(fontSize: 10.sp, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            campaign.title,
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                          ),
                          if (campaign.subtitle.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              campaign.subtitle,
                              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                            ),
                          ],
                          SizedBox(height: 8.h),
                          Text(
                            campaign.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.event, size: 14, color: Colors.grey),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: Text(
                                  '${DateFormat('yyyy-MM-dd').format(campaign.startDate)} to ${DateFormat('yyyy-MM-dd').format(campaign.endDate)}',
                                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (campaign.location != null && campaign.location!.isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Text(
                                    campaign.location!,
                                    style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (isStaff) ...[
                            SizedBox(height: 10.h),
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatMiniCol('Views', '${campaign.viewsCount}'),
                                  _buildStatMiniCol('RSVPs', '${campaign.participantsCount}'),
                                  _buildStatMiniCol('Attended', '${campaign.attendedCount}'),
                                  _buildStatMiniCol('Donors Needed', '${campaign.expectedDonors ?? "-"}'),
                                ],
                              ),
                            ),
                          ],
                          SizedBox(height: 12.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!isStaff) ...[
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (ctx) => CampaignDetailsScreen(campaignId: campaign.id),
                                      ),
                                    ).then((_) => _refresh());
                                  },
                                  icon: const Icon(Icons.info_outline, size: 16),
                                  label: Text(isRegistered ? 'View RSVP status' : 'View Details & RSVP'),
                                ),
                              ] else ...[
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: 'Duplicate',
                                  onPressed: () => _duplicateCampaign(campaign.id),
                                ),
                                if (campaign.status == 'DRAFT' || campaign.status == 'SCHEDULED') ...[
                                  TextButton.icon(
                                    onPressed: () => _openCampaignFormSheet(context, campaign),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Edit'),
                                  ),
                                  SizedBox(width: 4.w),
                                  ElevatedButton.icon(
                                    onPressed: () => _publishCampaign(campaign.id),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                                    icon: const Icon(Icons.publish, size: 16),
                                    label: const Text('Publish'),
                                  ),
                                  SizedBox(width: 4.w),
                                  IconButton(
                                    icon: const Icon(Icons.delete_forever, color: AppTheme.error),
                                    tooltip: 'Delete',
                                    onPressed: () => _confirmDelete(campaign.id),
                                  ),
                                ] else if (campaign.status == 'PUBLISHED' || campaign.status == 'ONGOING') ...[
                                  TextButton.icon(
                                    onPressed: () => _openParticipantListSheet(context, campaign),
                                    icon: const Icon(Icons.people_alt_outlined, size: 16),
                                    label: const Text('RSVPs'),
                                  ),
                                  SizedBox(width: 4.w),
                                  TextButton.icon(
                                    onPressed: () => _openStatsDialog(context, campaign),
                                    icon: const Icon(Icons.bar_chart_rounded, size: 16),
                                    label: const Text('Stats'),
                                  ),
                                  SizedBox(width: 4.w),
                                  PopupMenuButton<String>(
                                    onSelected: (val) {
                                      if (val == 'unpublish') {
                                        _unpublishCampaign(campaign.id);
                                      } else if (val == 'archive') {
                                        _archiveCampaign(campaign.id);
                                      } else if (val == 'edit') {
                                        _openCampaignFormSheet(context, campaign);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Edit details')),
                                      const PopupMenuItem(value: 'unpublish', child: Text('Unpublish')),
                                      const PopupMenuItem(value: 'archive', child: Text('Archive')),
                                    ],
                                  ),
                                ] else ...[
                                  ElevatedButton.icon(
                                    onPressed: () => _restoreCampaign(campaign.id),
                                    icon: const Icon(Icons.restore_rounded, size: 16),
                                    label: const Text('Restore'),
                                  ),
                                  SizedBox(width: 8.w),
                                  IconButton(
                                    icon: const Icon(Icons.delete_forever, color: AppTheme.error),
                                    tooltip: 'Delete permanently',
                                    onPressed: () => _confirmDelete(campaign.id),
                                  ),
                                ]
                              ],
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildStatMiniCol(String title, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        SizedBox(height: 2.h),
        Text(title, style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade600)),
      ],
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Campaign'),
        content: const Text('Are you sure you want to permanently delete this campaign? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCampaign(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
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

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'EMERGENCY':
        return AppTheme.error;
      case 'URGENT':
        return AppTheme.warning;
      default:
        return Colors.grey.shade600;
    }
  }

  // CREATE / EDIT FULL FEATURED SHEET
  void _openCampaignFormSheet(BuildContext context, CampaignModel? campaign) {
    final titleController = TextEditingController(text: campaign?.title ?? '');
    final subtitleController = TextEditingController(text: campaign?.subtitle ?? '');
    final descController = TextEditingController(text: campaign?.description ?? '');
    final locController = TextEditingController(text: campaign?.location ?? '');
    final latController = TextEditingController(text: campaign?.latitude?.toString() ?? '');
    final lngController = TextEditingController(text: campaign?.longitude?.toString() ?? '');
    
    String selectedCategory = campaign?.category ?? 'Blood Donation';
    String selectedPriority = campaign?.priority ?? 'Normal';
    final cityController = TextEditingController(text: campaign?.city ?? '');
    final regionController = TextEditingController(text: campaign?.region ?? '');
    final radiusController = TextEditingController(text: campaign?.targetRadius?.toString() ?? '');
    final contactController = TextEditingController(text: campaign?.contactInfo ?? '');
    final notesController = TextEditingController(text: campaign?.organizerNotes ?? '');
    final instructionsController = TextEditingController(text: campaign?.participationInstructions ?? '');
    final benefitsController = TextEditingController(text: campaign?.benefitsRewards ?? '');
    final documentsController = TextEditingController(text: campaign?.requiredDocuments ?? '');
    final hashtagsController = TextEditingController(text: campaign?.hashtags ?? '');
    String genderRestriction = campaign?.genderRestriction ?? 'None';
    String visibilitySettings = campaign?.visibilitySettings ?? 'Public';
    
    final targetCityController = TextEditingController(text: campaign?.targetLocation ?? '');
    String targetEligibility = campaign?.targetEligibility ?? 'Any';
    final ageMinController = TextEditingController(text: campaign?.targetAgeMin?.toString() ?? '18');
    final ageMaxController = TextEditingController(text: campaign?.targetAgeMax?.toString() ?? '65');
    final expectedDonorsController = TextEditingController(text: campaign?.expectedDonors?.toString() ?? '');
    final eligibilityNotesController = TextEditingController(text: campaign?.eligibilityCriteria ?? '');

    DateTime startDate = campaign?.startDate ?? DateTime.now().add(const Duration(days: 1));
    DateTime endDate = campaign?.endDate ?? DateTime.now().add(const Duration(days: 2));
    DateTime deadlineDate = campaign?.registrationDeadline ?? startDate.subtract(const Duration(hours: 12));
    
    String startTime = campaign?.eventStartTime ?? '08:00';
    String endTime = campaign?.eventEndTime ?? '17:00';
    
    DateTime? scheduledDelivery = campaign?.scheduledDelivery;

    final List<String> bloodGroupOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    List<String> selectedBloodGroups = campaign?.targetBloodGroupsList ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16.w, right: 16.w, top: 16.h),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        campaign == null ? 'Create Blood Campaign' : 'Edit Blood Campaign',
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(),
                      SizedBox(height: 8.h),
                      
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedCategory,
                        decoration: const InputDecoration(labelText: 'Campaign Category', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Blood Donation', child: Text('Blood Donation')),
                          DropdownMenuItem(value: 'Emergency Blood Drive', child: Text('Emergency Blood Drive')),
                          DropdownMenuItem(value: 'Awareness', child: Text('Awareness Campaign')),
                          DropdownMenuItem(value: 'Mobile Collection', child: Text('Mobile Collection')),
                          DropdownMenuItem(value: 'Hospital Event', child: Text('Hospital Event')),
                        ],
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedCategory = val);
                        },
                      ),
                      SizedBox(height: 12.h),
                      
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Campaign Title', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: subtitleController,
                        decoration: const InputDecoration(labelText: 'Subtitle / Slogan', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Detailed Description', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12.h),

                      Text('Event Date & Timing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: AppTheme.primaryColor)),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) {
                                  setSheetState(() {
                                    startDate = d;
                                    if (endDate.isBefore(startDate)) {
                                      endDate = startDate.add(const Duration(days: 1));
                                    }
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_month),
                              label: Text('Start Date: ${DateFormat('yyyy-MM-dd').format(startDate)}', style: TextStyle(fontSize: 10.sp)),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setSheetState(() => endDate = d);
                              },
                              icon: const Icon(Icons.calendar_month),
                              label: Text('End Date: ${DateFormat('yyyy-MM-dd').format(endDate)}', style: TextStyle(fontSize: 10.sp)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: deadlineDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: startDate,
                                );
                                if (d != null) setSheetState(() => deadlineDate = d);
                              },
                              icon: const Icon(Icons.lock_clock),
                              label: Text('RSVP Deadline: ${DateFormat('yyyy-MM-dd').format(deadlineDate)}', style: TextStyle(fontSize: 9.sp)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: startTime),
                              decoration: const InputDecoration(labelText: 'Start Time (e.g. 08:00)', border: OutlineInputBorder()),
                              onChanged: (v) => startTime = v,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: endTime),
                              decoration: const InputDecoration(labelText: 'End Time (e.g. 17:00)', border: OutlineInputBorder()),
                              onChanged: (v) => endTime = v,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      Text('Event Location Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: AppTheme.primaryColor)),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: locController,
                        decoration: const InputDecoration(labelText: 'Location / Hall / Center Name', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cityController,
                              decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: regionController,
                              decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: latController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Latitude (GPS)', border: OutlineInputBorder()),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: lngController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Longitude (GPS)', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      Text('Target Filters & Eligibility Criteria', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: AppTheme.primaryColor)),
                      SizedBox(height: 8.h),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedPriority,
                        decoration: const InputDecoration(labelText: 'Campaign Priority', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Normal', child: Text('Normal Appeal')),
                          DropdownMenuItem(value: 'Urgent', child: Text('Urgent Need')),
                          DropdownMenuItem(value: 'Emergency', child: Text('Critical Emergency appeal')),
                        ],
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedPriority = val);
                        },
                      ),
                      SizedBox(height: 12.h),
                      Text('Target Blood Groups (select single or multiple):', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 4.h,
                        children: bloodGroupOptions.map((bg) {
                          final isSelected = selectedBloodGroups.contains(bg);
                          return FilterChip(
                            label: Text(bg),
                            selected: isSelected,
                            onSelected: (val) {
                              setSheetState(() {
                                if (val) {
                                  selectedBloodGroups.add(bg);
                                } else {
                                  selectedBloodGroups.remove(bg);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: targetEligibility,
                              decoration: const InputDecoration(labelText: 'Target Eligibility', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'Any', child: Text('Any Eligibility')),
                                DropdownMenuItem(value: 'eligible', child: Text('Eligible Donors Only')),
                                DropdownMenuItem(value: 'ineligible', child: Text('Restricted/New Donors')),
                              ],
                              onChanged: (val) {
                                if (val != null) setSheetState(() => targetEligibility = val);
                              },
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: genderRestriction,
                              decoration: const InputDecoration(labelText: 'Gender Restriction', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'None', child: Text('No Gender restriction')),
                                DropdownMenuItem(value: 'M', child: Text('Male Only')),
                                DropdownMenuItem(value: 'F', child: Text('Female Only')),
                              ],
                              onChanged: (val) {
                                if (val != null) setSheetState(() => genderRestriction = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ageMinController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Min Age', border: OutlineInputBorder()),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: ageMaxController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Max Age', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: radiusController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Target Radius (km)', border: OutlineInputBorder()),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: expectedDonorsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Expected Donors Count', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: eligibilityNotesController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Detailed Eligibility Criteria notes', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12.h),

                      Text('Organizer & Benefit Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: AppTheme.primaryColor)),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: contactController,
                        decoration: const InputDecoration(labelText: 'Contact Information (Phone / Email)', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Internal Organizer Notes', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: instructionsController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Instructions for Participants', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: benefitsController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Donor Benefits / Snacks / Rewards', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: documentsController,
                        decoration: const InputDecoration(labelText: 'Required Documents (comma separated)', border: OutlineInputBorder(), hintText: 'e.g. ID card, Health Record book'),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: hashtagsController,
                        decoration: const InputDecoration(labelText: 'Hashtags (comma separated)', border: OutlineInputBorder(), hintText: '#SaveLives, #DonateBlood'),
                      ),
                      SizedBox(height: 12.h),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: visibilitySettings,
                        decoration: const InputDecoration(labelText: 'Campaign Visibility', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Public', child: Text('Public (Visible to All)')),
                          DropdownMenuItem(value: 'Targeted', child: Text('Targeted (Eligible Only)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setSheetState(() => visibilitySettings = val);
                        },
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(hours: 1)),
                                  firstDate: DateTime.now(),
                                  lastDate: startDate,
                                );
                                if (d != null) {
                                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                  if (t != null) {
                                    setSheetState(() {
                                      scheduledDelivery = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                                    });
                                  }
                                }
                              },
                              child: Text(scheduledDelivery == null 
                                  ? 'Schedule Campaign' 
                                  : 'Scheduled: ${DateFormat('yyyy-MM-dd HH:mm').format(scheduledDelivery!)}', style: TextStyle(fontSize: 10.sp)),
                            ),
                          ),
                          if (scheduledDelivery != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.error),
                              onPressed: () => setSheetState(() => scheduledDelivery = null),
                            )
                        ],
                      ),
                      SizedBox(height: 24.h),
                      
                      ElevatedButton(
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty || descController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill Title and Description.')));
                            return;
                          }
                          
                          final statusValue = scheduledDelivery != null ? 'SCHEDULED' : (campaign?.status ?? 'DRAFT');
                          
                          final campaignData = {
                            'title': titleController.text.trim(),
                            'subtitle': subtitleController.text.trim(),
                            'description': descController.text.trim(),
                            'category': selectedCategory,
                            'location': locController.text.trim(),
                            'latitude': double.tryParse(latController.text.trim()),
                            'longitude': double.tryParse(lngController.text.trim()),
                            'start_date': DateFormat('yyyy-MM-dd').format(startDate),
                            'end_date': DateFormat('yyyy-MM-dd').format(endDate),
                            'registration_deadline': DateFormat('yyyy-MM-dd').format(deadlineDate),
                            'event_start_time': startTime,
                            'event_end_time': endTime,
                            'expected_donors': int.tryParse(expectedDonorsController.text.trim()),
                            'campaign_type': 'DONATION_AWARENESS',
                            'priority': selectedPriority,
                            'status': statusValue,
                            'target_blood_group': selectedBloodGroups.isEmpty ? null : selectedBloodGroups.first,
                            'target_blood_groups': selectedBloodGroups.isEmpty ? null : selectedBloodGroups.join(','),
                            'target_location': targetCityController.text.trim().isEmpty ? null : targetCityController.text.trim(),
                            'target_eligibility': targetEligibility == 'Any' ? null : targetEligibility,
                            'target_age_min': int.tryParse(ageMinController.text.trim()),
                            'target_age_max': int.tryParse(ageMaxController.text.trim()),
                            'gender_restriction': genderRestriction,
                            'city': cityController.text.trim(),
                            'region': regionController.text.trim(),
                            'target_radius': double.tryParse(radiusController.text.trim()),
                            'contact_info': contactController.text.trim(),
                            'organizer_notes': notesController.text.trim(),
                            'participation_instructions': instructionsController.text.trim(),
                            'benefits_rewards': benefitsController.text.trim(),
                            'required_documents': documentsController.text.trim(),
                            'hashtags': hashtagsController.text.trim(),
                            'visibility_settings': visibilitySettings,
                            'scheduled_delivery': scheduledDelivery?.toIso8601String(),
                          };

                          Navigator.pop(context);
                          setState(() => _isActionLoading = true);
                          try {
                            final repo = ref.read(campaignRepositoryProvider);
                            if (campaign == null) {
                              await repo.createCampaign(campaignData);
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign draft saved successfully.'), backgroundColor: AppTheme.success));
                            } else {
                              await repo.updateCampaign(campaign.id, campaignData);
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign updated successfully.'), backgroundColor: AppTheme.success));
                            }
                            _refresh();
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                          } finally {
                            if (mounted) setState(() => _isActionLoading = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h), backgroundColor: AppTheme.primaryColor),
                        child: Text(campaign == null ? 'Save Campaign' : 'Save Changes'),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // RSVP PARTICIPANTS LIST SHEET
  void _openParticipantListSheet(BuildContext context, CampaignModel campaign) {
    String searchVal = '';
    String bloodFilter = '';
    String statusFilter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final repo = ref.read(campaignRepositoryProvider);
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16.w, right: 16.w, top: 16.h),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Registrant RSVPs - ${campaign.title}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    SizedBox(height: 8.h),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Search Donor Name', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                      onChanged: (v) {
                        setModalState(() => searchVal = v);
                      },
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Blood Group', contentPadding: EdgeInsets.zero),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('All Groups')),
                              DropdownMenuItem(value: 'A+', child: Text('A+')),
                              DropdownMenuItem(value: 'A-', child: Text('A-')),
                              DropdownMenuItem(value: 'B+', child: Text('B+')),
                              DropdownMenuItem(value: 'B-', child: Text('B-')),
                              DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                              DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                              DropdownMenuItem(value: 'O+', child: Text('O+')),
                              DropdownMenuItem(value: 'O-', child: Text('O-')),
                            ],
                            onChanged: (v) => setModalState(() => bloodFilter = v ?? ''),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Status', contentPadding: EdgeInsets.zero),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('Active RSVPs')),
                              DropdownMenuItem(value: 'REGISTERED', child: Text('Registered')),
                              DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                              DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                              DropdownMenuItem(value: 'ATTENDED', child: Text('Attended')),
                            ],
                            onChanged: (v) => setModalState(() => statusFilter = v ?? ''),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: FutureBuilder<List<CampaignRegistrationModel>>(
                        future: repo.getCampaignParticipants(campaign.id, search: searchVal, bloodGroup: bloodFilter, status: statusFilter),
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snap.hasError) {
                            return Center(child: Text('Error: ${snap.error}'));
                          }
                          final list = snap.data ?? [];
                          if (list.isEmpty) {
                            return const Center(child: Text('No participants found matching criteria.'));
                          }
                          return ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (ctx, i) {
                              final reg = list[i];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: reg.status == 'APPROVED' 
                                        ? AppTheme.success.withOpacity(0.12)
                                        : reg.status == 'ATTENDED' ? Colors.blue.withOpacity(0.12) : Colors.amber.withOpacity(0.12),
                                    child: Text(reg.donorDetails.fullName.substring(0, 1).toUpperCase()),
                                  ),
                                  title: Text(reg.donorDetails.fullName),
                                  subtitle: Text('${reg.donorDetails.bloodGroup ?? "N/A"} | ${reg.status}'),
                                  trailing: Wrap(
                                    spacing: 4.w,
                                    children: [
                                      if (reg.status == 'REGISTERED') ...[
                                        IconButton(
                                          icon: const Icon(Icons.check, color: AppTheme.success),
                                          onPressed: () async {
                                            await repo.approveRegistration(campaign.id, reg.donorId);
                                            setModalState(() {});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: AppTheme.error),
                                          onPressed: () async {
                                            await repo.rejectRegistration(campaign.id, reg.donorId);
                                            setModalState(() {});
                                          },
                                        ),
                                      ],
                                      if (reg.status == 'APPROVED') ...[
                                        ElevatedButton(
                                          onPressed: () async {
                                            final bool? donated = await showDialog<bool>(
                                              context: context,
                                              builder: (dialogCtx) => AlertDialog(
                                                title: const Text('Attendance & Check-in'),
                                                content: const Text('Did the participant successfully donate a unit of blood?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Attended only')),
                                                  ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Successfully Donated')),
                                                ],
                                              ),
                                            );
                                            if (donated != null) {
                                              await repo.checkInParticipant(campaign.id, reg.donorId, donated);
                                              setModalState(() {});
                                            }
                                          },
                                          child: const Text('Check In'),
                                        ),
                                      ],
                                      if (reg.status == 'ATTENDED')
                                        Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 24.w),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final url = Uri.parse('${ApiService.serverBaseUrl}/campaigns/${campaign.id}/export-participants/');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to initiate CSV download.')));
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Export Participants List (CSV)'),
                    ),
                    SizedBox(height: 12.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // STATISTICS DIALOG
  void _openStatsDialog(BuildContext context, CampaignModel campaign) {
    showDialog(
      context: context,
      builder: (ctx) {
        final repo = ref.read(campaignRepositoryProvider);
        return FutureBuilder<Map<String, dynamic>>(
          future: repo.getCampaignStatistics(campaign.id),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const AlertDialog(content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())));
            }
            if (snap.hasError) {
              return AlertDialog(title: const Text('Error'), content: Text('${snap.error}'));
            }
            final stats = snap.data ?? {};
            return AlertDialog(
              title: Text('Performance - ${campaign.title}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatRow('Views / Reach', '${stats['views'] ?? 0}'),
                  _buildStatRow('RSVP Registrations', '${stats['registrations'] ?? 0}'),
                  _buildStatRow('Attendance Count', '${stats['attendance'] ?? 0}'),
                  _buildStatRow('Successful Donations', '${stats['successful_donations'] ?? 0}'),
                  const Divider(),
                  _buildStatRow('RSVP Completion Rate', '${stats['completion_rate'] ?? 0.0}%'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
