import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/blood_request_model.dart';

class RequestRepository {
  final ApiService _apiService = ApiService();

  Future<List<BloodRequestModel>> getRequests() async {
    try {
      final response = await _apiService.get('/requests/');
      return (response.data as List)
          .map((json) => BloodRequestModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load requests: $e');
    }
  }

  Future<List<BloodRequestModel>> getMyRequests() async {
    try {
      final response = await _apiService.get('/requests/my_requests/');
      return (response.data as List)
          .map((json) => BloodRequestModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load requests: $e');
    }
  }

  Future<BloodRequestModel> createRequest(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/requests/', data);
      return BloodRequestModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create request: $e');
    }
  }

  Future<BloodRequestModel> createEmergencyRequest(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/requests/emergency/', data);
      return BloodRequestModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create emergency request: $e');
    }
  }

  Future<BloodRequestModel> updateRequest(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.patch('/requests/$id/', data);
      return BloodRequestModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update request: $e');
    }
  }

  Future<void> cancelRequest(int id) async {
    try {
      await _apiService.post('/requests/$id/cancel/');
    } catch (e) {
      throw Exception('Failed to cancel request: $e');
    }
  }

  Future<BloodRequestModel> approveRequest(int id, String fulfillmentType, {int? donorId}) async {
    try {
      final response = await _apiService.post('/requests/$id/approve/', {
        'fulfillment_type': fulfillmentType,
        if (donorId != null) 'donor_id': donorId,
      });
      return BloodRequestModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to approve request: $e');
    }
  }

  Future<BloodRequestModel> updateFulfillment(int id, String fulfillmentType, {int? donorId}) async {
    try {
      final response = await _apiService.post('/requests/$id/update-fulfillment/', {
        'fulfillment_type': fulfillmentType,
        if (donorId != null) 'donor_id': donorId,
      });
      return BloodRequestModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update fulfillment: $e');
    }
  }

  Future<BloodRequestModel> rejectRequest(int id, String reason) async {
    try {
      final response = await _apiService.post('/requests/$id/reject/', {'reason': reason});
      return BloodRequestModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  Future<BloodRequestModel> fulfillRequest(int id) async {
    try {
      final response = await _apiService.post('/requests/$id/fulfill/');
      return BloodRequestModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fulfill request: $e');
    }
  }

  Future<BloodRequestModel> pledgeToRequest(int id) async {
    try {
      final response = await _apiService.post('/requests/$id/pledge/');
      return BloodRequestModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to pledge to request: $e');
    }
  }

  Future<List<BloodRequestModel>> getMyPledges() async {
    try {
      final response = await _apiService.get('/requests/my_pledges/');
      return (response.data as List)
          .map((json) => BloodRequestModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load pledges: $e');
    }
  }

  Future<BloodRequestModel> cancelPledge(int id) async {
    try {
      final response = await _apiService.post('/requests/$id/cancel_pledge/');
      return BloodRequestModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to cancel pledge: $e');
    }
  }
}
