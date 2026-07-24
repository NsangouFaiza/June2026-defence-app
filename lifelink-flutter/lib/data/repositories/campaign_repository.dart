import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/campaign_model.dart';
import '../models/donor_model.dart';

class CampaignRepository {
  final ApiService _apiService = ApiService();

  Future<List<CampaignModel>> getCampaigns() async {
    try {
      final response = await _apiService.get('/campaigns/');
      return (response.data as List)
          .map((json) => CampaignModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load campaigns: $e');
    }
  }

  Future<CampaignModel> getCampaignById(int id) async {
    try {
      final response = await _apiService.get('/campaigns/$id/');
      return CampaignModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load campaign: $e');
    }
  }

  Future<CampaignModel> createCampaign(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/campaigns/', data);
      return CampaignModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create campaign: $e');
    }
  }

  Future<CampaignModel> updateCampaign(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.patch('/campaigns/$id/', data);
      return CampaignModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update campaign: $e');
    }
  }

  Future<void> deleteCampaign(int id) async {
    try {
      await _apiService.delete('/campaigns/$id/');
    } catch (e) {
      throw Exception('Failed to delete campaign: $e');
    }
  }

  Future<void> sendCampaign(int id, List<int> recipientIds) async {
    try {
      await _apiService.post('/campaigns/$id/send/', {'recipient_ids': recipientIds});
    } catch (e) {
      throw Exception('Failed to send campaign: $e');
    }
  }

  Future<List<DonorModel>> getTargetDonors(int id) async {
    try {
      final response = await _apiService.get('/campaigns/$id/target-donors/');
      return (response.data as List)
          .map((json) => DonorModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load targeted donors: $e');
    }
  }

  Future<void> registerForCampaign(int campaignId) async {
    try {
      await _apiService.post('/campaigns/$campaignId/register/');
    } catch (e) {
      throw Exception('Failed to register for campaign: $e');
    }
  }

  Future<void> unregisterFromCampaign(int campaignId) async {
    try {
      await _apiService.post('/campaigns/$campaignId/unregister/');
    } catch (e) {
      throw Exception('Failed to unregister from campaign: $e');
    }
  }

  Future<List<CampaignModel>> getMyCampaigns() async {
    try {
      final response = await _apiService.get('/campaigns/my-campaigns/');
      return (response.data as List)
          .map((json) => CampaignModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load registered campaigns: $e');
    }
  }

  Future<CampaignModel> duplicateCampaign(int id) async {
    try {
      final response = await _apiService.post('/campaigns/$id/duplicate/');
      return CampaignModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to duplicate campaign: $e');
    }
  }

  Future<void> publishCampaign(int id) async {
    try {
      await _apiService.post('/campaigns/$id/publish/');
    } catch (e) {
      throw Exception('Failed to publish campaign: $e');
    }
  }

  Future<void> unpublishCampaign(int id) async {
    try {
      await _apiService.post('/campaigns/$id/unpublish/');
    } catch (e) {
      throw Exception('Failed to unpublish campaign: $e');
    }
  }

  Future<void> archiveCampaign(int id) async {
    try {
      await _apiService.post('/campaigns/$id/archive/');
    } catch (e) {
      throw Exception('Failed to archive campaign: $e');
    }
  }

  Future<void> restoreCampaign(int id) async {
    try {
      await _apiService.post('/campaigns/$id/restore/');
    } catch (e) {
      throw Exception('Failed to restore campaign: $e');
    }
  }

  Future<void> incrementCampaignViews(int id) async {
    try {
      await _apiService.post('/campaigns/$id/increment-views/');
    } catch (_) {}
  }

  Future<List<CampaignRegistrationModel>> getCampaignParticipants(
    int id, {
    String? search,
    String? bloodGroup,
    String? status,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (bloodGroup != null && bloodGroup.isNotEmpty) params['blood_group'] = bloodGroup;
      if (status != null && status.isNotEmpty) params['status'] = status;

      final response = await _apiService.get('/campaigns/$id/participants/', queryParameters: params);
      return (response.data as List)
          .map((json) => CampaignRegistrationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load campaign participants: $e');
    }
  }

  Future<void> approveRegistration(int campaignId, int donorId) async {
    try {
      await _apiService.post('/campaigns/$campaignId/approve-registration/', {'donor_id': donorId});
    } catch (e) {
      throw Exception('Failed to approve registration: $e');
    }
  }

  Future<void> rejectRegistration(int campaignId, int donorId) async {
    try {
      await _apiService.post('/campaigns/$campaignId/reject-registration/', {'donor_id': donorId});
    } catch (e) {
      throw Exception('Failed to reject registration: $e');
    }
  }

  Future<void> checkInParticipant(int campaignId, int donorId, bool donated) async {
    try {
      await _apiService.post('/campaigns/$campaignId/attendance-check/', {'donor_id': donorId, 'donated': donated});
    } catch (e) {
      throw Exception('Failed to check in participant: $e');
    }
  }

  Future<Map<String, dynamic>> getCampaignStatistics(int id) async {
    try {
      final response = await _apiService.get('/campaigns/$id/statistics/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load campaign statistics: $e');
    }
  }
}
