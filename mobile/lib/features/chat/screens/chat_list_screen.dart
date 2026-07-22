import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/models/conversation_model.dart';
import '../../../../data/models/contact_model.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Conversations State
  List<ConversationModel> _conversations = [];
  bool _isLoadingConversations = true;

  // Contact Lists State
  List<ContactModel> _donorContacts = [];
  bool _isLoadingDonors = true;
  String _donorSearch = '';

  List<ContactModel> _patientContacts = [];
  bool _isLoadingPatients = true;
  String _patientSearch = '';

  List<ContactModel> _staffContacts = [];
  bool _isLoadingStaff = true;
  String _staffSearch = '';

  final TextEditingController _donorSearchCtrl = TextEditingController();
  final TextEditingController _patientSearchCtrl = TextEditingController();
  final TextEditingController _staffSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _donorSearchCtrl.dispose();
    _patientSearchCtrl.dispose();
    _staffSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    _loadConversations();
    _loadDonorContacts();
    _loadPatientContacts();
    _loadStaffContacts();
  }

  Future<void> _loadConversations() async {
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final conversations = await messageRepo.getConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoadingConversations = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingConversations = false);
      }
    }
  }

  Future<void> _loadDonorContacts() async {
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final contacts = await messageRepo.getDonorContacts();
      if (mounted) {
        setState(() {
          _donorContacts = contacts;
          _isLoadingDonors = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingDonors = false);
      }
    }
  }

  Future<void> _loadPatientContacts() async {
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final contacts = await messageRepo.getPatientContacts();
      if (mounted) {
        setState(() {
          _patientContacts = contacts;
          _isLoadingPatients = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPatients = false);
      }
    }
  }

  Future<void> _loadStaffContacts() async {
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final contacts = await messageRepo.getStaffContacts();
      if (mounted) {
        setState(() {
          _staffContacts = contacts;
          _isLoadingStaff = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStaff = false);
      }
    }
  }

  void _openChatWithUser(int otherUserId) async {
    await Navigator.of(context).pushNamed(
      '/chat',
      arguments: {
        'otherUserId': otherUserId,
      },
    );
    _loadAllData();
  }

  Color _getBloodGroupColor(String? bloodGroup) {
    if (bloodGroup == null) return Colors.grey;
    switch (bloodGroup.toUpperCase()) {
      case 'A+':
      case 'A-':
        return const Color(0xFFE53935);
      case 'B+':
      case 'B-':
        return const Color(0xFF1E88E5);
      case 'AB+':
      case 'AB-':
        return const Color(0xFF8E24AA);
      case 'O+':
      case 'O-':
        return const Color(0xFF43A047);
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final myId = currentUserAsync.value?.id ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Direct Chat'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoadingConversations = true;
                _isLoadingDonors = true;
                _isLoadingPatients = true;
                _isLoadingStaff = true;
              });
              _loadAllData();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontSize: 13.sp),
          tabs: const [
            Tab(
              icon: Icon(Icons.chat_bubble_outline),
              text: 'Ongoing',
            ),
            Tab(
              icon: Icon(Icons.volunteer_activism_outlined),
              text: 'Contact Donor',
            ),
            Tab(
              icon: Icon(Icons.healing_outlined),
              text: 'Contact Patient',
            ),
            Tab(
              icon: Icon(Icons.medical_services_outlined),
              text: 'Contact Staff',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOngoingConversationsTab(myId),
          _buildContactDonorsTab(),
          _buildContactPatientsTab(),
          _buildContactStaffTab(),
        ],
      ),
    );
  }

  // --- TAB 1: ONGOING CONVERSATIONS ---
  Widget _buildOngoingConversationsTab(int myId) {
    if (_isLoadingConversations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 72.w,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16.h),
              Text(
                'No ongoing conversations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Start a new direct chat with a Donor, Patient, or Hospital Staff member using the tabs above.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Wrap(
                spacing: 10.w,
                runSpacing: 10.h,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.volunteer_activism, size: 18),
                    label: const Text('Contact Donors'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _tabController.animateTo(2),
                    icon: const Icon(Icons.healing, size: 18),
                    label: const Text('Contact Patients'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _tabController.animateTo(3),
                    icon: const Icon(Icons.medical_services, size: 18),
                    label: const Text('Contact Staff'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          final otherParticipantName = conversation.getOtherParticipant(myId);
          final otherParticipantId = conversation.getOtherParticipantId(myId);
          final lastMsg = conversation.lastMessage;
          final lastMsgContent = lastMsg?.content ?? 'No messages yet';

          String formattedTime = '';
          if (lastMsg != null) {
            final time = lastMsg.createdAt;
            formattedTime =
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          }

          final isUnread =
              lastMsg != null && !lastMsg.isRead && lastMsg.senderId != myId;

          return Card(
            elevation: 0.5,
            margin: EdgeInsets.only(bottom: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: InkWell(
              onTap: () async {
                await Navigator.of(context).pushNamed(
                  '/chat',
                  arguments: {
                    'conversationId': conversation.id,
                    'otherUserId': otherParticipantId,
                  },
                );
                _loadConversations();
              },
              borderRadius: BorderRadius.circular(16.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26.r,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      child: Text(
                        otherParticipantName.isNotEmpty
                            ? otherParticipantName.substring(0, 1).toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  otherParticipantName,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMsgContent,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: isUnread
                                        ? Colors.black87
                                        : Colors.grey[600],
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 10.w,
                                  height: 10.w,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
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
          );
        },
      ),
    );
  }

  // --- TAB 2: CONTACT DONORS ---
  Widget _buildContactDonorsTab() {
    if (_isLoadingDonors) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredDonors = _donorContacts.where((donor) {
      if (_donorSearch.isEmpty) return true;
      final q = _donorSearch.toLowerCase();
      return donor.fullName.toLowerCase().contains(q) ||
          (donor.bloodGroup ?? '').toLowerCase().contains(q) ||
          (donor.city ?? '').toLowerCase().contains(q) ||
          (donor.region ?? '').toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 6.h),
          child: TextField(
            controller: _donorSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search donors by name, blood group, city...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _donorSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _donorSearchCtrl.clear();
                        setState(() => _donorSearch = '');
                      },
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            onChanged: (val) => setState(() => _donorSearch = val),
          ),
        ),
        // Donors List
        Expanded(
          child: filteredDonors.isEmpty
              ? Center(
                  child: Text(
                    _donorSearch.isEmpty
                        ? 'No other registered donors found.'
                        : 'No donors match your search.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDonorContacts,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    itemCount: filteredDonors.length,
                    itemBuilder: (context, index) {
                      final donor = filteredDonors[index];
                      final bg = donor.bloodGroup ?? 'N/A';
                      final location = [donor.city, donor.region]
                          .where((e) => e != null && e.isNotEmpty)
                          .join(', ');

                      return Card(
                        elevation: 0.5,
                        margin: EdgeInsets.only(bottom: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(12.w),
                          child: Row(
                            children: [
                              // Avatar / Blood Badge
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 26.r,
                                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                    child: Text(
                                      donor.fullName.isNotEmpty
                                          ? donor.fullName.substring(0, 1).toUpperCase()
                                          : 'D',
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: _getBloodGroupColor(bg),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      bg,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 14.w),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      donor.fullName,
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    if (location.isNotEmpty)
                                      Text(
                                        '📍 $location',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    SizedBox(height: 4.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: donor.isEligible
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        donor.isEligible ? 'Eligible Donor' : 'Resting Period',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                          color: donor.isEligible ? Colors.green[700] : Colors.orange[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Chat Button
                              ElevatedButton.icon(
                                onPressed: () => _openChatWithUser(donor.userId),
                                icon: const Icon(Icons.chat, size: 16),
                                label: const Text('Chat'),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // --- TAB 3: CONTACT PATIENTS ---
  Widget _buildContactPatientsTab() {
    if (_isLoadingPatients) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredPatients = _patientContacts.where((patient) {
      if (_patientSearch.isEmpty) return true;
      final q = _patientSearch.toLowerCase();
      return patient.fullName.toLowerCase().contains(q) ||
          (patient.bloodGroup ?? '').toLowerCase().contains(q) ||
          (patient.medicalConditions ?? '').toLowerCase().contains(q) ||
          (patient.city ?? '').toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 6.h),
          child: TextField(
            controller: _patientSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search patients by name, blood group, condition...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _patientSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _patientSearchCtrl.clear();
                        setState(() => _patientSearch = '');
                      },
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            onChanged: (val) => setState(() => _patientSearch = val),
          ),
        ),
        // Patients List
        Expanded(
          child: filteredPatients.isEmpty
              ? Center(
                  child: Text(
                    _patientSearch.isEmpty
                        ? 'No patients available for contact.'
                        : 'No patients match your search.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPatientContacts,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    itemCount: filteredPatients.length,
                    itemBuilder: (context, index) {
                      final patient = filteredPatients[index];
                      final bg = patient.bloodGroup ?? 'N/A';
                      final location = [patient.city, patient.region]
                          .where((e) => e != null && e.isNotEmpty)
                          .join(', ');

                      return Card(
                        elevation: 0.5,
                        margin: EdgeInsets.only(bottom: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(12.w),
                          child: Row(
                            children: [
                              // Avatar / Blood Badge
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 26.r,
                                    backgroundColor: Colors.teal.withOpacity(0.1),
                                    child: Text(
                                      patient.fullName.isNotEmpty
                                          ? patient.fullName.substring(0, 1).toUpperCase()
                                          : 'P',
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal[800],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: _getBloodGroupColor(bg),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      bg,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 14.w),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patient.fullName,
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    if (location.isNotEmpty)
                                      Text(
                                        '📍 $location',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      children: [
                                        if (patient.activeRequestsCount > 0)
                                          Container(
                                            margin: EdgeInsets.only(right: 6.w),
                                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6.r),
                                            ),
                                            child: Text(
                                              '🩸 ${patient.activeRequestsCount} Active Request(s)',
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.red[700],
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6.r),
                                            ),
                                            child: Text(
                                              'Patient Contact',
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Chat Button
                              ElevatedButton.icon(
                                onPressed: () => _openChatWithUser(patient.userId),
                                icon: const Icon(Icons.chat, size: 16),
                                label: const Text('Chat'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // --- TAB 4: CONTACT STAFF ---
  Widget _buildContactStaffTab() {
    if (_isLoadingStaff) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredStaff = _staffContacts.where((staff) {
      if (_staffSearch.isEmpty) return true;
      final q = _staffSearch.toLowerCase();
      return staff.fullName.toLowerCase().contains(q) ||
          (staff.hospitalName ?? '').toLowerCase().contains(q) ||
          (staff.position ?? '').toLowerCase().contains(q) ||
          staff.role.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 6.h),
          child: TextField(
            controller: _staffSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search staff by name, hospital, position...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _staffSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _staffSearchCtrl.clear();
                        setState(() => _staffSearch = '');
                      },
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            onChanged: (val) => setState(() => _staffSearch = val),
          ),
        ),
        // Staff List
        Expanded(
          child: filteredStaff.isEmpty
              ? Center(
                  child: Text(
                    _staffSearch.isEmpty
                        ? 'No staff members currently listed.'
                        : 'No staff match your search.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStaffContacts,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    itemCount: filteredStaff.length,
                    itemBuilder: (context, index) {
                      final staff = filteredStaff[index];
                      final hospital = staff.hospitalName ?? 'LifeLink Support';

                      return Card(
                        elevation: 0.5,
                        margin: EdgeInsets.only(bottom: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(12.w),
                          child: Row(
                            children: [
                              // Avatar / Icon
                              CircleAvatar(
                                radius: 26.r,
                                backgroundColor: Colors.indigo.withOpacity(0.1),
                                child: Icon(
                                  Icons.local_hospital_rounded,
                                  color: Colors.indigo,
                                  size: 24.w,
                                ),
                              ),
                              SizedBox(width: 14.w),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staff.fullName,
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      '🏥 $hospital',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        staff.displayRole,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.indigo[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Chat Button
                              ElevatedButton.icon(
                                onPressed: () => _openChatWithUser(staff.userId),
                                icon: const Icon(Icons.support_agent, size: 16),
                                label: const Text('Contact'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
