import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/models/donor_model.dart';
import '../../../../data/models/hospital_model.dart';

class DonorSelectionDialog extends ConsumerStatefulWidget {
  final HospitalModel? hospital;
  final String? initialBloodGroup;

  const DonorSelectionDialog({
    super.key,
    this.hospital,
    this.initialBloodGroup,
  });

  @override
  ConsumerState<DonorSelectionDialog> createState() => _DonorSelectionDialogState();
}

class _DonorSelectionDialogState extends ConsumerState<DonorSelectionDialog> {
  List<DonorModel> _allDonors = [];
  List<DonorModel> _filteredDonors = [];
  bool _isLoading = true;

  // Search & Filtering State
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedBloodGroup;
  String _selectedCity = '';
  bool _onlyEligible = true;
  String _donationStatus = 'any'; // 'any', 'active', 'inactive'
  String _lastDonationRange = 'any'; // 'any', '3months', '6months', 'never'

  @override
  void initState() {
    super.initState();
    _selectedBloodGroup = widget.initialBloodGroup;
    _fetchDonors();
  }

  Future<void> _fetchDonors() async {
    try {
      final fetched = await ref.read(donorRepositoryProvider).getDonors();
      setState(() {
        _allDonors = fetched;
        _isLoading = false;
        _applyFiltersAndSearch();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // R = 6371 km
  }

  double? _getDonorDistance(DonorModel donor) {
    if (donor.latitude == null || donor.longitude == null || widget.hospital?.latitude == null || widget.hospital?.longitude == null) {
      return null;
    }
    return _calculateDistance(
      donor.latitude!,
      donor.longitude!,
      widget.hospital!.latitude!,
      widget.hospital!.longitude!,
    );
  }

  void _applyFiltersAndSearch() {
    List<DonorModel> results = List.from(_allDonors);

    // 1. Text Search (Name, Donor ID)
    if (_searchQuery.isNotEmpty) {
      results = results.where((d) {
        final query = _searchQuery.toLowerCase();
        return d.fullName.toLowerCase().contains(query) ||
            d.donorIdCode.toLowerCase().contains(query);
      }).toList();
    }

    // 2. Blood Group Filter
    if (_selectedBloodGroup != null && _selectedBloodGroup!.isNotEmpty && _selectedBloodGroup != 'Any') {
      results = results.where((d) => d.bloodGroup == _selectedBloodGroup).toList();
    }

    // 3. City/Location Filter
    if (_selectedCity.isNotEmpty) {
      results = results.where((d) {
        final city = _selectedCity.toLowerCase();
        return (d.city ?? '').toLowerCase().contains(city) ||
            (d.region ?? '').toLowerCase().contains(city) ||
            (d.address ?? '').toLowerCase().contains(city);
      }).toList();
    }

    // 4. Availability / Eligibility
    if (_onlyEligible) {
      results = results.where((d) => d.isEligible).toList();
    }

    // 5. Donation Status
    if (_donationStatus == 'active') {
      results = results.where((d) => d.totalDonations > 0).toList();
    } else if (_donationStatus == 'inactive') {
      results = results.where((d) => d.totalDonations == 0).toList();
    }

    // 6. Last Donation Date presets
    final now = DateTime.now();
    if (_lastDonationRange == '3months') {
      results = results.where((d) {
        if (d.lastDonationDate == null) return false;
        return now.difference(d.lastDonationDate!).inDays <= 90;
      }).toList();
    } else if (_lastDonationRange == '6months') {
      results = results.where((d) {
        if (d.lastDonationDate == null) return false;
        final diff = now.difference(d.lastDonationDate!).inDays;
        return diff > 90 && diff <= 180;
      }).toList();
    } else if (_lastDonationRange == 'never') {
      results = results.where((d) => d.lastDonationDate == null).toList();
    }

    // Sort: Nearest first if coordinates are available, otherwise by name
    results.sort((a, b) {
      final distA = _getDonorDistance(a);
      final distB = _getDonorDistance(b);
      if (distA != null && distB != null) {
        return distA.compareTo(distB);
      }
      if (distA != null) return -1;
      if (distB != null) return 1;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });

    setState(() {
      _filteredDonors = results;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedBloodGroup = 'Any';
      _selectedCity = '';
      _onlyEligible = false;
      _donationStatus = 'any';
      _lastDonationRange = 'any';
      _applyFiltersAndSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      insetPadding: EdgeInsets.all(16.w),
      child: Container(
        width: double.infinity,
        height: 620.h,
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Eligible Donors',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    if (widget.hospital != null)
                      Text(
                        'Distance relative to ${widget.hospital!.name}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Search Bar & Filter Toggle
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by donor name or ID...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _applyFiltersAndSearch();
                      });
                    },
                  ),
                ),
                SizedBox(width: 8.w),
              ],
            ),
            SizedBox(height: 10.h),

            // Filter Row (Chips inline)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Blood Group filter dropdown card
                  _buildInlineFilterDropdown(
                    label: 'Blood: ${_selectedBloodGroup ?? "Any"}',
                    items: ['Any', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                    selected: _selectedBloodGroup ?? 'Any',
                    onChanged: (val) {
                      setState(() {
                        _selectedBloodGroup = val;
                        _applyFiltersAndSearch();
                      });
                    },
                  ),
                  SizedBox(width: 8.w),
                  // Eligibility Toggle
                  FilterChip(
                    label: Text('Only Eligible', style: TextStyle(fontSize: 11.sp)),
                    selected: _onlyEligible,
                    onSelected: (val) {
                      setState(() {
                        _onlyEligible = val;
                        _applyFiltersAndSearch();
                      });
                    },
                  ),
                  SizedBox(width: 8.w),
                  // Last donation preset dropdown
                  _buildInlineFilterDropdown(
                    label: 'Donation: ${_getDonationRangeLabel()}',
                    items: ['Any', 'Last 3 Months', '3-6 Months Ago', 'Never Donated'],
                    selected: _getDonationRangeSelected(),
                    onChanged: (val) {
                      setState(() {
                        _setDonationRange(val);
                        _applyFiltersAndSearch();
                      });
                    },
                  ),
                  SizedBox(width: 8.w),
                  // Availability/City Filter Input
                  Container(
                    width: 100.w,
                    height: 32.h,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'City Filter',
                        hintStyle: TextStyle(fontSize: 11.sp),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _selectedCity = val;
                          _applyFiltersAndSearch();
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 8.w),
                  TextButton(
                    onPressed: _clearAllFilters,
                    child: Text('Clear', style: TextStyle(fontSize: 11.sp)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),

            // Donors List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredDonors.isEmpty
                      ? Center(
                          child: Text(
                            'No eligible donors match filters.',
                            style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredDonors.length,
                          itemBuilder: (context, index) {
                            final donor = _filteredDonors[index];
                            final distance = _getDonorDistance(donor);
                            final distanceText = distance != null
                                ? (distance < 1.0
                                    ? '${(distance * 1000).round()} m'
                                    : '${distance.toStringAsFixed(1)} km')
                                : 'N/A';
                            final lastDonationStr = donor.lastDonationDate != null
                                ? DateFormat('yyyy-MM-dd').format(donor.lastDonationDate!)
                                : 'None';

                            return Container(
                              margin: EdgeInsets.only(bottom: 12.h),
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Profile Picture & Blood group badge
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        width: 50.w,
                                        height: 50.w,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 1.5),
                                        ),
                                        child: ClipOval(
                                          child: donor.fullProfilePictureUrl != null
                                              ? CachedNetworkImage(
                                                  imageUrl: donor.fullProfilePictureUrl!,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.grey),
                                                )
                                              : const Icon(Icons.person, color: Colors.grey),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.all(4.w),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child: Text(
                                          donor.bloodGroup ?? 'O+',
                                          style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 12.w),

                                  // Donor details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          donor.fullName.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                                        ),
                                        SizedBox(height: 2.h),
                                        Row(
                                          children: [
                                            Text(
                                              donor.donorIdCode,
                                              style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                            ),
                                            const Spacer(),
                                            if (distance != null)
                                              Text(
                                                '📍 $distanceText away',
                                                style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: Colors.indigo),
                                              ),
                                          ],
                                        ),
                                        const Divider(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildCardMiniStat('Age', '${donor.age} yrs'),
                                            _buildCardMiniStat('Phone', donor.phoneNumber),
                                            _buildCardMiniStat('City', donor.city ?? 'N/A'),
                                          ],
                                        ),
                                        SizedBox(height: 4.h),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildCardMiniStat('Donations', '${donor.totalDonations} total'),
                                            _buildCardMiniStat('Last Donated', lastDonationStr),
                                            _buildEligibilityStatus(donor.isEligible),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8.w),

                                  // Select Checkbox button
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 28),
                                        onPressed: () => Navigator.pop(context, donor),
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
        ),
      ),
    );
  }

  Widget _buildCardMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 8.sp, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
      ],
    );
  }

  Widget _buildEligibilityStatus(bool eligible) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: eligible ? AppTheme.success.withOpacity(0.1) : AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        eligible ? 'ELIGIBLE' : 'RESTRICTED',
        style: TextStyle(fontSize: 7.sp, fontWeight: FontWeight.bold, color: eligible ? AppTheme.success : AppTheme.error),
      ),
    );
  }

  Widget _buildInlineFilterDropdown({
    required String label,
    required List<String> items,
    required String selected,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(selected) ? selected : items.first,
          style: TextStyle(fontSize: 11.sp, color: AppTheme.onSurface, fontWeight: FontWeight.bold),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        ),
      ),
    );
  }

  String _getDonationRangeSelected() {
    switch (_lastDonationRange) {
      case '3months':
        return 'Last 3 Months';
      case '6months':
        return '3-6 Months Ago';
      case 'never':
        return 'Never Donated';
      default:
        return 'Any';
    }
  }

  String _getDonationRangeLabel() {
    switch (_lastDonationRange) {
      case '3months':
        return '<3M';
      case '6months':
        return '3-6M';
      case 'never':
        return 'Never';
      default:
        return 'Any';
    }
  }

  void _setDonationRange(String selection) {
    switch (selection) {
      case 'Last 3 Months':
        _lastDonationRange = '3months';
        break;
      case '3-6 Months Ago':
        _lastDonationRange = '6months';
        break;
      case 'Never Donated':
        _lastDonationRange = 'never';
        break;
      default:
        _lastDonationRange = 'any';
    }
  }
}
