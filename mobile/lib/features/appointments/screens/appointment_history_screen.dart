import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/appointment_repository.dart';
import '../../../../data/models/appointment_model.dart';

class AppointmentHistoryScreen extends ConsumerStatefulWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  ConsumerState<AppointmentHistoryScreen> createState() => _AppointmentHistoryScreenState();
}

class _AppointmentHistoryScreenState extends ConsumerState<AppointmentHistoryScreen> {
  void _refresh() {
    setState(() {});
  }

  Future<void> _handleCancel(AppointmentModel appointment) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel your appointment at ${appointment.hospitalName}?'),
            SizedBox(height: 12.h),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Appointment'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(appointmentRepositoryProvider).cancelAppointment(appointment.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment cancelled successfully'), backgroundColor: AppTheme.success),
          );
          _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  Future<void> _handleReschedule(AppointmentModel appointment) async {
    DateTime selectedDate = appointment.date.isAfter(DateTime.now()) ? appointment.date : DateTime.now().add(const Duration(days: 1));
    String selectedSlot = '09:00';

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );

    if (pickedDate == null) return;
    selectedDate = pickedDate;

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final slots = ['08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00'];
        String current = selectedSlot;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Select Time Slot (${selectedDate.day}/${selectedDate.month}/${selectedDate.year})'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: slots.map((slot) {
                  return RadioListTile<String>(
                    title: Text(slot),
                    value: slot,
                    groupValue: current,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => current = val);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, current),
                child: const Text('Confirm Reschedule'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      try {
        final formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
        await ref.read(appointmentRepositoryProvider).rescheduleAppointment(appointment.id, {
          'scheduled_date': formattedDate,
          'scheduled_time': result,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment rescheduled successfully!'), backgroundColor: AppTheme.success),
          );
          _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);
    final appointmentRepo = ref.watch(appointmentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('appointment_history')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).pushNamed('/book-appointment');
          _refresh();
        },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Book New'),
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
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.of(context).pushNamed('/book-appointment');
                      _refresh();
                    },
                    child: const Text('Book an Appointment'),
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
              final canManage = (appointment.status.toUpperCase() == 'PENDING' ||
                  appointment.status.toUpperCase() == 'SCHEDULED' ||
                  appointment.status.toUpperCase() == 'CONFIRMED');

              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                child: Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(appointment.status),
                          child: Icon(
                            _getStatusIcon(appointment.status),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          appointment.hospitalName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14.w, color: AppTheme.onSurfaceVariant),
                                SizedBox(width: 4.w),
                                Text(
                                  '${appointment.date.day}/${appointment.date.month}/${appointment.date.year} at ${appointment.time}',
                                  style: TextStyle(fontSize: 13.sp),
                                ),
                              ],
                            ),
                            if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                              SizedBox(height: 4.h),
                              Text(
                                'Notes: ${appointment.notes}',
                                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: _getStatusColor(appointment.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            appointment.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(appointment.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 11.sp,
                            ),
                          ),
                        ),
                      ),
                      if (canManage) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _handleReschedule(appointment),
                              icon: const Icon(Icons.edit_calendar, size: 18),
                              label: const Text('Reschedule'),
                            ),
                            SizedBox(width: 8.w),
                            TextButton.icon(
                              onPressed: () => _handleCancel(appointment),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ],
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
      case 'scheduled':
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
      case 'scheduled':
        return Icons.event_available;
      case 'pending':
        return Icons.pending_actions;
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.task_alt;
      default:
        return Icons.calendar_today;
    }
  }
}
