import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/payment_repository.dart';
import '../../../../core/constants/app_constants.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final int requestId;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.requestId,
    required this.amount,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String? _selectedMethod;
  String? _phoneNumber;
  bool _isLoading = false;
  bool _isProcessing = false;

  Future<void> _processPayment() async {
    if (_selectedMethod == null || _phoneNumber == null || _phoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select payment method and enter phone number')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final result = await paymentRepo.initiatePayment({
        'request_id': widget.requestId,
        'amount': widget.amount,
        'payment_method': _selectedMethod,
        'phone_number': _phoneNumber,
      });

      if (mounted) {
        _showPaymentDialog(result.toJson());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showPaymentDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(result['status'] == 'SUCCESS'
            ? 'Payment Successful'
            : 'Payment Pending'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              result['status'] == 'SUCCESS'
                  ? Icons.check_circle
                  : Icons.pending,
              size: 64.w,
              color: result['status'] == 'SUCCESS'
                  ? AppTheme.success
                  : AppTheme.warning,
            ),
            SizedBox(height: 16.h),
            Text(
              result['message'] ?? 'Processing payment...',
              textAlign: TextAlign.center,
            ),
            if (result['transaction_id'] != null) ...[
              SizedBox(height: 8.h),
              Text(
                'Transaction ID: ${result['transaction_id']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('payment')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  children: [
                    Text(
                      localization.translate('amount_to_pay'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '${widget.amount.toStringAsFixed(2)} FCFA',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),
              Text(
                localization.translate('select_payment_method'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 16.h),
              ...AppConstants.paymentMethods.map((method) {
                return Card(
                  margin: EdgeInsets.only(bottom: 12.h),
                  child: RadioListTile<String>(
                    title: Text(method['name']!),
                    subtitle: Text(method['description']!),
                    value: method['code']!,
                    groupValue: _selectedMethod,
                    onChanged: (value) {
                      setState(() => _selectedMethod = value);
                    },
                  ),
                );
              }),
              if (_selectedMethod != null) ...[
                SizedBox(height: 16.h),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: _selectedMethod == 'MTN'
                        ? 'MTN Mobile Money Number'
                        : 'Orange Money Number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (value) => _phoneNumber = value,
                ),
              ],
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(localization.translate('pay_now')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
