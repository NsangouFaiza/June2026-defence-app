import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/blood_inventory_model.dart';

class InventoryRepository {
  final ApiService _apiService = ApiService();

  Future<List<BloodInventoryModel>> getInventory() async {
    try {
      final response = await _apiService.get('/inventory/');
      return (response.data as List)
          .map((json) => BloodInventoryModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load inventory: $e');
    }
  }

  Future<List<BloodInventoryModel>> searchBlood({
    String? bloodGroup,
    String? region,
    int? hospitalId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (bloodGroup != null) params['blood_group'] = bloodGroup;
      if (region != null) params['region'] = region;
      if (hospitalId != null) params['hospital'] = hospitalId;

      final response = await _apiService.get('/inventory/search/', queryParameters: params);
      return (response.data as List)
          .map((json) => BloodInventoryModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to search blood: $e');
    }
  }

  Future<BloodInventoryModel> createInventoryItem(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/inventory/', data);
      return BloodInventoryModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create inventory item: $e');
    }
  }

  Future<BloodInventoryModel> updateInventoryItem(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put('/inventory/$id/', data);
      return BloodInventoryModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update inventory item: $e');
    }
  }

  Future<void> deleteInventoryItem(int id) async {
    try {
      await _apiService.delete('/inventory/$id/');
    } catch (e) {
      throw Exception('Failed to delete inventory item: $e');
    }
  }

  Future<BloodInventoryModel> approveUnit(int id) async {
    try {
      final response = await _apiService.post('/inventory/$id/approve_unit/');
      return BloodInventoryModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to approve unit: $e');
    }
  }

  Future<BloodInventoryModel> rejectUnit(int id) async {
    try {
      final response = await _apiService.post('/inventory/$id/reject_unit/');
      return BloodInventoryModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to reject unit: $e');
    }
  }

  Future<Map<String, dynamic>> checkBloodAvailability(String bloodGroup, int quantity) async {
    try {
      final response = await _apiService.get(
        '/inventory/check_availability/',
        queryParameters: {
          'blood_group': bloodGroup,
          'quantity': quantity,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'hospitals': []};
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        final d = e.response!.data;
        if (d is Map && d.containsKey('error')) {
          throw Exception(d['error']);
        }
      }
      throw Exception('Failed to check blood availability: ');
    }
  }
}
