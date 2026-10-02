import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/providers.dart';

class CheckBloodAvailabilityDialog extends ConsumerStatefulWidget {
  final String? initialBloodGroup;
  final int initialQuantity;
  final void Function(Map<String, dynamic> hospital)? onSelectHospital;

  const CheckBloodAvailabilityDialog({
    super.key,
    this.initialBloodGroup,
    this.initialQuantity = 1,
    this.onSelectHospital,
  });

  @override
  ConsumerState<CheckBloodAvailabilityDialog> createState() =>
      _CheckBloodAvailabilityDialogState();
}

class _CheckBloodAvailabilityDialogState
    extends ConsumerState<CheckBloodAvailabilityDialog> {
  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  late String _selectedBloodGroup;
  late int _quantity;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>>? _hospitals;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _selectedBloodGroup = widget.initialBloodGroup ?? 'A+';
    _quantity = widget.initialQuantity > 0 ? widget.initialQuantity : 1;
  }

  Future<void> _checkAvailability() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final result =
          await repo.checkBloodAvailability(_selectedBloodGroup, _quantity);
      final list = (result['hospitals'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      if (mounted) {
        setState(() {
          _hospitals = list;
          _hasSearched = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          _isLoading = false;
          _hasSearched = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: 0.85.sh,
          maxWidth: 480.w,
        ),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.bloodtype_rounded,
                      color: AppTheme.primaryColor,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check Blood Availability',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Live stock at verified active hospitals',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Colors.grey,
                  ),
                ],
              ),
              const Divider(height: 20),

              // Filter Controls
              Row(
                children: [
                  // Blood group dropdown
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Blood Group',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBloodGroup,
                              isExpanded: true,
                              items: bloodGroups.map((bg) {
                                return DropdownMenuItem(
                                  value: bg,
                                  child: Text(
                                    bg,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedBloodGroup = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Quantity Selector
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Units Needed',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: _quantity > 1
                                    ? () => setState(() => _quantity--)
                                    : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Text(
                                '$_quantity',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 16),
                                onPressed: () => setState(() => _quantity++),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),

              // Search Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _checkAvailability,
                icon: _isLoading
                    ? SizedBox(
                        width: 16.sp,
                        height: 16.sp,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(
                  _isLoading ? 'Checking Availability...' : 'Check Availability',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Results Section
              Expanded(
                child: _buildResultsSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 40),
            SizedBox(height: 8.h),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 12.sp, color: AppTheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                color: Colors.grey.shade400, size: 48.sp),
            SizedBox(height: 12.h),
            Text(
              'Select blood group and units needed,\nthen tap "Check Availability"',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final hospitals = _hospitals ?? [];
    if (hospitals.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade600, size: 48.sp),
              SizedBox(height: 12.h),
              Text(
                'No Available Blood Units Found',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'No verified active hospitals currently have $_selectedBloodGroup blood in stock for the requested quantity ($_quantity unit(s)).',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/blood-request');
                },
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('Post Emergency Blood Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AVAILABLE AT ${hospitals.length} HOSPITAL(S)',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Colors.green.shade800,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Text(
                '$_selectedBloodGroup Stock Verified',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: ListView.separated(
            itemCount: hospitals.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final h = hospitals[index];
              final availableUnits = h['available_units'] as int? ?? 0;
              final isSufficient = h['is_sufficient'] as bool? ?? false;
              final hospitalName = h['hospital_name'] ?? 'Hospital';
              final city = h['city'] ?? '';
              final region = h['region'] ?? '';
              final phone = h['phone_number'] ?? '';

              return Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: isSufficient
                        ? Colors.green.shade300
                        : Colors.amber.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hospitalName,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: isSufficient
                                ? Colors.green.shade100
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            '$availableUnits Unit(s) In Stock',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: isSufficient
                                  ? Colors.green.shade900
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (city.isNotEmpty || region.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13.sp, color: Colors.grey.shade600),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              [city, region].where((s) => s.isNotEmpty).join(', '),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 13.sp, color: Colors.grey.shade600),
                          SizedBox(width: 4.w),
                          Text(
                            phone,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (widget.onSelectHospital != null) {
                              widget.onSelectHospital!(h);
                            } else {
                              Navigator.of(context).pushNamed(
                                '/blood-request',
                                arguments: {
                                  'hospital_id': h['hospital_id'],
                                  'hospital_name': hospitalName,
                                  'blood_group': _selectedBloodGroup,
                                  'quantity': _quantity,
                                  'fulfillment_type': 'INVENTORY',
                                },
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 6.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Request Blood',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
