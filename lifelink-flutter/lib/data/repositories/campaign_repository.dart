import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/campaign_model.dart';

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
}
