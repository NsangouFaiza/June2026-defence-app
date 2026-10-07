import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/admin_repository.dart';

const Map<String, String> kAdminRoleLabels = {
  'donor': 'Donor',
  'patient': 'Patient',
  'hospital_staff': 'Hospital Staff',
  'blood_bank_admin': 'Blood Bank Admin',
  'system_admin': 'System Admin',
};

Color adminRoleColor(String? role) {
  switch (role) {
    case 'donor':
      return AppTheme.success;
    case 'patient':
      return AppTheme.warning;
    case 'hospital_staff':
      return AppTheme.accentColor;
    case 'blood_bank_admin':
      return Colors.purple;
    case 'system_admin':
      return AppTheme.error;
    default:
      return Colors.grey;
  }
}

String adminFormatDate(dynamic value) {
  if (value == null) return '—';
  final date = DateTime.tryParse(value.toString());
  if (date == null) return '—';
  final d = date.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class AdminUserAvatar extends StatelessWidget {
  final Map<String, dynamic> user;
  final double radius;

  const AdminUserAvatar({required this.user, required this.radius});

  @override
  Widget build(BuildContext context) {
    final name = (user['full_name'] ?? user['email'] ?? '?').toString().trim();
    final color = adminRoleColor(user['role']);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(user['is_active'] == true ? 1 : 0.4),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.8),
      ),
    );
  }
}

class AdminChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AdminChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11.sp, color: color), SizedBox(width: 3.w)],
          Text(label, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

/// Bottom sheet form used to create a new user or edit an existing one.
class AdminUserFormSheet extends StatefulWidget {
  final AdminRepository repo;
  final Map<String, dynamic>? user;

  const AdminUserFormSheet({required this.repo, this.user});

  @override
  State<AdminUserFormSheet> createState() => AdminUserFormSheetState();
}

class AdminUserFormSheetState extends State<AdminUserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late final TextEditingController _region;
  final _password = TextEditingController();
  late String _role;
  String? _bloodGroup;
  int? _hospitalId;
  List<dynamic> _hospitals = [];
  bool _saving = false;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user ?? {};
    _name = TextEditingController(text: u['full_name'] ?? '');
    _email = TextEditingController(text: u['email'] ?? '');
    _phone = TextEditingController(text: u['phone_number'] ?? '');
    _city = TextEditingController(text: u['city'] ?? '');
    _region = TextEditingController(text: u['region'] ?? '');
    _role = u['role'] ?? 'donor';
    _bloodGroup = u['blood_group'];
    if (!_isEdit) {
      widget.repo.getAllHospitals().then((h) {
        if (mounted) setState(() => _hospitals = h);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _city, _region, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'full_name': _name.text.trim(),
        'phone_number': _phone.text.trim(),
        'city': _city.text.trim(),
        'region': _region.text.trim(),
        'blood_group': _bloodGroup,
      };
      if (_isEdit) {
        await widget.repo.updateUser(widget.user!['id'], data);
      } else {
        await widget.repo.createUser({
          ...data,
          'email': _email.text.trim(),
          'password': _password.text,
          'role': _role,
          if (_role == 'hospital_staff' && _hospitalId != null) 'hospital_id': _hospitalId,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AdminRepository.errorMessage(e)), backgroundColor: AppTheme.error),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      );

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(height: 12.h);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_isEdit ? 'Edit User' : 'Add New User',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),),
                SizedBox(height: 16.h),
                TextFormField(controller: _name, decoration: _decoration('Full name', Icons.person_outline), validator: _required),
                gap,
                TextFormField(
                  controller: _email,
                  enabled: !_isEdit,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration('Email', Icons.email_outlined),
                  validator: (v) => _isEdit || (v != null && v.contains('@')) ? null : 'Enter a valid email',
                ),
                gap,
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration('Phone number', Icons.phone_outlined),
                  validator: _required,
                ),
                if (!_isEdit) ...[
                  gap,
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: _decoration('Password', Icons.lock_outline),
                    validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
                  ),
                  gap,
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: _decoration('Role', Icons.badge_outlined),
                    items: kAdminRoleLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _role = v ?? 'donor'),
                  ),
                  if (_role == 'hospital_staff') ...[
                    gap,
                    DropdownButtonFormField<int>(
                      value: _hospitalId,
                      isExpanded: true,
                      decoration: _decoration('Assign to hospital (optional)', Icons.local_hospital_outlined),
                      items: _hospitals
                          .map((h) => DropdownMenuItem<int>(value: h['id'] as int, child: Text(h['name'] ?? '')))
                          .toList(),
                      onChanged: (v) => setState(() => _hospitalId = v),
                    ),
                  ],
                ],
                gap,
                DropdownButtonFormField<String?>(
                  value: _bloodGroup,
                  decoration: _decoration('Blood group', Icons.bloodtype_outlined),
                  items: [null, 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g ?? 'Unknown')))
                      .toList(),
                  onChanged: (v) => setState(() => _bloodGroup = v),
                ),
                gap,
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _city, decoration: _decoration('City', Icons.location_city))),
                    SizedBox(width: 10.w),
                    Expanded(child: TextFormField(controller: _region, decoration: _decoration('Region', Icons.map_outlined))),
                  ],
                ),
                SizedBox(height: 20.h),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h)),
                  child: _saving
                      ? SizedBox(height: 18.h, width: 18.h, child: const CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEdit ? 'Save Changes' : 'Create User'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Admin actions on a user, shared by the users list and the user details screen.
/// Each action returns true when the user was changed on the server.
class AdminUserActions {
  final BuildContext context;
  final AdminRepository repo;

  AdminUserActions(this.context, this.repo);

  void _toast(String message, {bool error = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppTheme.error : null),
    );
  }

  Future<bool> _run(Future<void> Function() action, String successMessage) async {
    try {
      await action();
      _toast(successMessage);
      return true;
    } catch (e) {
      _toast(AdminRepository.errorMessage(e), error: true);
      return false;
    }
  }

  Future<bool> _confirm(String title, String message, {String confirmLabel = 'Confirm', bool destructive = false}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: destructive ? ElevatedButton.styleFrom(backgroundColor: AppTheme.error) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> toggleActive(Map<String, dynamic> user) async {
    final isActive = user['is_active'] == true;
    final name = user['full_name'] ?? user['email'];
    if (isActive) {
      final ok = await _confirm(
        'Suspend User',
        'Suspend "$name"? They will not be able to log in until reactivated.',
        confirmLabel: 'Suspend',
        destructive: true,
      );
      if (!ok) return false;
      return _run(() => repo.suspendUser(user['id']), '$name suspended');
    }
    return _run(() => repo.activateUser(user['id']), '$name activated');
  }

  Future<bool> delete(Map<String, dynamic> user) async {
    final name = user['full_name'] ?? user['email'];
    final ok = await _confirm(
      'Delete User',
      'Permanently delete "$name" and all of their data? This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return false;
    return _run(() => repo.deleteUser(user['id']), '$name deleted');
  }

  Future<bool> changeRole(Map<String, dynamic> user) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Change Role'),
        children: kAdminRoleLabels.entries
            .map(
              (e) => RadioListTile<String>(
                value: e.key,
                groupValue: user['role'] as String?,
                title: Text(e.value),
                activeColor: adminRoleColor(e.key),
                onChanged: (v) => Navigator.pop(ctx, v),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || selected == user['role']) return false;
    return _run(
      () => repo.updateUser(user['id'], {'role': selected}),
      'Role changed to ${kAdminRoleLabels[selected]}',
    );
  }

  Future<bool> resetPassword(Map<String, dynamic> user) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(labelText: 'New password for ${user['full_name']}'),
            validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null) return false;
    return _run(() => repo.resetUserPassword(user['id'], password), 'Password updated');
  }

  /// Opens the create (user == null) or edit form.
  Future<bool> openForm({Map<String, dynamic>? user}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => AdminUserFormSheet(repo: repo, user: user),
    );
    if (saved == true) {
      _toast(user == null ? 'User created' : 'User updated');
      return true;
    }
    return false;
  }
}
