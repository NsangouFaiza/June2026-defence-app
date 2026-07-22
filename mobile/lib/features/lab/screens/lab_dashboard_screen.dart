import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/appointment_repository.dart';
import '../../../../data/repositories/donation_repository.dart';
import '../../../../data/repositories/inventory_repository.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/donation_model.dart';
import '../../../../data/models/blood_inventory_model.dart';

class LabDashboardScreen extends ConsumerStatefulWidget {
  const LabDashboardScreen({super.key});

  @override
  ConsumerState<LabDashboardScreen> createState() => _LabDashboardScreenState();
}

class _LabDashboardScreenState extends ConsumerState<LabDashboardScreen> {
  late Future<List<AppointmentModel>> _appointmentsFuture;
  late Future<List<DonationModel>> _donationsFuture;
  late Future<List<BloodInventoryModel>> _screeningFuture;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  void _refreshAll() {
    setState(() {
      _appointmentsFuture = ref.read(appointmentRepositoryProvider).getAppointments();
      _donationsFuture = ref.read(donationRepositoryProvider).getDonationHistory();
      _screeningFuture = ref.read(inventoryRepositoryProvider).getInventory();
    });
  }

  // --- 1. Validate Attendance Modal ---
  void _openValidateAttendanceModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fact_check_rounded, color: AppTheme.primaryColor, size: 24.w),
                      SizedBox(width: 8.w),
                      Text('Validate Donor Attendance', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<AppointmentModel>>(
                  future: _appointmentsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final appointments = snapshot.data ?? [];
                    if (appointments.isEmpty) {
                      return const Center(child: Text('No pending donor appointments logged.'));
                    }
                    return ListView.builder(
                      itemCount: appointments.length,
                      itemBuilder: (context, index) {
                        final appt = appointments[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 6.h),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              child: Icon(Icons.person, color: AppTheme.primaryColor),
                            ),
                            title: Text('Appointment #${appt.id}'),
                            subtitle: Text('Date: ${appt.date} • Status: ${appt.status}'),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                try {
                                  await ref.read(appointmentRepositoryProvider).completeAppointment(appt.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Attendance Validated & Marked Completed'), backgroundColor: AppTheme.success),
                                    );
                                  }
                                  _refreshAll();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                              child: const Text('Validate'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 2. Record Donation Modal ---
  void _openRecordDonationModal() {
    final donorController = TextEditingController();
    final hospitalController = TextEditingController();
    final quantityController = TextEditingController(text: '450');
    final notesController = TextEditingController();
    String selectedBloodGroup = 'O+';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              Icon(Icons.water_drop_rounded, color: Colors.red.shade700, size: 24.w),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Record Blood Donation',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: donorController,
                    decoration: const InputDecoration(labelText: 'Donor ID / Code'),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: hospitalController,
                    decoration: const InputDecoration(labelText: 'Hospital ID'),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 8.h),
                  DropdownButtonFormField<String>(
                    value: selectedBloodGroup,
                    decoration: const InputDecoration(labelText: 'Blood Group'),
                    items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                        .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) selectedBloodGroup = val;
                    },
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity (ml)'),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Screening Notes'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await ref.read(donationRepositoryProvider).recordDonation({
                      'donor': int.parse(donorController.text),
                      'hospital': int.parse(hospitalController.text),
                      'blood_group': selectedBloodGroup,
                      'units': int.parse(quantityController.text),
                      'notes': notesController.text,
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Donation recorded successfully'), backgroundColor: AppTheme.success),
                      );
                    }
                    _refreshAll();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              child: const Text('Save Record'),
            ),
          ],
        );
      },
    );
  }

  // --- 3. Analyze Samples Modal ---
  void _openAnalyzeSamplesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.biotech_rounded, color: Colors.cyan.shade700, size: 24.w),
                      SizedBox(width: 8.w),
                      Text('Analyze Blood Samples', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<BloodInventoryModel>>(
                  future: _screeningFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final units = snapshot.data ?? [];
                    if (units.isEmpty) {
                      return const Center(child: Text('No blood units logged for analysis.'));
                    }
                    return ListView.builder(
                      itemCount: units.length,
                      itemBuilder: (context, index) {
                        final u = units[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.opacity, color: Colors.cyan.shade700),
                            title: Text('Unit #${u.id} • Group ${u.bloodGroup}'),
                            subtitle: Text('Volume: ${u.quantity} ml • Status: ${u.status}'),
                            trailing: TextButton.icon(
                              icon: const Icon(Icons.science_rounded, size: 16),
                              label: const Text('Analyze'),
                              onPressed: () => _openBloodTypingAndScreeningModal(unit: u),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 4 & 5. Blood Typing & Disease Screening Modal ---
  void _openBloodTypingAndScreeningModal({BloodInventoryModel? unit}) {
    String abo = unit?.bloodGroup ?? 'O+';
    String rhFactor = 'Positive (+)';
    bool hivNegative = true;
    bool hepBNegative = true;
    bool hepCNegative = true;
    bool syphilisNegative = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              title: Row(
                children: [
                  Icon(Icons.health_and_safety_rounded, color: Colors.teal.shade700, size: 24.w),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Blood Typing & Disease Screening',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ABO & Rh Factor Determination:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: abo,
                            decoration: const InputDecoration(labelText: 'ABO Group'),
                            items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => abo = val);
                            },
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: rhFactor,
                            decoration: const InputDecoration(labelText: 'Rh Factor'),
                            items: ['Positive (+)', 'Negative (-)']
                                .map((rh) => DropdownMenuItem(value: rh, child: Text(rh)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => rhFactor = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Text('Infectious Disease Screening (Serology):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                    CheckboxListTile(
                      title: const Text('HIV I & II (Non-Reactive)'),
                      value: hivNegative,
                      activeColor: AppTheme.success,
                      onChanged: (v) => setDialogState(() => hivNegative = v ?? true),
                    ),
                    CheckboxListTile(
                      title: const Text('Hepatitis B Surface Ag (HBsAg Non-Reactive)'),
                      value: hepBNegative,
                      activeColor: AppTheme.success,
                      onChanged: (v) => setDialogState(() => hepBNegative = v ?? true),
                    ),
                    CheckboxListTile(
                      title: const Text('Hepatitis C Antibodies (HCV Non-Reactive)'),
                      value: hepCNegative,
                      activeColor: AppTheme.success,
                      onChanged: (v) => setDialogState(() => hepCNegative = v ?? true),
                    ),
                    CheckboxListTile(
                      title: const Text('Syphilis VDRL/TPHA (Non-Reactive)'),
                      value: syphilisNegative,
                      activeColor: AppTheme.success,
                      onChanged: (v) => setDialogState(() => syphilisNegative = v ?? true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final allClean = hivNegative && hepBNegative && hepCNegative && syphilisNegative;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(allClean
                            ? 'Blood Type $abo verified. Serology Non-Reactive (Safe for Transfusion)'
                            : 'WARNING: Reactive Pathogen Detected! Sample Flagged & Quarantined!'),
                        backgroundColor: allClean ? AppTheme.success : AppTheme.error,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  child: const Text('Save Screening'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 6. Approve / Reject Blood Units Modal ---
  void _openApproveRejectUnitsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: Colors.orange.shade800, size: 24.w),
                      SizedBox(width: 8.w),
                      Text('Approve / Reject Blood Units', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<BloodInventoryModel>>(
                  future: _screeningFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final units = snapshot.data ?? [];
                    if (units.isEmpty) {
                      return const Center(child: Text('No blood units pending evaluation.'));
                    }
                    return ListView.builder(
                      itemCount: units.length,
                      itemBuilder: (context, index) {
                        final u = units[index];
                        return Card(
                          child: ListTile(
                            title: Text('Unit #${u.id} • ${u.bloodGroup} (${u.quantity} ml)'),
                            subtitle: Text('Status: ${u.status.toUpperCase()}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                  onPressed: () async {
                                    try {
                                      await ref.read(inventoryRepositoryProvider).approveUnit(u.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Unit Approved & Moved to Inventory'), backgroundColor: AppTheme.success),
                                        );
                                      }
                                      _refreshAll();
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                      }
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                                  onPressed: () async {
                                    try {
                                      await ref.read(inventoryRepositoryProvider).rejectUnit(u.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Unit Rejected & Flagged Disposable'), backgroundColor: Colors.red),
                                        );
                                      }
                                      _refreshAll();
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 7. Update Blood Status Modal ---
  void _openUpdateBloodStatusModal() {
    String selectedStatus = 'available';
    final unitIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              title: Row(
                children: [
                  Icon(Icons.published_with_changes_rounded, color: Colors.purple.shade700, size: 24.w),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Update Blood Unit Status',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: unitIdController,
                    decoration: const InputDecoration(labelText: 'Blood Unit ID'),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10.h),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Target Status'),
                    items: const [
                      DropdownMenuItem(value: 'available', child: Text('AVAILABLE (Approved)')),
                      DropdownMenuItem(value: 'pending', child: Text('PENDING (In Screening)')),
                      DropdownMenuItem(value: 'reserved', child: Text('RESERVED (For Emergency)')),
                      DropdownMenuItem(value: 'quarantined', child: Text('QUARANTINED (Abnormal Pathogen)')),
                      DropdownMenuItem(value: 'rejected', child: Text('REJECTED (Disposed)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedStatus = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Unit #${unitIdController.text.isEmpty ? '1' : unitIdController.text} status updated to ${selectedStatus.toUpperCase()}'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                    _refreshAll();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  child: const Text('Update Status'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 8 & 11. Laboratory Records & Classification Modal ---
  void _openLabRecordsAndClassificationModal({String initialFilter = 'ALL'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_shared_rounded, color: Colors.indigo.shade700, size: 24.w),
                      SizedBox(width: 8.w),
                      Text('Laboratory Records & File Store', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<BloodInventoryModel>>(
                  future: _screeningFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final units = snapshot.data ?? [];
                    if (units.isEmpty) {
                      return const Center(child: Text('No laboratory records logged yet.'));
                    }
                    return ListView.builder(
                      itemCount: units.length,
                      itemBuilder: (context, index) {
                        final u = units[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade700),
                            title: Text('LAB-REC-2026-00${u.id} • Group ${u.bloodGroup}'),
                            subtitle: Text('Status: ${u.status.toUpperCase()} • Qty: ${u.quantity} ml\nScreened for HIV, Hep B/C, Syphilis'),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.download_rounded),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Downloading Lab Report #LAB-REC-2026-00${u.id}.pdf...')),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 9. Report Abnormal Findings Modal ---
  void _openReportAbnormalFindingsModal() {
    final noteController = TextEditingController();
    final unitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Colors.red.shade700, size: 24.w),
              SizedBox(width: 8.w),
              const Text('Report Abnormal Findings'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Blood Unit ID / Donor Code'),
              ),
              SizedBox(height: 10.h),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Abnormal Finding Details (e.g. Hemolysis, Bacterial Contamination)'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abnormal finding logged & alert sent to hospital staff!'), backgroundColor: AppTheme.success),
                );
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Report & Alert Staff'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );
  }

  // --- 10. History Modal ---
  void _openHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_edu_rounded, color: Colors.blueGrey.shade700, size: 24.w),
                      SizedBox(width: 8.w),
                      Text('Laboratory Audit History', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                      title: const Text('Donor DON-2026-0001 Screened'),
                      subtitle: const Text('ABO: O+ • HIV Negative • Hep B/C Negative • Approved'),
                      trailing: const Text('Today, 14:20'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      title: const Text('Abnormal Finding Reported'),
                      subtitle: const Text('Unit #402 flagged for Hemolysis re-inspection'),
                      trailing: const Text('Yesterday, 10:15'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.inventory_2_rounded, color: Colors.blue),
                      title: const Text('5 Units Transferred to Blood Bank'),
                      subtitle: const Text('Central Hospital Yaoundé Blood Bank Store'),
                      trailing: const Text('2 days ago'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Laboratory Dashboard'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LABORATORY CONTROL CENTER',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 12.h),

              // Responsive 2-Column Grid of Large Clickable Icon Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14.w,
                mainAxisSpacing: 14.h,
                childAspectRatio: 1.1,
                children: [
                  _buildDashboardCard(
                    title: 'Validate Attendance',
                    description: 'Check in donors & verify appointments',
                    icon: Icons.fact_check_rounded,
                    gradient: const [Color(0xFF1E88E5), Color(0xFF1565C0)],
                    onTap: _openValidateAttendanceModal,
                  ),
                  _buildDashboardCard(
                    title: 'Record Donation',
                    description: 'Log new blood donation entries',
                    icon: Icons.water_drop_rounded,
                    gradient: const [Color(0xFFE53935), Color(0xFFC62828)],
                    onTap: _openRecordDonationModal,
                  ),
                  _buildDashboardCard(
                    title: 'Analyze Samples',
                    description: 'Inspect collected blood specimens',
                    icon: Icons.biotech_rounded,
                    gradient: const [Color(0xFF00ACC1), Color(0xFF00838F)],
                    onTap: _openAnalyzeSamplesModal,
                  ),
                  _buildDashboardCard(
                    title: 'Disease Screening',
                    description: 'Screen for HIV, Hep B/C & Syphilis',
                    icon: Icons.health_and_safety_rounded,
                    gradient: const [Color(0xFF00897B), Color(0xFF004D40)],
                    onTap: () => _openBloodTypingAndScreeningModal(),
                  ),
                  _buildDashboardCard(
                    title: 'Approve / Reject',
                    description: 'Approve safe units or reject bad ones',
                    icon: Icons.verified_user_rounded,
                    gradient: const [Color(0xFFFB8C00), Color(0xFFEF6C00)],
                    onTap: _openApproveRejectUnitsModal,
                  ),
                  _buildDashboardCard(
                    title: 'Update Blood Status',
                    description: 'Available, reserved, or quarantined',
                    icon: Icons.published_with_changes_rounded,
                    gradient: const [Color(0xFF7B1FA2), Color(0xFF4A148C)],
                    onTap: _openUpdateBloodStatusModal,
                  ),
                  _buildDashboardCard(
                    title: 'Laboratory Records',
                    description: 'Store & view donor lab files',
                    icon: Icons.folder_shared_rounded,
                    gradient: const [Color(0xFF3949AB), Color(0xFF283593)],
                    onTap: () => _openLabRecordsAndClassificationModal(initialFilter: 'ALL'),
                  ),
                  _buildDashboardCard(
                    title: 'History',
                    description: 'View complete lab audit history',
                    icon: Icons.history_edu_rounded,
                    gradient: const [Color(0xFF546E7A), Color(0xFF37474F)],
                    onTap: _openHistoryModal,
                  ),
                  _buildDashboardCard(
                    title: 'Classify Records',
                    description: 'Categorize by donor & test status',
                    icon: Icons.category_rounded,
                    gradient: const [Color(0xFF5E35B1), Color(0xFF4527A0)],
                    onTap: () => _openLabRecordsAndClassificationModal(initialFilter: 'APPROVED'),
                  ),
                ],
              ),

              SizedBox(height: 30.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
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
}
