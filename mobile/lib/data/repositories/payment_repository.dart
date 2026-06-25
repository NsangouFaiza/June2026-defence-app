import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  final ApiService _apiService = ApiService();

  Future<PaymentModel> initiatePayment(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/payments/initiate/', data);
      return PaymentModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to initiate payment: $e');
    }
  }

  Future<PaymentModel> getPaymentStatus(int paymentId) async {
    try {
      final response = await _apiService.get('/payments/$paymentId/status/');
      return PaymentModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get payment status: $e');
    }
  }

  Future<List<PaymentModel>> getPaymentHistory() async {
    try {
      final response = await _apiService.get('/payments/history/');
      return (response.data as List)
          .map((json) => PaymentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load payment history: $e');
    }
  }
}
