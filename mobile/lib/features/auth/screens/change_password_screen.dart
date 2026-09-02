import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../features/auth/providers/auth_providers.dart';
import '../../../../data/repositories/auth_repository.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _hasMinLength(String p) => p.length >= 8;
  bool _hasUppercase(String p) => RegExp(r'[A-Z]').hasMatch(p);
  bool _hasLowercase(String p) => RegExp(r'[a-z]').hasMatch(p);
  bool _hasDigits(String p) => RegExp(r'[0-9]').hasMatch(p);
  bool _hasSpecialChar(String p) => RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(p);

  double _calculateStrength(String p) {
    if (p.isEmpty) return 0.0;
    int score = 0;
    if (_hasMinLength(p)) score++;
    if (_hasUppercase(p)) score++;
    if (_hasLowercase(p)) score++;
    if (_hasDigits(p)) score++;
    if (_hasSpecialChar(p)) score++;
    return score / 5.0;
  }

  Color _getStrengthColor(double strength) {
    if (strength <= 0.2) return AppTheme.error;
    if (strength <= 0.6) return AppTheme.warning;
    return AppTheme.success;
  }

  String _getStrengthText(double strength, LocalizationService loc) {
    if (strength <= 0.2) return loc.translate('weak');
    if (strength <= 0.6) return loc.translate('medium');
    return loc.translate('strong');
  }

  Future<void> _submitChangePassword() async {
    final localization = ref.read(localizationServiceProvider);
    if (!_formKey.currentState!.validate()) return;

    final newPass = _newPasswordController.text;
    if (_calculateStrength(newPass) < 0.8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localization.translate('password_requirements_unmet')),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.translate('password_changed_success')),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final cleanErr = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanErr),
            backgroundColor: AppTheme.error,
          ),
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
    final newPass = _newPasswordController.text;
    final strength = _calculateStrength(newPass);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('change_password')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          child: Icon(Icons.shield_outlined, color: AppTheme.primaryColor, size: 22.w),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Text(
                            localization.translate('change_password_notice'),
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                // Current Password
                TextFormField(
                  controller: _currentPasswordController,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: localization.translate('current_password'),
                    prefixIcon: const Icon(Icons.lock_clock_outlined),
                    hintText: localization.translate('enter_current_password'),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return localization.translate('please_enter_current_password');
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),

                // New Password
                TextFormField(
                  controller: _newPasswordController,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: _obscureNew,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: localization.translate('new_password'),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    hintText: localization.translate('create_new_password'),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return localization.translate('please_enter_password');
                    }
                    if (val.length < 8) {
                      return localization.translate('password_length_error');
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),

                // Password Strength Indicator
                if (newPass.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${localization.translate("password_strength")}: ',
                        style: TextStyle(fontSize: 12.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        _getStrengthText(strength, localization),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: _getStrengthColor(strength),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: strength,
                      minHeight: 6.h,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(_getStrengthColor(strength)),
                    ),
                  ),
                  SizedBox(height: 14.h),

                  // Rule Validation Checklist
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRuleRow('8+ characters', _hasMinLength(newPass)),
                        _buildRuleRow('At least 1 uppercase letter (A-Z)', _hasUppercase(newPass)),
                        _buildRuleRow('At least 1 lowercase letter (a-z)', _hasLowercase(newPass)),
                        _buildRuleRow('At least 1 number (0-9)', _hasDigits(newPass)),
                        _buildRuleRow('At least 1 special character (!@#\$%...)', _hasSpecialChar(newPass)),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                // Confirm New Password
                TextFormField(
                  controller: _confirmPasswordController,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: localization.translate('confirm_new_password'),
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    hintText: localization.translate('confirm_your_password'),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (val) {
                    if (val != _newPasswordController.text) {
                      return localization.translate('passwords_do_not_match');
                    }
                    return null;
                  },
                ),
                SizedBox(height: 32.h),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitChangePassword,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : Text(localization.translate('update_password')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleRow(String label, bool isMet) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16.w,
            color: isMet ? AppTheme.success : Colors.grey,
          ),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: isMet ? Theme.of(context).colorScheme.onSurface : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
