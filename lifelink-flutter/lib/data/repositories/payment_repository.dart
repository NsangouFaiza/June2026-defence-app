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
  Future<Map<String, dynamic>> payHospitalSubscription(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/hospitals/pay_subscription/', data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to process hospital subscription payment: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getHospitalSubscriptionHistory({int? hospitalId}) async {
    try {
      final query = hospitalId != null ? '?hospital_id=$hospitalId' : '';
      final response = await _apiService.get('/hospitals/subscription_history/$query');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to load subscription history: $e');
    }
  }

  Future<Map<String, dynamic>> getInvoiceDetail(String invoiceNumber) async {
    try {
      final response = await _apiService.get('/hospitals/invoice_detail/?invoice_number=$invoiceNumber');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load invoice details: $e');
    }
  }
}
