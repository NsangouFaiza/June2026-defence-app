import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/appointment_repository.dart';
import '../../../../data/models/appointment_model.dart';

class AppointmentHistoryScreen extends ConsumerWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final appointmentRepo = ref.watch(appointmentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('appointment_history')),
      ),
      body: FutureBuilder<List<AppointmentModel>>(
        future: appointmentRepo.getAppointments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final appointments = snapshot.data ?? [];

          if (appointments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64.w,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    localization.translate('no_appointments'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final appointment = appointments[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(appointment.status),
                    child: Icon(
                      _getStatusIcon(appointment.status),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    appointment.hospitalName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${appointment.date.day}/${appointment.date.month}/${appointment.date.year} at ${appointment.time}',
                      ),
                      if (appointment.notes != null && appointment.notes!.isNotEmpty)
                        Text(
                          appointment.notes!,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (appointment.status == 'CONFIRMED' || appointment.status == 'PENDING')
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                          onPressed: () {
                            // Reschedule
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: AppTheme.error),
                        onPressed: () {
                          // Cancel
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppTheme.success;
      case 'pending':
        return AppTheme.warning;
      case 'cancelled':
        return AppTheme.error;
      case 'completed':
        return AppTheme.primaryColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check;
      case 'pending':
        return Icons.pending;
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }
}
