import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/inventory_repository.dart';
import '../../../../data/models/blood_inventory_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../widgets/lifelink_app_bar.dart';

class BloodInventoryScreen extends ConsumerStatefulWidget {
  const BloodInventoryScreen({super.key});

  @override
  ConsumerState<BloodInventoryScreen> createState() => _BloodInventoryScreenState();
}

class _BloodInventoryScreenState extends ConsumerState<BloodInventoryScreen> {
  Future<BloodInventoryModel?> _showAddPackDialog(BuildContext context, String bloodGroup, int? hospitalId) async {
    if (hospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Hospital ID not resolved. Cannot add new pack.')),
      );
      return null;
    }

    final inventoryRepo = ref.read(inventoryRepositoryProvider);
    final qtyController = TextEditingController(text: '1');
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<BloodInventoryModel?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add New $bloodGroup Pack'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity (units)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Collection Date:'),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 90)),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Text(
                          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final qty = int.tryParse(qtyController.text) ?? 1;
                    final expDate = selectedDate.add(const Duration(days: 42)); // 42 days shelf life
                    try {
                      final newPack = await inventoryRepo.createInventoryItem({
                        'hospital': hospitalId,
                        'blood_group': bloodGroup,
                        'quantity': qty,
                        'collection_date': "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                        'expiration_date': "${expDate.year}-${expDate.month.toString().padLeft(2, '0')}-${expDate.day.toString().padLeft(2, '0')}",
                        'status': 'available',
                      });
                      Navigator.of(context).pop(newPack);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding pack: $e')),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  Future<void> _showManagePacksDialog(BuildContext context, String bloodGroup, List<BloodInventoryModel> packs, int? fallbackHospitalId) async {
    final inventoryRepo = ref.read(inventoryRepositoryProvider);
    final localization = ref.read(localizationServiceProvider);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Group $bloodGroup Packs'),
                  IconButton(
                    icon: const Icon(Icons.add_box, color: AppTheme.primaryColor),
                    tooltip: 'Add New Pack',
                    onPressed: () async {
                      final newPack = await _showAddPackDialog(context, bloodGroup, fallbackHospitalId);
                      if (newPack != null) {
                        setState(() {});
                        Navigator.of(context).pop(); // Close manage packs dialog to refresh everything
                        _showManagePacksDialog(context, bloodGroup, [...packs, newPack], fallbackHospitalId);
                      }
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: packs.isEmpty
                    ? const Center(child: Text('No blood packs available for this group.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: packs.length,
                        itemBuilder: (context, index) {
                          final pack = packs[index];
                          final collectStr = "${pack.collectionDate.year}-${pack.collectionDate.month.toString().padLeft(2, '0')}-${pack.collectionDate.day.toString().padLeft(2, '0')}";
                          final expiryStr = "${pack.expirationDate.year}-${pack.expirationDate.month.toString().padLeft(2, '0')}-${pack.expirationDate.day.toString().padLeft(2, '0')}";
                          final isExpired = pack.expirationDate.isBefore(DateTime.now());
                          return Container(
                            margin: EdgeInsets.only(bottom: 12.h),
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Collected: $collectStr',
                                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        'Expires: $expiryStr',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.bold,
                                          color: isExpired ? AppTheme.error : AppTheme.success,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        'Status: ${pack.status.toUpperCase()}',
                                        style: TextStyle(fontSize: 11.sp, color: AppTheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
                                      onPressed: pack.quantity <= 1
                                          ? null
                                          : () async {
                                              try {
                                                final updated = await inventoryRepo.updateInventoryItem(
                                                  pack.id,
                                                  {'quantity': pack.quantity - 1},
                                                );
                                                setDialogState(() {
                                                  packs[index] = updated;
                                                });
                                                setState(() {}); // Refresh main screen
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error: $e')),
                                                );
                                              }
                                            },
                                    ),
                                    Text(
                                      '${pack.quantity}',
                                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.success),
                                      onPressed: () async {
                                        try {
                                          final updated = await inventoryRepo.updateInventoryItem(
                                            pack.id,
                                            {'quantity': pack.quantity + 1},
                                          );
                                          setDialogState(() {
                                            packs[index] = updated;
                                          });
                                          setState(() {}); // Refresh main screen
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e')),
                                          );
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Blood Pack'),
                                            content: const Text('Are you sure you want to delete this blood pack?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await inventoryRepo.deleteInventoryItem(pack.id);
                                            setDialogState(() {
                                              packs.removeAt(index);
                                            });
                                            setState(() {}); // Refresh main screen
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);
    final inventoryRepo = ref.watch(inventoryRepositoryProvider);

    return Scaffold(
      appBar: LifeLinkAppBar(
        title: localization.translate('blood_inventory'),
        actions: [

          FutureBuilder<List<BloodInventoryModel>>(
            future: inventoryRepo.getInventory(),
            builder: (context, snapshot) {
              final inventory = snapshot.data ?? [];
              return IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  if (inventory.isNotEmpty) {
                    final fallbackHospitalId = inventory.first.hospitalId;
                    String selectedGroup = AppConstants.bloodGroups.first;
                    final newGroup = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Select Blood Group'),
                        content: DropdownButtonFormField<String>(
                          value: selectedGroup,
                          items: AppConstants.bloodGroups
                              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) selectedGroup = val;
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(selectedGroup),
                            child: const Text('Select'),
                          ),
                        ],
                      ),
                    );

                    if (newGroup != null && context.mounted) {
                      final newPack = await _showAddPackDialog(context, newGroup, fallbackHospitalId);
                      if (newPack != null) {
                        setState(() {});
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No active inventory found to fetch hospital association.')),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<BloodInventoryModel>>(
        future: inventoryRepo.getInventory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final inventory = snapshot.data ?? [];

          // Group by blood group
          final groupedInventory = <String, List<BloodInventoryModel>>{};
          for (final item in inventory) {
            groupedInventory.putIfAbsent(item.bloodGroup, () => []).add(item);
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: AppConstants.bloodGroups.length,
            itemBuilder: (context, index) {
              final bloodGroup = AppConstants.bloodGroups[index];
              final items = groupedInventory[bloodGroup] ?? [];
              final totalQuantity = items.fold<int>(0, (sum, item) => sum + item.quantity);
              final isLowStock = totalQuantity < 5;

              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLowStock ? AppTheme.error : AppTheme.primaryColor,
                    child: Text(
                      bloodGroup,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    'Group $bloodGroup',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('$totalQuantity units available'),
                  trailing: isLowStock
                      ? Chip(
                          label: Text(localization.translate('low_stock')),
                          backgroundColor: AppTheme.error.withOpacity(0.1),
                        )
                      : Chip(
                          label: Text(localization.translate('available')),
                          backgroundColor: AppTheme.success.withOpacity(0.1),
                        ),
                  onTap: () {
                    final fallbackHospitalId = inventory.isNotEmpty ? inventory.first.hospitalId : null;
                    _showManagePacksDialog(context, bloodGroup, items, fallbackHospitalId);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
