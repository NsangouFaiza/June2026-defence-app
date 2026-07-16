import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/inventory_repository.dart';
import '../../../../data/models/blood_inventory_model.dart';
import '../../../../core/constants/app_constants.dart';

class AvailableBloodPacksScreen extends ConsumerStatefulWidget {
  const AvailableBloodPacksScreen({super.key});

  @override
  ConsumerState<AvailableBloodPacksScreen> createState() => _AvailableBloodPacksScreenState();
}

class _AvailableBloodPacksScreenState extends ConsumerState<AvailableBloodPacksScreen> {
  List<BloodInventoryModel> _allInventory = [];
  List<BloodInventoryModel> _filteredInventory = [];
  Map<String, int> _categoryTotals = {};
  bool _isLoading = true;
  String _selectedCategory = ''; // Empty string means 'All'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    try {
      final inventoryRepo = ref.read(inventoryRepositoryProvider);
      final inventory = await inventoryRepo.getInventory();
      
      // Filter for 'available' blood packs
      final availablePacks = inventory.where((item) => item.status.toLowerCase() == 'available').toList();

      if (mounted) {
        setState(() {
          _allInventory = availablePacks;
          _calculateCategoryTotals(availablePacks);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateCategoryTotals(List<BloodInventoryModel> items) {
    // Initialize totals for all blood groups
    final totals = <String, int>{};
    for (final bg in AppConstants.bloodGroups) {
      totals[bg] = 0;
    }

    // Sum quantities
    for (final item in items) {
      if (totals.containsKey(item.bloodGroup)) {
        totals[item.bloodGroup] = totals[item.bloodGroup]! + item.quantity;
      } else {
        totals[item.bloodGroup] = item.quantity;
      }
    }
    _categoryTotals = totals;
  }

  void _applyFilters() {
    List<BloodInventoryModel> temp = _allInventory;

    // Filter by selected blood group category
    if (_selectedCategory.isNotEmpty) {
      temp = temp.where((item) => item.bloodGroup == _selectedCategory).toList();
    }

    // Filter by search query (hospital name, city, etc.)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      temp = temp.where((item) {
        final hospital = item.hospitalName.toLowerCase();
        return hospital.contains(query);
      }).toList();
    }

    setState(() {
      _filteredInventory = temp;
    });
  }

  void _selectCategory(String category) {
    setState(() {
      if (_selectedCategory == category) {
        _selectedCategory = ''; // Toggle off
      } else {
        _selectedCategory = category;
      }
      _applyFilters();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  int get _totalUnits => _allInventory.fold<int>(0, (sum, item) => sum + item.quantity);

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Available Blood Packs'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Total Statistics Card
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(16.w),
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bloodtype,
                          color: Colors.white,
                          size: 32.w,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Available Inventory',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '$_totalUnits Units',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Categories (Classification Grid)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Classified by Categories',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),

                // Horizontally Scrollable Categories List
                SizedBox(
                  height: 96.h,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    scrollDirection: Axis.horizontal,
                    itemCount: AppConstants.bloodGroups.length,
                    itemBuilder: (context, index) {
                      final group = AppConstants.bloodGroups[index];
                      final total = _categoryTotals[group] ?? 0;
                      final isSelected = _selectedCategory == group;

                      return GestureDetector(
                        onTap: () => _selectCategory(group),
                        child: Container(
                          width: 80.w,
                          margin: EdgeInsets.only(right: 12.w),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.grey[200]!,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 22.r,
                                backgroundColor: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : _getBloodGroupColor(group).withOpacity(0.1),
                                child: Text(
                                  group,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : _getBloodGroupColor(group),
                                  ),
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                '$total Units',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16.h),

                // Search Bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Container(
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search by hospital...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                // Headline of filtered count
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedCategory.isEmpty
                            ? 'All Available Blood Packs'
                            : 'Available $_selectedCategory Blood Packs',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        '${_filteredInventory.length} packs',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),

                // Available Blood Packs Detail List
                Expanded(
                  child: _filteredInventory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                size: 48.w,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'No matching blood packs available',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14.sp,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          itemCount: _filteredInventory.length,
                          itemBuilder: (context, index) {
                            final pack = _filteredInventory[index];
                            final isExpired = pack.expirationDate.isBefore(DateTime.now());
                            final expDaysRemaining = pack.expirationDate.difference(DateTime.now()).inDays;

                            return Card(
                              elevation: 1,
                              margin: EdgeInsets.only(bottom: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(12.w),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Blood Group Badge
                                    Container(
                                      width: 48.w,
                                      height: 48.w,
                                      decoration: BoxDecoration(
                                        color: _getBloodGroupColor(pack.bloodGroup).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          pack.bloodGroup,
                                          style: TextStyle(
                                            fontSize: 18.sp,
                                            fontWeight: FontWeight.bold,
                                            color: _getBloodGroupColor(pack.bloodGroup),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    // Details Section
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pack.hospitalName,
                                            style: TextStyle(
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            'Quantity: ${pack.quantity} units',
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today, size: 12.w, color: Colors.grey[500]),
                                              SizedBox(width: 4.w),
                                              Text(
                                                'Expires: ${pack.expirationDate.day}/${pack.expirationDate.month}/${pack.expirationDate.year}',
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: isExpired ? Colors.red : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (!isExpired) ...[
                                            SizedBox(height: 2.h),
                                            Text(
                                              '($expDaysRemaining days left)',
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                color: expDaysRemaining < 7 ? Colors.orange : Colors.green,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Action Button
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pushNamed(
                                          '/blood-request',
                                          arguments: {
                                            'bloodGroup': pack.bloodGroup,
                                            'hospitalId': pack.hospitalId,
                                          },
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                      ),
                                      child: const Text('Request'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Color _getBloodGroupColor(String bloodGroup) {
    switch (bloodGroup) {
      case 'A+':
      case 'A-':
        return const Color(0xFFE03131); // red
      case 'B+':
      case 'B-':
        return const Color(0xFF1971C2); // blue
      case 'AB+':
      case 'AB-':
        return const Color(0xFF9C36B5); // purple
      case 'O+':
      case 'O-':
        return const Color(0xFF2B8A3E); // green
      default:
        return Colors.grey;
    }
  }
}
