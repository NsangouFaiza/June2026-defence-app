import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../widgets/lifelink_app_bar.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _securityData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSecuritySettings();
  }

  Future<void> _fetchSecuritySettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final data = await authRepo.getSecuritySettings();
      if (mounted) {
        setState(() {
          _securityData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.updateSecuritySettings({key: value});
      await _fetchSecuritySettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Security setting updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update setting: $e')),
        );
      }
    }
  }

  Future<void> _terminateSession({int? sessionId, bool terminateAllOthers = false}) async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.terminateSession(sessionId: sessionId, terminateAllOthers: terminateAllOthers);
      await _fetchSecuritySettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(terminateAllOthers ? 'Logged out from all other devices.' : 'Session terminated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error terminating session: $e')),
        );
      }
    }
  }

  void _showRecoveryEmailDialog(String? currentEmail) {
    final controller = TextEditingController(text: currentEmail);
    final localization = ref.read(localizationServiceProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localization.translate('recovery_email')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: localization.translate('recovery_email'),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(localization.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateSetting('recovery_email', controller.text.trim());
            },
            child: Text(localization.translate('save')),
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
        title: localization.translate('security_settings'),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppTheme.error)),
                      SizedBox(height: 16.h),
                      ElevatedButton(onPressed: _fetchSecuritySettings, child: Text(localization.translate('retry'))),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Security Score Card
                      _buildSecurityScoreCard(localization),
                      SizedBox(height: 16.h),

                      // Quick Action: Change Password
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            child: Icon(Icons.lock_reset, color: AppTheme.primaryColor, size: 20.w),
                          ),
                          title: Text(localization.translate('change_password')),
                          subtitle: Text(localization.translate('change_password_desc')),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => Navigator.of(context).pushNamed('/change-password'),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Authentication & Security Preferences Card
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localization.translate('authentication_security'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              SizedBox(height: 12.h),

                              // Biometrics
                              SwitchListTile(
                                title: Text(localization.translate('biometric_auth')),
                                subtitle: Text(localization.translate('biometric_auth_desc')),
                                value: _securityData?['biometric_enabled'] ?? false,
                                onChanged: (val) => _updateSetting('biometric_enabled', val),
                              ),
                              const Divider(height: 1),

                              // Two Factor Auth
                              SwitchListTile(
                                title: Text(localization.translate('two_factor_auth')),
                                subtitle: Text(localization.translate('two_factor_auth_desc')),
                                value: _securityData?['two_factor_enabled'] ?? false,
                                onChanged: (val) => _updateSetting('two_factor_enabled', val),
                              ),
                              const Divider(height: 1),

                              // Login Notifications
                              SwitchListTile(
                                title: Text(localization.translate('login_notifications')),
                                subtitle: Text(localization.translate('login_notifications_desc')),
                                value: _securityData?['login_notifications_enabled'] ?? true,
                                onChanged: (val) => _updateSetting('login_notifications_enabled', val),
                              ),
                              const Divider(height: 1),

                              // Recovery Email
                              ListTile(
                                title: Text(localization.translate('recovery_email')),
                                subtitle: Text(_securityData?['recovery_email'] ?? localization.translate('not_configured')),
                                trailing: const Icon(Icons.edit_outlined, size: 18),
                                onTap: () => _showRecoveryEmailDialog(_securityData?['recovery_email']),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Active Sessions Card
                      _buildActiveSessionsCard(localization),
                      SizedBox(height: 16.h),

                      // Login History Logs
                      _buildLoginHistoryCard(localization),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSecurityScoreCard(LocalizationService loc) {
    final score = _securityData?['security_score'] ?? 50;
    Color scoreColor = AppTheme.warning;
    if (score >= 80) scoreColor = AppTheme.success;
    if (score < 40) scoreColor = AppTheme.error;

    return Card(
      color: scoreColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: scoreColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 54.w,
                  height: 54.w,
                  child: CircularProgressIndicator(
                    value: score / 100.0,
                    strokeWidth: 6.w,
                    backgroundColor: scoreColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                ),
                Text(
                  '$score%',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.translate('account_security_status'),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    score >= 80
                        ? loc.translate('security_status_high')
                        : loc.translate('security_status_medium'),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionsCard(LocalizationService loc) {
    final List sessions = _securityData?['active_sessions'] ?? [];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.translate('active_sessions'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (sessions.length > 1)
                  TextButton(
                    onPressed: () => _terminateSession(terminateAllOthers: true),
                    child: Text(
                      loc.translate('logout_other_devices'),
                      style: const TextStyle(color: AppTheme.error, fontSize: 12),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12.h),
            if (sessions.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Text(
                  loc.translate('no_active_sessions'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13.sp),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final sess = sessions[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.devices, color: AppTheme.primaryColor),
                    title: Text(sess['device_name'] ?? 'Mobile Device'),
                    subtitle: Text('${sess['ip_address'] ?? "IP: N/A"} • ${sess["last_activity"] != null ? sess["last_activity"].toString().substring(0, 10) : "Active Now"}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.exit_to_app, color: AppTheme.error, size: 20),
                      onPressed: () => _terminateSession(sessionId: sess['id']),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginHistoryCard(LocalizationService loc) {
    final List logs = _securityData?['login_history'] ?? [];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.translate('recent_login_history'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 12.h),
            if (logs.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Text(
                  loc.translate('no_login_history'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13.sp),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final log = logs[index];
                  final isSuccess = (log['status'] ?? '').toString().toLowerCase() == 'success';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                      color: isSuccess ? AppTheme.success : AppTheme.error,
                      size: 20.w,
                    ),
                    title: Text(log['device_name'] ?? 'Auth Request'),
                    subtitle: Text('${log["ip_address"] ?? "IP: Hidden"} • ${log["login_time"] != null ? log["login_time"].toString().replaceAll("T", " ").substring(0, 16) : ""}'),
                    trailing: Text(
                      log['status'] ?? 'Success',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: isSuccess ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
