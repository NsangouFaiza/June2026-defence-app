import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/appointment_repository.dart';
import '../../../../data/repositories/donation_repository.dart';
import '../../../../data/repositories/inventory_repository.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/donation_model.dart';
import '../../../../data/models/blood_inventory_model.dart';

class LabDashboardScreen extends ConsumerWidget {
  const LabDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final appointmentRepo = ref.watch(appointmentRepositoryProvider);
    final donationRepo = ref.watch(donationRepositoryProvider);
    final inventoryRepo = ref.watch(inventoryRepositoryProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lab Technician Dashboard'),
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
            _AppointmentsTab(future: appointmentRepo.getAppointments()),
            _DonationsTab(future: donationRepo.getDonationHistory()),
            _ScreeningTab(future: inventoryRepo.getInventory()),
          ],
        ),
      ),
    );
  }
}

class _AppointmentsTab extends StatelessWidget {
  const _AppointmentsTab({required this.future});

  final Future<List<AppointmentModel>> future;

  @override
  Widget build(BuildContext context) {
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
        return ListView.builder(
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
                  onPressed: () {},
                  tooltip: 'Validate attendance',
                ),
              ),
            );
          },
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

class _ScreeningTab extends StatelessWidget {
  const _ScreeningTab({required this.future});

  final Future<List<BloodInventoryModel>> future;

  @override
  Widget build(BuildContext context) {
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
        return ListView.builder(
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
                      onPressed: () {},
                      tooltip: 'Approve unit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {},
                      tooltip: 'Reject unit',
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
}
