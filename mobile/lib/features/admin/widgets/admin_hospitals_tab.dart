import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/repositories/admin_repository.dart';
import '../screens/admin_user_detail_screen.dart';

enum _HospitalState { active, expired, deactivated }

_HospitalState _stateOf(Map<String, dynamic> h) {
  if (h['is_active'] == false || h['subscription_status'] == 'DEACTIVATED') return _HospitalState.deactivated;
  if (h['is_subscription_active'] == true) return _HospitalState.active;
  return _HospitalState.expired;
}

Color _stateColor(_HospitalState s) => switch (s) {
      _HospitalState.active => AppTheme.success,
      _HospitalState.expired => AppTheme.warning,
      _HospitalState.deactivated => AppTheme.error,
    };

String _stateLabel(_HospitalState s) => switch (s) {
      _HospitalState.active => 'Active',
      _HospitalState.expired => 'Expired',
      _HospitalState.deactivated => 'Deactivated',
    };

String _formatDate(dynamic value) {
  if (value == null) return '—';
  final date = DateTime.tryParse(value.toString());
  if (date == null) return '—';
  final d = date.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class AdminHospitalsTab extends ConsumerStatefulWidget {
  const AdminHospitalsTab({super.key});

  @override
  ConsumerState<AdminHospitalsTab> createState() => _AdminHospitalsTabState();
}

class _AdminHospitalsTabState extends ConsumerState<AdminHospitalsTab> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _hospitals = [];
  bool _loading = true;
  String? _error;
  _HospitalState? _filter;

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _hospitals.isEmpty;
      _error = null;
    });
    try {
      final data = await _repo.getAllHospitals(search: _searchController.text.trim());
      if (!mounted) return;
      setState(() {
        _hospitals = data.cast<Map<String, dynamic>>();
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppTheme.error : null),
    );
  }

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    try {
      await action();
      _toast(successMessage);
      await _load();
    } catch (e) {
      _toast(AdminRepository.errorMessage(e), error: true);
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
            style: ElevatedButton.styleFrom(backgroundColor: destructive ? AppTheme.error : AppTheme.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ------------------------------------------------------------ Actions

  Future<void> _toggleAccess(Map<String, dynamic> h) async {
    final isActive = h['is_active'] != false && h['subscription_status'] != 'DEACTIVATED';
    final ok = await _confirm(
      isActive ? 'Deactivate Hospital Access?' : 'Activate Hospital Access?',
      isActive
          ? 'Deactivating "${h['name']}" will hide it from users and block its staff until it is reactivated.'
          : 'Activate access for "${h['name']}"? If the subscription has expired, it will be extended by 30 days '
              'and all users will be notified.',
      confirmLabel: isActive ? 'Deactivate' : 'Activate',
      destructive: isActive,
    );
    if (!ok) return;
    await _run(() => _repo.setHospitalActive(h['id'], !isActive), '${h['name']} ${isActive ? 'deactivated' : 'activated'}');
  }

  Future<void> _grantMonths(Map<String, dynamic> h) async {
    int months = 1;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Grant Subscription'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manually extend "${h['name']}" (e.g. for an offline payment).'),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: months > 1 ? () => setLocal(() => months--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$months month${months > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),),
                  IconButton(
                    onPressed: months < 24 ? () => setLocal(() => months++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, months), child: const Text('Grant')),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _run(() => _repo.extendHospitalSubscription(h['id'], result),
        'Granted $result month${result > 1 ? 's' : ''} to ${h['name']}',);
  }

  Future<void> _delete(Map<String, dynamic> h) async {
    final ok = await _confirm(
      'Delete Hospital',
      'Permanently delete "${h['name']}"? Its staff links, inventory and related records will be removed. '
          'This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await _run(() => _repo.deleteHospital(h['id']), '${h['name']} deleted');
  }

  Future<void> _openForm({Map<String, dynamic>? hospital}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => _HospitalFormSheet(repo: _repo, hospital: hospital),
    );
    if (saved == true) {
      _toast(hospital == null ? 'Hospital created' : 'Hospital updated');
      await _load();
    }
  }

  Future<void> _openStaff(Map<String, dynamic> h) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => _HospitalStaffSheet(repo: _repo, hospital: h),
    );
    // Staff count may have changed
    await _load();
  }

  void _openDetails(Map<String, dynamic> h) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => _HospitalDetailsSheet(
        repo: _repo,
        hospital: h,
        onAction: (action) {
          Navigator.pop(ctx);
          switch (action) {
            case 'edit':
              _openForm(hospital: h);
            case 'staff':
              _openStaff(h);
            case 'grant':
              _grantMonths(h);
            case 'toggle':
              _toggleAccess(h);
            case 'invoices':
              Navigator.of(context).pushNamed('/hospital-subscription-history', arguments: {'hospitalId': h['id']});
            case 'delete':
              _delete(h);
          }
        },
      ),
    );
  }

  // ----------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final counts = {for (final s in _HospitalState.values) s: 0};
    for (final h in _hospitals) {
      counts[_stateOf(h)] = counts[_stateOf(h)]! + 1;
    }
    final visible = _filter == null ? _hospitals : _hospitals.where((h) => _stateOf(h) == _filter).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search name, city, region',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _load();
                            },
                          ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              IconButton.filled(
                tooltip: 'Add hospital',
                style: IconButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                onPressed: _openForm,
                icon: const Icon(Icons.add_business, color: Colors.white),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
          child: Row(
            children: [
              _summaryTile('All', _hospitals.length, AppTheme.accentColor, null),
              ..._HospitalState.values.map((s) => _summaryTile(_stateLabel(s), counts[s]!, _stateColor(s), s)),
            ],
          ),
        ),
        Expanded(child: _buildList(visible)),
      ],
    );
  }

  Widget _summaryTile(String label, int count, Color color, _HospitalState? state) {
    final selected = _filter == state;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = state),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 3.w),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: color.withOpacity(selected ? 0.18 : 0.06),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
          ),
          child: Column(
            children: [
              Text('$count', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: color)),
              Text(label, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> hospitals) {
    if (_loading) return const Center(child: CircularProgressIndicator());
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

    return RefreshIndicator(
      onRefresh: _load,
      child: hospitals.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 80.h),
                Icon(Icons.local_hospital_outlined, size: 56.w, color: Colors.grey.shade400),
                SizedBox(height: 8.h),
                const Center(child: Text('No hospitals found', style: TextStyle(color: Colors.grey))),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 96.h),
              itemCount: hospitals.length,
              itemBuilder: (context, index) => _buildHospitalCard(hospitals[index]),
            ),
    );
  }

  Widget _buildHospitalCard(Map<String, dynamic> h) {
    final state = _stateOf(h);
    final color = _stateColor(state);
    final isActive = state != _HospitalState.deactivated;

    return Card(
      margin: EdgeInsets.only(bottom: 14.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => _openDetails(h),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(Icons.local_hospital, color: color),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h['name'] ?? 'Unknown Hospital',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),),
                        SizedBox(height: 2.h),
                        Text(
                          [h['city'], h['region']].where((e) => e != null && e.toString().isNotEmpty).join(', '),
                          style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12.r)),
                    child: Text(_stateLabel(state),
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: color),),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'edit':
                          _openForm(hospital: h);
                        case 'staff':
                          _openStaff(h);
                        case 'grant':
                          _grantMonths(h);
                        case 'delete':
                          _delete(h);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit details'))),
                      PopupMenuItem(value: 'staff', child: ListTile(leading: Icon(Icons.groups_outlined), title: Text('Manage staff'))),
                      PopupMenuItem(value: 'grant', child: ListTile(leading: Icon(Icons.more_time), title: Text('Grant subscription'))),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: AppTheme.error),
                          title: Text('Delete', style: TextStyle(color: AppTheme.error)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Wrap(
                spacing: 14.w,
                runSpacing: 6.h,
                children: [
                  _info(Icons.groups_outlined, '${h['staff_count'] ?? 0} staff'),
                  if ((h['phone_number'] ?? '').toString().isNotEmpty) _info(Icons.phone_outlined, h['phone_number']),
                  if (h['has_blood_bank'] == true) _info(Icons.bloodtype_outlined, 'Blood bank'),
                  if (h['has_emergency_services'] == true) _info(Icons.emergency_outlined, 'Emergency'),
                ],
              ),
              SizedBox(height: 6.h),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    h['subscription_end_date'] != null
                        ? '${state == _HospitalState.active ? 'Valid until' : 'Ended'}: ${_formatDate(h['subscription_end_date'])}'
                        : 'No subscription yet',
                    style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                  ),
                  Text('Rate: 25 FCFA/mo',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pushNamed('/hospital-subscription-history', arguments: {'hospitalId': h['id']}),
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Invoices', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _toggleAccess(h),
                      style: ElevatedButton.styleFrom(backgroundColor: isActive ? AppTheme.error : AppTheme.success),
                      icon: Icon(isActive ? Icons.block : Icons.check_circle, size: 16),
                      label: Text(isActive ? 'Deactivate' : 'Activate', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: AppTheme.onSurfaceVariant),
          SizedBox(width: 4.w),
          Text(text, style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant)),
        ],
      );
}

/// Details sheet that loads live figures (blood units, pending requests) for a hospital.
class _HospitalDetailsSheet extends StatelessWidget {
  final AdminRepository repo;
  final Map<String, dynamic> hospital;
  final void Function(String action) onAction;

  const _HospitalDetailsSheet({required this.repo, required this.hospital, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final state = _stateOf(hospital);
    final isActive = state != _HospitalState.deactivated;

    Widget row(IconData icon, String label, dynamic value) => Padding(
          padding: EdgeInsets.symmetric(vertical: 5.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18.w, color: AppTheme.onSurfaceVariant),
              SizedBox(width: 10.w),
              SizedBox(width: 95.w, child: Text(label, style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant))),
              Expanded(
                child: Text(
                  (value == null || value.toString().isEmpty) ? '—' : value.toString(),
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: Text(hospital['name'] ?? '', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _stateColor(state).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(_stateLabel(state),
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: _stateColor(state)),),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            FutureBuilder<Map<String, dynamic>>(
              future: repo.getHospital(hospital['id']),
              builder: (context, snap) {
                final d = snap.data;
                Widget stat(String label, String value, Color color, IconData icon) => Expanded(
                      child: Container(
                        padding: EdgeInsets.all(10.w),
                        margin: EdgeInsets.symmetric(horizontal: 3.w),
                        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12.r)),
                        child: Column(
                          children: [
                            Icon(icon, color: color, size: 20.w),
                            SizedBox(height: 4.h),
                            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: color)),
                            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.sp)),
                          ],
                        ),
                      ),
                    );
                final loading = snap.connectionState == ConnectionState.waiting;
                return Row(
                  children: [
                    stat('Staff', loading ? '…' : '${d?['staff_count'] ?? hospital['staff_count'] ?? 0}',
                        AppTheme.accentColor, Icons.groups,),
                    stat('Blood units', loading ? '…' : '${d?['total_blood_units'] ?? '—'}', AppTheme.primaryColor,
                        Icons.bloodtype,),
                    stat('Pending requests', loading ? '…' : '${d?['pending_requests'] ?? '—'}', AppTheme.warning,
                        Icons.assignment,),
                  ],
                );
              },
            ),
            SizedBox(height: 14.h),
            const Divider(),
            row(Icons.location_on_outlined, 'Address', hospital['address']),
            row(Icons.map_outlined, 'City / Region',
                [hospital['city'], hospital['region']].where((e) => e != null && e.toString().isNotEmpty).join(', '),),
            row(Icons.phone_outlined, 'Phone', hospital['phone_number']),
            row(Icons.email_outlined, 'Email', hospital['email']),
            row(Icons.schedule, 'Opening hours', hospital['opening_hours']),
            row(Icons.medical_services_outlined, 'Services', hospital['services']),
            row(Icons.gps_fixed, 'Coordinates',
                hospital['latitude'] != null ? '${hospital['latitude']}, ${hospital['longitude']}' : null,),
            row(Icons.event_available, 'Subscription', _formatDate(hospital['subscription_end_date'])),
            row(Icons.calendar_today_outlined, 'Registered', _formatDate(hospital['created_at'])),
            if ((hospital['description'] ?? '').toString().isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(hospital['description'], style: TextStyle(fontSize: 13.sp, color: AppTheme.onSurfaceVariant)),
            ],
            const Divider(),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                OutlinedButton.icon(
                    onPressed: () => onAction('edit'), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit'),),
                OutlinedButton.icon(
                    onPressed: () => onAction('staff'), icon: const Icon(Icons.groups_outlined, size: 18), label: const Text('Staff'),),
                OutlinedButton.icon(
                    onPressed: () => onAction('invoices'),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Invoices'),),
                OutlinedButton.icon(
                    onPressed: () => onAction('grant'),
                    icon: const Icon(Icons.more_time, size: 18),
                    label: const Text('Grant months'),),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: isActive ? AppTheme.warning : AppTheme.success),
                  onPressed: () => onAction('toggle'),
                  icon: Icon(isActive ? Icons.block : Icons.check_circle, size: 18),
                  label: Text(isActive ? 'Deactivate' : 'Activate'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                  onPressed: () => onAction('delete'),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lists a hospital's staff and lets the admin assign or remove members.
class _HospitalStaffSheet extends StatefulWidget {
  final AdminRepository repo;
  final Map<String, dynamic> hospital;

  const _HospitalStaffSheet({required this.repo, required this.hospital});

  @override
  State<_HospitalStaffSheet> createState() => _HospitalStaffSheetState();
}

class _HospitalStaffSheetState extends State<_HospitalStaffSheet> {
  List<Map<String, dynamic>>? _staff;
  String? _error;

  int get _hospitalId => widget.hospital['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final staff = await widget.repo.getHospitalStaff(_hospitalId);
      if (mounted) setState(() => _staff = staff);
    } catch (e) {
      if (mounted) setState(() => _error = AdminRepository.errorMessage(e));
    }
  }

  void _toast(String msg, {bool error = false}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppTheme.error : null));

  Future<void> _remove(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff Member'),
        content: Text('Remove ${s['full_name']} from ${widget.hospital['name']}? Their user account is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo.removeHospitalStaff(_hospitalId, s['id']);
      _toast('${s['full_name']} removed');
      _load();
    } catch (e) {
      _toast(AdminRepository.errorMessage(e), error: true);
    }
  }

  Future<void> _assign() async {
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _UserPickerDialog(repo: widget.repo, excludeIds: _staff?.map((s) => s['user_id'] as int).toSet() ?? {}),
    );
    if (picked == null) return;
    try {
      await widget.repo.assignHospitalStaff(_hospitalId, picked['user']['id'], position: picked['position']);
      _toast('${picked['user']['full_name']} assigned to ${widget.hospital['name']}');
      _load();
    } catch (e) {
      _toast(AdminRepository.errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scroll) => Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Staff Members', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                        Text(widget.hospital['name'] ?? '',
                            style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _assign,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Assign'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!))
                  : _staff == null
                      ? const Center(child: CircularProgressIndicator())
                      : _staff!.isEmpty
                          ? const Center(child: Text('No staff assigned yet', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              controller: scroll,
                              itemCount: _staff!.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final s = _staff![i];
                                return ListTile(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AdminUserDetailScreen(userId: s['user_id'] as int),
                                    ),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.accentColor.withOpacity(s['is_active'] == true ? 1 : 0.4),
                                    child: Text(
                                      (s['full_name'] ?? '?').toString().isEmpty ? '?' : s['full_name'][0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(s['full_name'] ?? ''),
                                  subtitle: Text([s['position'], s['email']].where((e) => e != null).join(' • ')),
                                  trailing: IconButton(
                                    tooltip: 'Remove',
                                    icon: const Icon(Icons.person_remove_outlined, color: AppTheme.error),
                                    onPressed: () => _remove(s),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable user picker returning {'user': Map, 'position': String}.
class _UserPickerDialog extends StatefulWidget {
  final AdminRepository repo;
  final Set<int> excludeIds;

  const _UserPickerDialog({required this.repo, required this.excludeIds});

  @override
  State<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<_UserPickerDialog> {
  final _search = TextEditingController();
  final _position = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await widget.repo.getUsers(search: _search.text.trim(), isActive: true);
      if (!mounted) return;
      setState(() {
        _results = users.where((u) => !widget.excludeIds.contains(u['id']) && u['role'] != 'system_admin').toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Staff Member'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420.h,
        child: Column(
          children: [
            TextField(
              controller: _search,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _load);
              },
              decoration: const InputDecoration(hintText: 'Search users', prefixIcon: Icon(Icons.search), isDense: true),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('No users found'))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, i) {
                            final u = _results[i];
                            final selected = _selected?['id'] == u['id'];
                            return ListTile(
                              dense: true,
                              selected: selected,
                              selectedTileColor: AppTheme.primaryColor.withOpacity(0.08),
                              leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: selected ? AppTheme.primaryColor : null,),
                              title: Text(u['full_name'] ?? ''),
                              subtitle: Text(
                                [u['email'], if (u['hospital_name'] != null) 'currently at ${u['hospital_name']}'].join(' • '),
                              ),
                              onTap: () => setState(() => _selected = u),
                            );
                          },
                        ),
            ),
            TextField(
              controller: _position,
              decoration: const InputDecoration(labelText: 'Position (optional)', prefixIcon: Icon(Icons.work_outline), isDense: true),
            ),
            if (_selected != null && _selected!['role'] != 'hospital_staff')
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(
                  'This user\'s role will be changed to Hospital Staff.',
                  style: TextStyle(fontSize: 11.sp, color: AppTheme.warning),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, {'user': _selected, 'position': _position.text.trim()}),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

/// Bottom sheet form to create or edit a hospital.
class _HospitalFormSheet extends StatefulWidget {
  final AdminRepository repo;
  final Map<String, dynamic>? hospital;

  const _HospitalFormSheet({required this.repo, this.hospital});

  @override
  State<_HospitalFormSheet> createState() => _HospitalFormSheetState();
}

class _HospitalFormSheetState extends State<_HospitalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late bool _hasBloodBank;
  late bool _hasEmergency;
  bool _saving = false;

  bool get _isEdit => widget.hospital != null;

  static const _textFields = [
    'name', 'address', 'city', 'region', 'phone_number', 'email',
    'opening_hours', 'services', 'description', 'latitude', 'longitude',
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.hospital ?? {};
    _c = {for (final f in _textFields) f: TextEditingController(text: h[f]?.toString() ?? '')};
    if (!_isEdit) {
      _c['opening_hours']!.text = '24/7 Emergency & Blood Bank';
      _c['services']!.text = 'Blood Bank, Emergency Care, Transfusion, ICU, Lab Testing';
    }
    _hasBloodBank = h['has_blood_bank'] ?? true;
    _hasEmergency = h['has_emergency_services'] ?? true;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = <String, dynamic>{
      for (final f in _textFields) f: _c[f]!.text.trim().isEmpty ? null : _c[f]!.text.trim(),
      'latitude': double.tryParse(_c['latitude']!.text.trim()),
      'longitude': double.tryParse(_c['longitude']!.text.trim()),
      'has_blood_bank': _hasBloodBank,
      'has_emergency_services': _hasEmergency,
    };
    // Non-nullable text fields on the backend: send empty strings instead of null.
    for (final f in ['opening_hours', 'services']) {
      data[f] ??= '';
    }
    try {
      if (_isEdit) {
        await widget.repo.updateHospital(widget.hospital!['id'], data);
      } else {
        await widget.repo.createHospital(data);
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

  Widget _field(String key, String label, IconData icon,
      {bool required = false, TextInputType? keyboard, int maxLines = 1, String? Function(String?)? validator,}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: TextFormField(
        controller: _c[key],
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
        validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null),
      ),
    );
  }

  String? _coordinate(String? v, double limit) {
    if (v == null || v.trim().isEmpty) return null;
    final d = double.tryParse(v.trim());
    if (d == null || d.abs() > limit) return 'Invalid';
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                Text(_isEdit ? 'Edit Hospital' : 'Register New Hospital',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),),
                SizedBox(height: 16.h),
                _field('name', 'Hospital name', Icons.local_hospital_outlined, required: true),
                _field('address', 'Address', Icons.location_on_outlined, required: true),
                Row(
                  children: [
                    Expanded(child: _field('city', 'City', Icons.location_city, required: true)),
                    SizedBox(width: 10.w),
                    Expanded(child: _field('region', 'Region', Icons.map_outlined, required: true)),
                  ],
                ),
                _field('phone_number', 'Phone number', Icons.phone_outlined,
                    required: true, keyboard: TextInputType.phone,),
                _field('email', 'Email (optional)', Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.trim().isEmpty || v.contains('@')) ? null : 'Invalid email',),
                Row(
                  children: [
                    Expanded(
                      child: _field('latitude', 'Latitude', Icons.gps_fixed,
                          keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          validator: (v) => _coordinate(v, 90),),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _field('longitude', 'Longitude', Icons.gps_fixed,
                          keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          validator: (v) => _coordinate(v, 180),),
                    ),
                  ],
                ),
                _field('opening_hours', 'Opening hours', Icons.schedule),
                _field('services', 'Services (comma separated)', Icons.medical_services_outlined, maxLines: 2),
                _field('description', 'Description (optional)', Icons.notes, maxLines: 3),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Has blood bank'),
                  value: _hasBloodBank,
                  onChanged: (v) => setState(() => _hasBloodBank = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Has emergency services'),
                  value: _hasEmergency,
                  onChanged: (v) => setState(() => _hasEmergency = v),
                ),
                SizedBox(height: 12.h),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h)),
                  child: _saving
                      ? SizedBox(height: 18.h, width: 18.h, child: const CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEdit ? 'Save Changes' : 'Create Hospital'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
