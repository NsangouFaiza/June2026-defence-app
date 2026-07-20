import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/location_search_service.dart';
import '../models/hospital_model.dart';

class HospitalRepository {
  final ApiService _apiService = ApiService();
  final LocationSearchService _locationSearchService = LocationSearchService();

  Future<List<HospitalModel>> getHospitals() async {
    try {
      final response = await _apiService.get('/hospitals/');
      return (response.data as List)
          .map((json) => HospitalModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load hospitals: $e');
    }
  }

  /// Search all healthcare facilities combining database records and real-time external location search.
  Future<List<HospitalModel>> searchLiveHealthcareFacilities(
    String query, {
    double? userLat,
    double? userLng,
  }) async {
    List<HospitalModel> dbHospitals = [];
    try {
      dbHospitals = await getHospitals();
    } catch (_) {}

    final String expanded = _locationSearchService.resolveAcronym(query);

    // Filter DB hospitals locally
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final qExp = expanded.toLowerCase();
      dbHospitals = dbHospitals.where((h) {
        final name = h.name.toLowerCase();
        final city = (h.city ?? '').toLowerCase();
        final region = (h.region ?? '').toLowerCase();
        final address = (h.address ?? '').toLowerCase();
        final services = (h.services ?? '').toLowerCase();

        return name.contains(q) ||
            name.contains(qExp) ||
            city.contains(q) ||
            region.contains(q) ||
            address.contains(q) ||
            services.contains(q);
      }).toList();
    }

    // Query external live OpenStreetMap & Cameroon knowledgebase
    List<HospitalModel> externalResults = [];
    if (query.isNotEmpty) {
      externalResults = await _locationSearchService.searchExternalFacilities(
        query,
        userLat: userLat,
        userLng: userLng,
      );
    } else {
      // Default view: include knowledgebase facilities if query is empty
      externalResults = await _locationSearchService.searchExternalFacilities(
        'Hôpital Cameroon',
        userLat: userLat,
        userLng: userLng,
      );
    }

    // Deduplicate by name & coordinates proximity
    final Map<String, HospitalModel> merged = {};
    for (final h in dbHospitals) {
      merged[h.name.toLowerCase()] = h;
    }

    for (final ext in externalResults) {
      final key = ext.name.toLowerCase();
      if (!merged.containsKey(key)) {
        merged[key] = ext;
      }
    }

    return merged.values.toList();
  }

  Future<HospitalModel?> getMyHospital() async {
    try {
      final response = await _apiService.get('/hospitals/my-hospital/');
      return HospitalModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('Failed to load hospital: $e');
    } catch (e) {
      throw Exception('Failed to load hospital: $e');
    }
  }

  Future<HospitalModel> getHospitalById(int id) async {
    try {
      final response = await _apiService.get('/hospitals/$id/');
      return HospitalModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load hospital: $e');
    }
  }

  Future<Map<String, dynamic>> getHospitalStatistics() async {
    try {
      final response = await _apiService.get('/hospitals/statistics/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load statistics: $e');
    }
  }
}
