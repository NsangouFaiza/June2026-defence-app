import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/repositories/admin_repository.dart';
import '../screens/admin_user_detail_screen.dart';
import 'admin_user_common.dart';

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  String? _roleFilter;
  bool? _activeFilter;

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
      _loading = _users.isEmpty;
      _error = null;
    });
    try {
      final users = await _repo.getUsers(
        search: _searchController.text.trim(),
        role: _roleFilter,
        isActive: _activeFilter,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
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

  AdminUserActions get _actions => AdminUserActions(context, _repo);

  /// Runs an admin action and reloads the list if it changed anything.
  Future<void> _act(Future<bool> Function(AdminUserActions a) action) async {
    if (await action(_actions)) await _load();
  }

  Future<void> _openDetails(Map<String, dynamic> user) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminUserDetailScreen(userId: user['id'] as int, initialUser: user)),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUserId = ref.watch(currentUserProvider).value?.id;
    final activeCount = _users.where((u) => u['is_active'] == true).length;

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
                    hintText: 'Search name, email, phone, city',
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
              PopupMenuButton<bool?>(
                tooltip: 'Status filter',
                icon: Icon(Icons.filter_list, color: _activeFilter == null ? null : AppTheme.primaryColor),
                onSelected: (v) {
                  setState(() => _activeFilter = v);
                  _load();
                },
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(value: null, checked: _activeFilter == null, child: const Text('All statuses')),
                  CheckedPopupMenuItem(value: true, checked: _activeFilter == true, child: const Text('Active only')),
                  CheckedPopupMenuItem(value: false, checked: _activeFilter == false, child: const Text('Suspended only')),
                ],
              ),
              IconButton.filled(
                tooltip: 'Add user',
                style: IconButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                onPressed: () => _act((a) => a.openForm()),
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48.h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            children: [
              _filterChip('All', null),
              ...kAdminRoleLabels.entries.map((e) => _filterChip(e.value, e.key)),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Text('${_users.length} users', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
              SizedBox(width: 12.w),
              Text('$activeCount active', style: TextStyle(fontSize: 12.sp, color: AppTheme.success)),
              SizedBox(width: 12.w),
              Text('${_users.length - activeCount} suspended', style: TextStyle(fontSize: 12.sp, color: AppTheme.error)),
            ],
          ),
        ),
        Expanded(child: _buildList(currentUserId)),
      ],
    );
  }

  Widget _filterChip(String label, String? role) {
    final selected = _roleFilter == role;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12.sp)),
        selected: selected,
        selectedColor: (role == null ? AppTheme.primaryColor : adminRoleColor(role)).withOpacity(0.18),
        onSelected: (_) {
          setState(() => _roleFilter = role);
          _load();
        },
      ),
    );
  }

  Widget _buildList(int? currentUserId) {
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
      child: _users.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 80.h),
                Icon(Icons.people_outline, size: 56.w, color: Colors.grey.shade400),
                SizedBox(height: 8.h),
                const Center(child: Text('No users match your filters', style: TextStyle(color: Colors.grey))),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 96.h),
              itemCount: _users.length,
              itemBuilder: (context, index) => _buildUserCard(_users[index], _users[index]['id'] == currentUserId),
            ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isSelf) {
    final role = user['role'] as String?;
    final isActive = user['is_active'] == true;

    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () => _openDetails(user),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              AdminUserAvatar(user: user, radius: 22.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user['full_name'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                          ),
                        ),
                        if (isSelf)
                          Padding(
                            padding: EdgeInsets.only(left: 6.w),
                            child: Text('(you)', style: TextStyle(fontSize: 11.sp, color: AppTheme.onSurfaceVariant)),
                          ),
                      ],
                    ),
                    Text(
                      user['email'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                    ),
                    SizedBox(height: 6.h),
                    Wrap(spacing: 6.w, runSpacing: 4.h, children: [
                      AdminChip(label: kAdminRoleLabels[role] ?? role ?? '', color: adminRoleColor(role)),
                      if (!isActive) const AdminChip(label: 'Suspended', color: AppTheme.error),
                      if (user['hospital_name'] != null)
                        AdminChip(label: user['hospital_name'], color: Colors.blueGrey, icon: Icons.local_hospital),
                    ],),
                  ],
                ),
              ),
              if (!isSelf)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        _act((a) => a.openForm(user: user));
                      case 'role':
                        _act((a) => a.changeRole(user));
                      case 'toggle':
                        _act((a) => a.toggleActive(user));
                      case 'password':
                        _act((a) => a.resetPassword(user));
                      case 'delete':
                        _act((a) => a.delete(user));
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                    const PopupMenuItem(value: 'role', child: ListTile(leading: Icon(Icons.badge_outlined), title: Text('Change role'))),
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        leading: Icon(isActive ? Icons.block : Icons.check_circle,
                            color: isActive ? AppTheme.warning : AppTheme.success,),
                        title: Text(isActive ? 'Suspend' : 'Activate'),
                      ),
                    ),
                    const PopupMenuItem(value: 'password', child: ListTile(leading: Icon(Icons.lock_reset), title: Text('Reset password'))),
                    const PopupMenuItem(
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
        ),
      ),
    );
  }
}

