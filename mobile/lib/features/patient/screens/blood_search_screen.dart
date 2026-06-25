import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/inventory_repository.dart';
import '../../../../data/models/blood_inventory_model.dart';
import '../../../../core/constants/app_constants.dart';

class BloodSearchScreen extends ConsumerStatefulWidget {
  const BloodSearchScreen({super.key});

  @override
  ConsumerState<BloodSearchScreen> createState() => _BloodSearchScreenState();
}

class _BloodSearchScreenState extends ConsumerState<BloodSearchScreen> {
  String? _selectedBloodGroup;
  String? _selectedRegion;
  int? _selectedHospitalId;
  List<BloodInventoryModel> _results = [];
  bool _isSearching = false;

  Future<void> _searchBlood() async {
    setState(() => _isSearching = true);

    try {
      final inventoryRepo = ref.read(inventoryRepositoryProvider);
      final results = await inventoryRepo.searchBlood(
        bloodGroup: _selectedBloodGroup,
        region: _selectedRegion,
        hospitalId: _selectedHospitalId,
      );
      setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('search_blood')),
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: EdgeInsets.all(16.w),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Blood Group',
                    isDense: true,
                  ),
                  items: AppConstants.bloodGroups
                      .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedBloodGroup = value),
                ),
                SizedBox(height: 12.h),
                ElevatedButton.icon(
                  onPressed: _isSearching ? null : _searchBlood,
                  icon: const Icon(Icons.search),
                  label: Text(localization.translate('search')),
                ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          localization.translate('no_results'),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 12.h),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getBloodGroupColor(item.bloodGroup),
                                child: Text(
                                  item.bloodGroup,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(item.hospitalName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item.quantity} units available'),
                                  Text(
                                    'Expires: ${item.expirationDate.day}/${item.expirationDate.month}/${item.expirationDate.year}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  // Request blood
                                },
                                child: Text(localization.translate('request')),
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
        return Colors.red;
      case 'A-':
        return Colors.redAccent;
      case 'B+':
        return Colors.blue;
      case 'B-':
        return Colors.blueAccent;
      case 'AB+':
        return Colors.purple;
      case 'AB-':
        return Colors.purpleAccent;
      case 'O+':
        return Colors.green;
      case 'O-':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }
}
