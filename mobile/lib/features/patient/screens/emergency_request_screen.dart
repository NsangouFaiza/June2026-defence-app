import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/request_repository.dart';
import '../../../../core/constants/app_constants.dart';

class EmergencyRequestScreen extends ConsumerStatefulWidget {
  const EmergencyRequestScreen({super.key});

  @override
  ConsumerState<EmergencyRequestScreen> createState() => _EmergencyRequestScreenState();
}

class _EmergencyRequestScreenState extends ConsumerState<EmergencyRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBloodGroup;
  int _quantity = 1;
  String? _selectedUrgency;
  String? _reason;
  bool _isLoading = false;

  Future<void> _submitEmergencyRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBloodGroup == null || _selectedUrgency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final requestRepo = ref.read(requestRepositoryProvider);
      await requestRepo.createEmergencyRequest({
        'blood_group': _selectedBloodGroup,
        'quantity': _quantity,
        'urgency': _selectedUrgency,
        'reason': _reason ?? '',
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: AppTheme.success, size: 64),
            title: const Text('Emergency Request Sent'),
            content: const Text('Your emergency blood request has been sent to all nearby hospitals and donors.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('emergency_request')),
        backgroundColor: AppTheme.error,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: AppTheme.error, size: 32.w),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Text(
                          localization.translate('emergency_warning'),
                          style: TextStyle(color: AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Blood Group',
                    prefixIcon: Icon(Icons.bloodtype_outlined),
                  ),
                  items: AppConstants.bloodGroups
                      .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedBloodGroup = value),
                  validator: (value) => value == null ? 'Please select blood group' : null,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Quantity (units)',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: '1',
                  onChanged: (value) => _quantity = int.tryParse(value) ?? 1,
                  validator: (value) {
                    if (value == null || int.tryParse(value) == null || int.parse(value) < 1) {
                      return 'Please enter a valid quantity';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Urgency Level',
                    prefixIcon: Icon(Icons.priority_high),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'HIGH', child: Text('High')),
                    DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
                  ],
                  onChanged: (value) => setState(() => _selectedUrgency = value),
                  validator: (value) => value == null ? 'Please select urgency' : null,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  maxLines: 3,
                  onChanged: (value) => _reason = value,
                ),
                SizedBox(height: 32.h),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitEmergencyRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          localization.translate('send_emergency_request'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
