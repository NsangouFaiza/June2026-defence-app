import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/payment_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../widgets/lifelink_app_bar.dart';

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

  Future<void> _waitForPaymentCompletion(int paymentId, Function(Map<String, dynamic> successPayment) onSuccess) async {
    final paymentRepo = ref.read(paymentRepositoryProvider);
    bool completed = false;
    int attempts = 0;
    
    // Show a loading/pending dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              content: Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.primaryColor),
                    SizedBox(height: 20.h),
                    Text(
                      'Confirming Payment',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Please check your phone and enter your Mobile Money PIN when prompted.',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Checking status (Attempt ${attempts + 1})...',
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Start polling
    while (!completed && attempts < 30) { // Poll for up to 60 seconds
      await Future.delayed(const Duration(seconds: 2));
      attempts++;
      try {
        final verifyResult = await paymentRepo.verifyPayment(paymentId);
        final verifyStatus = (verifyResult['status'] ?? 'PENDING').toString().toUpperCase();
        if (verifyStatus == 'SUCCESS') {
          completed = true;
          if (mounted) {
            Navigator.of(context).pop(); // Pop the waiting dialog
            onSuccess(verifyResult);
          }
          break;
        } else if (verifyStatus == 'FAILED') {
          completed = true;
          if (mounted) {
            Navigator.of(context).pop(); // Pop the waiting dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment verification failed or was cancelled.'),
                backgroundColor: AppTheme.error,
              ),
            );
          }
          break;
        }
      } catch (e) {
        debugPrint('Error polling status: $e');
      }
    }

    if (!completed) {
      if (mounted) {
        Navigator.of(context).pop(); // Pop the waiting dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verification timed out. If you were debited, it will reflect shortly.'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    }
  }

  void _showSuccessPaymentDialog(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 28.w),
            SizedBox(width: 10.w),
            const Expanded(
              child: Text(
                'Payment Successful',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64.w, color: AppTheme.success),
            SizedBox(height: 16.h),
            const Text(
              'Your payment has been successfully received. The blood request status has been updated.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              'Transaction ID: ${payment['transaction_id'] ?? payment['transaction_reference'] ?? "N/A"}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/patient-dashboard',
                (route) => false,
              );
            },
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

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
        if (result.status.toUpperCase() == 'PENDING') {
          _waitForPaymentCompletion(result.id, (successPaymentJson) {
            _showSuccessPaymentDialog(successPaymentJson);
          });
        } else {
          _showPaymentDialog(result.toJson());
        }
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
            onPressed: () {
              Navigator.of(context).pop();
              if (result['status'] == 'SUCCESS') {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/patient-dashboard',
                  (route) => false,
                );
              }
            },
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
      appBar: LifeLinkAppBar(
        title: localization.translate('payment'),
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
