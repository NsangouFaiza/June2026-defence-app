import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/appointment_repository.dart';
import '../../../../data/repositories/donor_repository.dart';
import '../../../../data/repositories/notification_repository.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/donor_model.dart';

class ManageAppointmentsScreen extends ConsumerStatefulWidget {
  const ManageAppointmentsScreen({super.key});

  @override
  ConsumerState<ManageAppointmentsScreen> createState() => _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends ConsumerState<ManageAppointmentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppointmentModel> _appointments = [];
  List<DonorModel> _donors = [];
  bool _isLoading = false;

  // Filters for Appointments Tab
  String _selectedStatusFilter = 'ALL';
  DateTime? _selectedDateFilter;
  final TextEditingController _searchController = TextEditingController();

  // Send Notification Form
  DonorModel? _selectedNotificationRecipient;
  final TextEditingController _notifyTitleController = TextEditingController();
  final TextEditingController _notifyBodyController = TextEditingController();
  bool _isSendingNotification = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _notifyTitleController.dispose();
    _notifyBodyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final appRepo = ref.read(appointmentRepositoryProvider);
      final donorRepo = ref.read(donorRepositoryProvider);

      final fetchedApps = await appRepo.getAppointments();
      final fetchedDonors = await donorRepo.getDonors();

      setState(() {
        _appointments = fetchedApps;
        _donors = fetchedDonors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  // Action methods
  Future<void> _confirmApp(int id) async {
    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.confirmAppointment(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment confirmed successfully')));
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _completeApp(int id) async {
    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.completeAppointment(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment marked complete and blood pack logged')));
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _cancelApp(int id) async {
    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.cancelAppointment(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  // Handle scheduling new appointments on behalf of donors
  Future<void> _scheduleAppointment() async {
    if (_donors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No donors registered to schedule.')));
      return;
    }

    DonorModel? selectDonor = _donors.first;
    DateTime selectDate = DateTime.now().add(const Duration(days: 1));
    String selectTimeSlot = '08:00';
    List<String> availableSlots = [];
    bool isSlotsLoading = false;

    // Helper dialog content state updater
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> updateSlots() async {
            setDialogState(() => isSlotsLoading = true);
            try {
              final repo = ref.read(appointmentRepositoryProvider);
              // Safe fallback for hospital ID (usually 1, or resolved if possible)
              final slots = await repo.getAvailableSlots(1, selectDate);
              setDialogState(() {
                availableSlots = slots;
                if (slots.isNotEmpty && !slots.contains(selectTimeSlot)) {
                  selectTimeSlot = slots.first;
                }
                isSlotsLoading = false;
              });
            } catch (_) {
              setDialogState(() {
                availableSlots = ['08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00'];
                isSlotsLoading = false;
              });
            }
          }

          if (availableSlots.isEmpty && !isSlotsLoading) {
            updateSlots();
          }

          return AlertDialog(
            title: const Text('Schedule Donation'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<DonorModel>(
                    isExpanded: true,
                    value: selectDonor,
                    decoration: const InputDecoration(labelText: 'Select Donor'),
                    items: _donors
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text("${d.fullName} (${d.bloodGroup ?? 'O+'})"),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectDonor = val);
                      }
                    },
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Date: ${selectDate.year}-${selectDate.month}-${selectDate.day}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setDialogState(() => selectDate = picked);
                            updateSlots();
                          }
                        },
                        child: const Text('Change Date'),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  isSlotsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectTimeSlot,
                          decoration: const InputDecoration(labelText: 'Available Time Slot'),
                          items: (availableSlots.isEmpty ? ['08:00', '10:00', '14:00'] : availableSlots)
                              .map((slot) => DropdownMenuItem(value: slot, child: Text(slot)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectTimeSlot = val);
                            }
                          },
                        ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  setState(() => _isLoading = true);
                  try {
                    final appRepo = ref.read(appointmentRepositoryProvider);
                    await appRepo.bookAppointment({
                      'donor': selectDonor!.id,
                      'hospital': 1, // Fallback default hospital
                      'date': "${selectDate.year}-${selectDate.month.toString().padLeft(2, '0')}-${selectDate.day.toString().padLeft(2, '0')}",
                      'time': "$selectTimeSlot:00",
                      'notes': 'Scheduled manually by staff',
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Appointment scheduled successfully!')),
                    );
                    _loadData();
                  } catch (e) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to book: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                },
                child: const Text('Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Handle custom notifications dispatch
  Future<void> _sendNotification() async {
    final title = _notifyTitleController.text.trim();
    final body = _notifyBodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out Title and Message fields.')));
      return;
    }

    setState(() => _isSendingNotification = true);

    try {
      final notifyRepo = ref.read(notificationRepositoryProvider);
      await notifyRepo.sendCustomNotification(
        title: title,
        message: body,
        recipientId: _selectedNotificationRecipient?.userId,
      );

      setState(() {
        _isSendingNotification = false;
        _notifyTitleController.clear();
        _notifyBodyController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification(s) sent successfully!')),
      );
    } catch (e) {
      setState(() => _isSendingNotification = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send notification: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Appointments & Alerts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.event), text: 'Appointments'),
            Tab(icon: Icon(Icons.notifications_active), text: 'Send Alerts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppointmentsTab(),
          _buildAlertsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _scheduleAppointment,
              icon: const Icon(Icons.add),
              label: const Text('Schedule Appointment'),
            )
          : null,
    );
  }

  // 1. APPOINTMENTS TAB
  Widget _buildAppointmentsTab() {
    // Filter list
    final filtered = _appointments.where((app) {
      // 1. Status Filter
      if (_selectedStatusFilter != 'ALL' && app.status != _selectedStatusFilter) {
        return false;
      }
      // 2. Date Filter
      if (_selectedDateFilter != null) {
        final sameDate = app.date.year == _selectedDateFilter!.year &&
            app.date.month == _selectedDateFilter!.month &&
            app.date.day == _selectedDateFilter!.day;
        if (!sameDate) return false;
      }
      // 3. Search Filter
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        final matchName = app.donorName.toLowerCase().contains(query);
        final matchHospital = app.hospitalName.toLowerCase().contains(query);
        if (!matchName && !matchHospital) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Controls Panel
        Card(
          margin: EdgeInsets.all(12.w),
          child: Padding(
            padding: EdgeInsets.all(10.w),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedStatusFilter,
                        decoration: const InputDecoration(labelText: 'Status Filter', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'SCHEDULED', child: Text('Scheduled')),
                          DropdownMenuItem(value: 'CONFIRMED', child: Text('Confirmed')),
                          DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                          DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatusFilter = val);
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8.w),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDateFilter ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 180)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDateFilter = picked);
                        }
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(_selectedDateFilter == null ? 'Filter Date' : "${_selectedDateFilter!.month}/${_selectedDateFilter!.day}"),
                    ),
                    if (_selectedDateFilter != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _selectedDateFilter = null),
                      ),
                  ],
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search donors...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchController.clear()))
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ),
        // List Views
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(child: Text('No appointments match current filters.'))
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final app = filtered[index];
                        final dateStr = "${app.date.year}-${app.date.month}-${app.date.day} at ${app.time}";

                        return Card(
                          margin: EdgeInsets.only(bottom: 10.h),
                          child: Padding(
                            padding: EdgeInsets.all(12.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      app.donorName,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
                                    ),
                                    _buildStatusBadge(app.status),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  "Scheduled: $dateStr",
                                  style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                                ),
                                if (app.notes != null && app.notes!.isNotEmpty) ...[
                                  SizedBox(height: 4.h),
                                  Text(
                                    "Notes: ${app.notes}",
                                    style: TextStyle(fontSize: 11.sp, fontStyle: FontStyle.italic),
                                  ),
                                ],
                                SizedBox(height: 10.h),
                                // Actions
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (app.status == 'SCHEDULED') ...[
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                                        onPressed: () => _cancelApp(app.id),
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('Cancel'),
                                      ),
                                      SizedBox(width: 8.w),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                                        onPressed: () => _confirmApp(app.id),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Confirm'),
                                      ),
                                    ] else if (app.status == 'CONFIRMED') ...[
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                                        onPressed: () => _cancelApp(app.id),
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('Cancel'),
                                      ),
                                      SizedBox(width: 8.w),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                                        onPressed: () => _completeApp(app.id),
                                        icon: const Icon(Icons.done_all),
                                        label: const Text('Complete Donation'),
                                      ),
                                    ] else ...[
                                      const Text('No pending actions', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'SCHEDULED':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case 'CONFIRMED':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade700;
        break;
      case 'COMPLETED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'CANCELLED':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10.r)),
      child: Text(
        status,
        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // 2. ALERTS/NOTIFICATIONS TAB
  Widget _buildAlertsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create Custom Notification',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<DonorModel?>(
                    isExpanded: true,
                    value: _selectedNotificationRecipient,
                    decoration: const InputDecoration(labelText: 'Recipient Target'),
                    items: [
                      const DropdownMenuItem<DonorModel?>(
                        value: null,
                        child: Text('📢 Broadcast to All Donors'),
                      ),
                      ..._donors.map((d) => DropdownMenuItem<DonorModel?>(
                            value: d,
                            child: Text("🎯 Direct: ${d.fullName}"),
                          ))
                    ],
                    onChanged: (val) {
                      setState(() => _selectedNotificationRecipient = val);
                    },
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _notifyTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Alert Title',
                      hintText: 'e.g. Urgent O- Blood Required',
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _notifyBodyController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message Body',
                      hintText: 'Describe the donation drive details, location, or urgent request details...',
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _isSendingNotification
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _sendNotification,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Dispatch Notification'),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
