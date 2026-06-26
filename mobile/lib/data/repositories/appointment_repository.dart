import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/appointment_model.dart';

class AppointmentRepository {
  final ApiService _apiService = ApiService();

  Future<List<AppointmentModel>> getAppointments() async {
    try {
      final response = await _apiService.get('/appointments/');
      return (response.data as List)
          .map((json) => AppointmentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load appointments: $e');
    }
  }

  Future<AppointmentModel> bookAppointment(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/appointments/', data);
      return AppointmentModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to book appointment: $e');
    }
  }

  Future<List<String>> getAvailableSlots(int hospitalId, DateTime date) async {
    try {
      final response = await _apiService.get(
        '/appointments/available-slots/',
        queryParameters: {
          'hospital': hospitalId,
          'date': date.toIso8601String().split('T')[0],
        },
      );
      return List<String>.from(response.data['available_slots'] as List);
    } catch (e) {
      throw Exception('Failed to load available slots: $e');
    }
  }

  Future<AppointmentModel> rescheduleAppointment(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.patch('/appointments/$id/', data);
      return AppointmentModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to reschedule appointment: $e');
    }
  }

  Future<void> cancelAppointment(int id) async {
    try {
      await _apiService.post('/appointments/$id/cancel/');
    } catch (e) {
      throw Exception('Failed to cancel appointment: $e');
    }
  }

  Future<AppointmentModel> completeAppointment(int id) async {
    try {
      final response = await _apiService.post('/appointments/$id/complete/');
      return AppointmentModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to complete appointment: $e');
    }
  }

  Future<AppointmentModel> confirmAppointment(int id) async {
    try {
      final response = await _apiService.post('/appointments/$id/confirm/');
      return AppointmentModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to confirm appointment: $e');
    }
  }
}
