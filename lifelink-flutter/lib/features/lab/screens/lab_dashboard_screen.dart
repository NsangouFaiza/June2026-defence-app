import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../features/auth/providers/auth_providers.dart';
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

  void _showRecordDonationDialog(BuildContext context) {
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
          title: const Text('Record Donation'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: donorController,
                    decoration: const InputDecoration(labelText: 'Donor ID'),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: hospitalController,
                    decoration: const InputDecoration(labelText: 'Hospital ID'),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
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
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity (ml)'),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes / Screening Notes'),
                    maxLines: 3,
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
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final data = {
                      'donor': int.parse(donorController.text),
                      'hospital': int.parse(hospitalController.text),
                      'blood_group': selectedBloodGroup,
                      'units': int.parse(quantityController.text),
                      'notes': notesController.text,
                      'status': 'COMPLETED',
                    };
                    await ref.read(donationRepositoryProvider).recordDonation(data);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Donation recorded successfully')),
                    );
                    _refreshAll();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error recording donation: $e')),
                    );
                  }
                }
              },
              child: const Text('Record'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user != null ? 'Welcome Back, ${user.fullName}' : 'Welcome Back',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 20.h,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      'Lab Technician Dashboard',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outlined),
              onPressed: () {
                Navigator.of(context).pushNamed('/profile');
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Appointments', icon: Icon(Icons.event)),
              Tab(text: 'Donations', icon: Icon(Icons.bloodtype)),
              Tab(text: 'Screening', icon: Icon(Icons.science)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AppointmentsTab(future: _appointmentsFuture, onRefresh: _refreshAll),
            _DonationsTab(future: _donationsFuture),
            _ScreeningTab(future: _screeningFuture, onRefresh: _refreshAll),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showRecordDonationDialog(context),
          label: const Text('Record Donation'),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _AppointmentsTab extends ConsumerWidget {
  const _AppointmentsTab({required this.future, required this.onRefresh});

  final Future<List<AppointmentModel>> future;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<AppointmentModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No pending appointments'));
        }
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: Icon(Icons.person, color: AppTheme.primaryColor),
                  title: Text('Appointment #${item.id}'),
                  subtitle: Text('${item.date} • ${item.status}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: () async {
                      try {
                        await ref.read(appointmentRepositoryProvider).completeAppointment(item.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Appointment marked complete')),
                        );
                        onRefresh();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    tooltip: 'Validate attendance',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DonationsTab extends StatelessWidget {
  const _DonationsTab({required this.future});

  final Future<List<DonationModel>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DonationModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No donations to process'));
        }
        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                leading: Icon(Icons.bloodtype, color: AppTheme.secondaryColor),
                title: Text('${item.bloodGroup} • ${item.units} units'),
                subtitle: Text('Status: ${item.status}'),
              ),
            );
          },
        );
      },
    );
  }
}

class _ScreeningTab extends ConsumerWidget {
  const _ScreeningTab({required this.future, required this.onRefresh});

  final Future<List<BloodInventoryModel>> future;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<BloodInventoryModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No units pending screening'));
        }
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text('${item.bloodGroup} • Qty ${item.quantity}'),
                  subtitle: Text('Status: ${item.status}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          try {
                            await ref.read(inventoryRepositoryProvider).approveUnit(item.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Blood unit approved')),
                            );
                            onRefresh();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        tooltip: 'Approve unit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          try {
                            await ref.read(inventoryRepositoryProvider).rejectUnit(item.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Blood unit rejected')),
                            );
                            onRefresh();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        tooltip: 'Reject unit',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
