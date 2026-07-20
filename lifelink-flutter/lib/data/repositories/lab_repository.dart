import '../services/api_service.dart';
import '../models/lab_test_record_model.dart';

class LabRepository {
  final ApiService _apiService = ApiService();

  Future<List<LabTestRecordModel>> getLabRecords() async {
    try {
      final response = await _apiService.get('/inventory/lab-records/');
      return (response.data as List)
          .map((json) => LabTestRecordModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load lab records: $e');
    }
  }

  Future<List<LabTestRecordModel>> getMyConductedTests() async {
    try {
      final response = await _apiService.get('/inventory/lab-records/my_tests/');
      return (response.data as List)
          .map((json) => LabTestRecordModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load technician tests: $e');
    }
  }

  Future<LabTestRecordModel> createLabRecord(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/inventory/lab-records/', data);
      return LabTestRecordModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to record lab test: $e');
    }
  }

  Future<LabTestRecordModel> approveLabRecord(int id) async {
    try {
      final response = await _apiService.post('/inventory/lab-records/$id/approve/');
      return LabTestRecordModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to approve lab unit: $e');
    }
  }

  Future<LabTestRecordModel> rejectLabRecord(int id, {String? reason}) async {
    try {
      final response = await _apiService.post('/inventory/lab-records/$id/reject/', {
        if (reason != null) 'reason': reason,
      });
      return LabTestRecordModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to reject lab unit: $e');
    }
  }

  Future<LabTestRecordModel> reportAbnormalFinding(int id, String findings, {String unitStatus = 'QUARANTINED'}) async {
    try {
      final response = await _apiService.post('/inventory/lab-records/$id/report_abnormal/', {
        'abnormal_findings': findings,
        'unit_status': unitStatus,
      });
      return LabTestRecordModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to report abnormal finding: $e');
    }
  }
}
