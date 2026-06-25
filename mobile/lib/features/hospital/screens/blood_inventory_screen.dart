import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/inventory_repository.dart';
import '../../../../data/models/blood_inventory_model.dart';
import '../../../../core/constants/app_constants.dart';

class BloodInventoryScreen extends ConsumerWidget {
  const BloodInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final inventoryRepo = ref.watch(inventoryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('blood_inventory')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to add inventory
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
                    // View details
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
