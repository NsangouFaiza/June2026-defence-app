import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../widgets/lifelink_app_bar.dart';
import '../widgets/admin_user_common.dart';

/// Full profile of a single user as seen by a system admin.
/// Pops with `true` when the user was modified or deleted so the list can refresh.
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final int userId;
  final Map<String, dynamic>? initialUser;

  const AdminUserDetailScreen({super.key, required this.userId, this.initialUser});

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;
  bool _changed = false;

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _repo.getUserDetails(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminRepository.errorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _act(Future<bool> Function(AdminUserActions a) action, {bool closeAfter = false}) async {
    final changed = await action(AdminUserActions(context, _repo));
    if (!changed || !mounted) return;
    _changed = true;
    if (closeAfter) {
      Navigator.of(context).pop(true);
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = ref.watch(currentUserProvider).value?.id == widget.userId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: LifeLinkAppBar(
          title: 'User Details',
          onBackPressed: () => Navigator.of(context).pop(_changed),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _load,
            ),
          ],
        ),
        body: _buildBody(isSelf),
      ),
    );
  }

  Widget _buildBody(bool isSelf) {
    final user = _user;
    if (user == null) {
      if (_error != null) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48.w, color: AppTheme.error),
                SizedBox(height: 8.h),
                Text(_error!, textAlign: TextAlign.center),
                SizedBox(height: 12.h),
                ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final donor = user['donor_profile'] as Map<String, dynamic>?;
    final patient = user['patient_profile'] as Map<String, dynamic>?;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
        children: [
          if (_loading) LinearProgressIndicator(minHeight: 2.h),
          _header(user),
          SizedBox(height: 12.h),
          _actionsBar(user, isSelf),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text('Could not refresh: $_error', style: TextStyle(color: AppTheme.error, fontSize: 12.sp)),
            ),
          _section('Personal Information', Icons.person_outline, [
            _row('Email', user['email']),
            _row('Phone', user['phone_number']),
            _row('Gender', switch (user['gender']) { 'M' => 'Male', 'F' => 'Female', _ => null }),
            _row(
              'Date of birth',
              user['date_of_birth'] == null
                  ? null
                  : '${adminFormatDate(user['date_of_birth'])}${user['age'] != null ? '  (${user['age']} yrs)' : ''}',
            ),
            _row('Blood group', user['blood_group']),
            _row('Address', user['address']),
            _row('City', user['city']),
            _row('Region', user['region']),
          ]),
          _section('Account', Icons.manage_accounts_outlined, [
            _row('Role', kAdminRoleLabels[user['role']] ?? user['role']),
            _row('Status', user['is_active'] == true ? 'Active' : 'Suspended'),
            _row('Verified', user['is_verified'] == true ? 'Yes' : 'No'),
            if (user.containsKey('two_factor_enabled'))
              _row('Two-factor auth', user['two_factor_enabled'] == true ? 'Enabled' : 'Disabled'),
            if (user['language'] != null) _row('Language', user['language'] == 'fr' ? 'French' : 'English'),
            _row('Joined', adminFormatDate(user['date_joined'])),
            _row('Last login', adminFormatDate(user['last_login'])),
            if (user['hospital_name'] != null) _row('Hospital', user['hospital_name']),
            if (user['hospital_position'] != null) _row('Position', user['hospital_position']),
          ]),
          if (donor != null) ..._donorSection(user, donor),
          if (patient != null) ..._patientSection(user, patient),
          _paymentsSection(user),
          _loginsSection(user),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- Header

  Widget _header(Map<String, dynamic> user) {
    final role = user['role'] as String?;
    final color = adminRoleColor(role);
    final isActive = user['is_active'] == true;

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34.r,
            backgroundColor: Colors.white,
            child: Text(
              (user['full_name'] ?? '?').toString().trim().isEmpty
                  ? '?'
                  : user['full_name'].toString().trim()[0].toUpperCase(),
              style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['full_name'] ?? '',
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 2.h),
                Text(user['email'] ?? '', style: TextStyle(fontSize: 12.sp, color: Colors.white70)),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 4.h,
                  children: [
                    _whiteChip(kAdminRoleLabels[role] ?? role ?? ''),
                    _whiteChip(isActive ? 'Active' : 'Suspended', icon: isActive ? Icons.check_circle : Icons.block),
                    if (user['is_verified'] == true) _whiteChip('Verified', icon: Icons.verified),
                    if (user['blood_group'] != null) _whiteChip(user['blood_group'], icon: Icons.bloodtype),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteChip(String label, {IconData? icon}) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(10.r)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12.sp, color: Colors.white), SizedBox(width: 3.w)],
            Text(label, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      );

  Widget _actionsBar(Map<String, dynamic> user, bool isSelf) {
    final isActive = user['is_active'] == true;
    Widget action(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 20.r,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color, size: 20.w),
                  ),
                  SizedBox(height: 4.h),
                  Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
        child: Row(
          children: [
            action(Icons.edit_outlined, 'Edit', AppTheme.accentColor, () => _act((a) => a.openForm(user: user))),
            action(Icons.lock_reset, 'Password', Colors.blueGrey, () => _act((a) => a.resetPassword(user))),
            if (!isSelf) ...[
              action(Icons.badge_outlined, 'Role', Colors.purple, () => _act((a) => a.changeRole(user))),
              action(
                isActive ? Icons.block : Icons.check_circle,
                isActive ? 'Suspend' : 'Activate',
                isActive ? AppTheme.warning : AppTheme.success,
                () => _act((a) => a.toggleActive(user)),
              ),
              action(Icons.delete_outline, 'Delete', AppTheme.error, () => _act((a) => a.delete(user), closeAfter: true)),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Sections

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Card(
      margin: EdgeInsets.only(top: 14.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20.w, color: AppTheme.primaryColor),
                SizedBox(width: 8.w),
                Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 8.h),
            const Divider(height: 1),
            SizedBox(height: 6.h),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value) => Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120.w,
              child: Text(label, style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(
                (value == null || value.toString().trim().isEmpty) ? '—' : value.toString(),
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  Widget _statTile(String label, dynamic value, IconData icon, Color color) => Expanded(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 3.w),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12.r)),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20.w),
              SizedBox(height: 4.h),
              Text('${value ?? 0}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: color)),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.sp)),
            ],
          ),
        ),
      );

  Widget _statusBadge(String? status) {
    final s = (status ?? '').toUpperCase();
    final color = switch (s) {
      'COMPLETED' || 'SUCCESS' || 'PAID' || 'FULFILLED' || 'APPROVED' || 'CONFIRMED' => AppTheme.success,
      'PENDING' || 'SCHEDULED' || 'PROCESSING' => AppTheme.warning,
      'FAILED' || 'CANCELLED' || 'REJECTED' || 'EXPIRED' => AppTheme.error,
      _ => Colors.blueGrey,
    };
    return AdminChip(label: s.isEmpty ? '—' : s, color: color);
  }

  Widget _emptyLine(String text) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Text(text, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
      );

  Widget _subheading(String text) => Padding(
        padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Colors.grey.shade700),
        ),
      );

  Widget _activityTile({required IconData icon, required String title, String? subtitle, String? status}) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 16.r,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Icon(icon, size: 16.w, color: AppTheme.primaryColor),
        ),
        title: Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(fontSize: 11.sp)),
        trailing: status == null ? null : _statusBadge(status),
      );

  List<Widget> _donorSection(Map<String, dynamic> user, Map<String, dynamic> donor) {
    final donations = (user['recent_donations'] as List?) ?? [];
    final appointments = (user['recent_appointments'] as List?) ?? [];
    return [
      _section('Donor Profile', Icons.volunteer_activism_outlined, [
        Row(
          children: [
            _statTile('Donations', donor['total_donations'], Icons.favorite, AppTheme.primaryColor),
            _statTile('Units', donor['total_blood_units'], Icons.bloodtype, AppTheme.accentColor),
            _statTile('Lives saved', donor['lives_saved'], Icons.health_and_safety, AppTheme.success),
            _statTile('Points', donor['points'], Icons.stars, AppTheme.warning),
          ],
        ),
        SizedBox(height: 8.h),
        _row('Level', donor['level']),
        _row('Eligibility', donor['is_eligible'] == true ? 'Eligible' : (donor['eligibility_status'] ?? 'Not eligible')),
        _row('Available', donor['is_available'] == true ? 'Yes' : 'No'),
        _row('Last donation', adminFormatDate(donor['last_donation_date'])),
        _row('Next eligible', adminFormatDate(donor['next_eligible_date'])),
        if (donor['weight'] != null) _row('Weight', '${donor['weight']} kg'),
        if (donor['height'] != null) _row('Height', '${donor['height']} cm'),
        _subheading('Recent donations'),
        if (donations.isEmpty) _emptyLine('No donations recorded'),
        ...donations.map(
          (d) => _activityTile(
            icon: Icons.favorite_outline,
            title: '${d['quantity_ml']} ml • ${d['blood_group'] ?? ''}',
            subtitle: '${d['hospital_name'] ?? 'Unknown hospital'} • ${adminFormatDate(d['created_at'])}',
            status: d['status'],
          ),
        ),
        _subheading('Appointments'),
        if (appointments.isEmpty) _emptyLine('No appointments'),
        ...appointments.map(
          (a) => _activityTile(
            icon: Icons.event_outlined,
            title: a['hospital_name'] ?? 'Unknown hospital',
            subtitle:
                '${adminFormatDate(a['scheduled_date'])} at ${(a['scheduled_time'] ?? '').toString().split('.').first}',
            status: a['status'],
          ),
        ),
      ]),
    ];
  }

  List<Widget> _patientSection(Map<String, dynamic> user, Map<String, dynamic> patient) {
    final requests = (user['recent_requests'] as List?) ?? [];
    return [
      _section('Patient Profile', Icons.personal_injury_outlined, [
        _row('Emergency contact', patient['emergency_contact_name']),
        _row('Emergency phone', patient['emergency_contact_phone']),
        _row('Medical conditions', patient['medical_conditions']),
        _row('Medications', patient['current_medications']),
        _row('Allergies', patient['allergies']),
        if (patient['weight'] != null) _row('Weight', '${patient['weight']} kg'),
        if (patient['height'] != null) _row('Height', '${patient['height']} cm'),
        _subheading('Blood requests'),
        if (requests.isEmpty) _emptyLine('No blood requests'),
        ...requests.map(
          (r) => _activityTile(
            icon: r['is_emergency'] == true ? Icons.emergency : Icons.assignment_outlined,
            title: '${r['quantity']} unit(s) • ${r['blood_group'] ?? ''} • ${r['urgency'] ?? ''}',
            subtitle: '${r['hospital_name'] ?? 'No hospital'} • ${adminFormatDate(r['created_at'])}',
            status: r['status'],
          ),
        ),
      ]),
    ];
  }

  Widget _paymentsSection(Map<String, dynamic> user) {
    final payments = (user['recent_payments'] as List?) ?? [];
    final total = (user['payments_total'] as num?) ?? 0;
    return _section('Payments', Icons.payments_outlined, [
      _row('Total paid', '${total.toStringAsFixed(0)} FCFA'),
      if (payments.isEmpty) _emptyLine('No payments'),
      ...payments.map(
        (p) => _activityTile(
          icon: Icons.receipt_long_outlined,
          title: '${(p['amount'] as num? ?? 0).toStringAsFixed(0)} FCFA • ${p['payment_type'] ?? ''}',
          subtitle: '${p['payment_method'] ?? ''} • ${adminFormatDate(p['created_at'])}',
          status: p['status'],
        ),
      ),
    ]);
  }

  Widget _loginsSection(Map<String, dynamic> user) {
    final logins = (user['recent_logins'] as List?) ?? [];
    return _section('Recent Logins', Icons.history, [
      if (logins.isEmpty) _emptyLine('No login history'),
      ...logins.map(
        (l) => _activityTile(
          icon: Icons.devices_outlined,
          title: l['device_name'] ?? 'Unknown device',
          subtitle: '${l['ip_address'] ?? ''} • ${adminFormatDate(l['login_time'])}',
          status: l['status'],
        ),
      ),
    ]);
  }
}
