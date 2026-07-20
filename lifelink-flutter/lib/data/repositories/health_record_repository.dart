import '../services/api_service.dart';
import '../models/health_record_model.dart';

class HealthRecordRepository {
  final ApiService _apiService = ApiService();

  Future<List<HealthRecordModel>> getMyHealthRecords() async {
    try {
      final response = await _apiService.get('/donors/health-records/my_records/');
      return (response.data as List)
          .map((json) => HealthRecordModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load health records: $e');
    }
  }

  Future<HealthRecordModel> addHealthRecord(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/donors/health-records/', data);
      return HealthRecordModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to add health record: $e');
    }
  }
}
