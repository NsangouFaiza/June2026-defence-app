import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/eligibility_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../widgets/lifelink_app_bar.dart';

class EligibilityCheckScreen extends ConsumerStatefulWidget {
  const EligibilityCheckScreen({super.key});

  @override
  ConsumerState<EligibilityCheckScreen> createState() => _EligibilityCheckScreenState();
}

class _EligibilityCheckScreenState extends ConsumerState<EligibilityCheckScreen> {
  final _formKey = GlobalKey<FormState>();

  int _age = 25;
  double _weight = 70;
  bool _hasRecentSurgery = false;
  bool _isPregnant = false;
  bool _hasInfectiousDisease = false;
  bool _isOnMedication = false;
  bool _hasMedicalCondition = false;
  bool _isLoading = false;
  String? _result;

  Future<void> _checkEligibility() async {
    final localization = ref.read(localizationServiceProvider);

    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(eligibilityRepositoryProvider);
      final result = await repo.checkEligibility({
        'age': _age,
        'weight': _weight,
        'has_recent_surgery': _hasRecentSurgery,
        'is_pregnant': _isPregnant,
        'has_infectious_disease': _hasInfectiousDisease,
        'is_on_medication': _isOnMedication,
        'has_medical_condition': _hasMedicalCondition,
      });

      setState(() => _result = result.status);
      if (result.status == 'ELIGIBLE' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are eligible! Redirecting to booking...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking eligibility: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  void _showResultDialog(Map<String, dynamic> result) {
    final isEligible = result['is_eligible'] as bool? ?? false;
    final reason = result['reason'] as String? ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEligible ? 'Eligible to Donate!' : 'Not Eligible Currently'),
        content: Text(
          isEligible
              ? 'Great news! You meet the initial health guidelines to donate blood.'
              : reason.isNotEmpty
                  ? reason
                  : 'Based on your entries, you do not meet the criteria at this time.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      appBar: LifeLinkAppBar(
        title: localization.translate('eligibility_check'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localization.translate('health_questionnaire'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 24.h),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: localization.translate('age'),
                    prefixIcon: const Icon(Icons.cake_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: _age.toString(),
                  onChanged: (value) => _age = int.tryParse(value) ?? _age,
                  validator: (value) {
                    if (value == null || int.tryParse(value) == null || int.parse(value) < 18 || int.parse(value) > 65) {
                      return 'Age must be between 18 and 65';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: localization.translate('weight_kg'),
                    prefixIcon: const Icon(Icons.monitor_weight_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: _weight.toString(),
                  onChanged: (value) => _weight = double.tryParse(value) ?? _weight,
                  validator: (value) {
                    if (value == null || double.tryParse(value) == null || double.parse(value) < 50) {
                      return 'Weight must be at least 50 kg';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                SwitchListTile(
                  title: Text(localization.translate('recent_surgeries')),
                  subtitle: const Text('Any surgery in the last 6 months'),
                  value: _hasRecentSurgery,
                  onChanged: (value) => setState(() => _hasRecentSurgery = value),
                ),
                SwitchListTile(
                  title: Text(localization.translate('pregnancy_status')),
                  value: _isPregnant,
                  onChanged: (value) => setState(() => _isPregnant = value),
                ),
                SwitchListTile(
                  title: Text(localization.translate('infectious_diseases')),
                  subtitle: const Text('HIV, Hepatitis, etc.'),
                  value: _hasInfectiousDisease,
                  onChanged: (value) => setState(() => _hasInfectiousDisease = value),
                ),
                SwitchListTile(
                  title: Text(localization.translate('medication_use')),
                  value: _isOnMedication,
                  onChanged: (value) => setState(() => _isOnMedication = value),
                ),
                SwitchListTile(
                  title: Text(localization.translate('medical_condition')),
                  value: _hasMedicalCondition,
                  onChanged: (value) => setState(() => _hasMedicalCondition = value),
                ),
                SizedBox(height: 32.h),
                if (_result != null) ...[
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: _getResultColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: _getResultColor()),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getResultIcon(),
                          size: 48.w,
                          color: _getResultColor(),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          _getResultText(localization),
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: _getResultColor(),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_result == 'ELIGIBLE') ...[
                          SizedBox(height: 16.h),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacementNamed('/book-appointment');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Book Appointment Now'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
                ElevatedButton(
                  onPressed: _isLoading ? null : _checkEligibility,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(localization.translate('check_eligibility')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getResultColor() {
    switch (_result) {
      case 'ELIGIBLE':
        return AppTheme.success;
      case 'TEMPORARY_INELIGIBLE':
        return AppTheme.warning;
      case 'PERMANENT_INELIGIBLE':
        return AppTheme.error;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getResultIcon() {
    switch (_result) {
      case 'ELIGIBLE':
        return Icons.check_circle;
      case 'TEMPORARY_INELIGIBLE':
        return Icons.warning;
      case 'PERMANENT_INELIGIBLE':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getResultText(LocalizationService localization) {
    switch (_result) {
      case 'ELIGIBLE':
        return localization.translate('eligible');
      case 'TEMPORARY_INELIGIBLE':
        return localization.translate('temporary_ineligible');
      case 'PERMANENT_INELIGIBLE':
        return localization.translate('permanent_ineligible');
      default:
        return 'Unknown';
    }
  }
}
