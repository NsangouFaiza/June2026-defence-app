import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/payment_repository.dart';
import '../../../../core/providers/providers.dart';
import '../../../../widgets/lifelink_app_bar.dart';

class HospitalSubscriptionPaymentScreen extends ConsumerStatefulWidget {

  final int? hospitalId;
  final String? hospitalName;
  final String? currentExpiryDate;

  const HospitalSubscriptionPaymentScreen({
    super.key,
    this.hospitalId,
    this.hospitalName,
    this.currentExpiryDate,
  });

  @override
  ConsumerState<HospitalSubscriptionPaymentScreen> createState() =>
      _HospitalSubscriptionPaymentScreenState();
}

class _HospitalSubscriptionPaymentScreenState
    extends ConsumerState<HospitalSubscriptionPaymentScreen> {
  int _selectedMonths = 1;
  String _selectedMethod = 'MTN_MOMO';
  final _phoneController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  bool _isProcessing = false;

  final double _monthlyFee = 25.0;

  @override
  void dispose() {
    _phoneController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    super.dispose();
  }

  double get _totalAmount => _monthlyFee * _selectedMonths;

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

  Future<void> _processPayment() async {
    final localization = ref.read(localizationServiceProvider);

    if ((_selectedMethod == 'MTN_MOMO' || _selectedMethod == 'ORANGE_MONEY') &&
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localization.translate('please_enter_phone') ?? 'Please enter your Mobile Money phone number'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final result = await paymentRepo.payHospitalSubscription({
        'hospital_id': widget.hospitalId,
        'amount': _totalAmount,
        'months': _selectedMonths,
        'payment_method': _selectedMethod,
        'phone_number': _phoneController.text.trim(),
      });

      if (mounted) {
        final paymentData = result['payment'] as Map<String, dynamic>;
        final paymentId = paymentData['id'] as int;
        final initialStatus = (paymentData['status'] ?? 'PENDING').toString().toUpperCase();

        if (initialStatus == 'PENDING') {
          _waitForPaymentCompletion(paymentId, (successPaymentJson) {
            final vStatus = (successPaymentJson['status'] ?? '').toString().toUpperCase();
            if (vStatus == 'SUCCESS') {
              _showInvoiceDialog(successPaymentJson);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Payment not confirmed by Campay (Status: $vStatus). Subscription remains inactive.'),
                  backgroundColor: AppTheme.warning,
                ),
              );
            }
          });
        } else if (initialStatus == 'SUCCESS') {
          _showInvoiceDialog(paymentData);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment initiation failed or was rejected (Status: $initialStatus). Subscription remains inactive.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showInvoiceDialog(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 28.w),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'Payment Receipt / Facture',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    Text(
                      'INVOICE / FACTURE',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      payment['invoice_number'] ?? 'INV-HOSP-2026',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _buildReceiptRow('Hospital', payment['hospital_name'] ?? widget.hospitalName ?? 'Hospital'),
              _buildReceiptRow('Amount Paid', '${double.parse(payment['amount'].toString()).toStringAsFixed(0)} FCFA'),
              _buildReceiptRow('Period Covered', '${payment['months']} Month(s)'),
              _buildReceiptRow('Payment Method', payment['payment_method'] ?? _selectedMethod),
              _buildReceiptRow('Reference ID', payment['transaction_reference'] ?? payment['external_reference'] ?? payment['transaction_id'] ?? 'TXN'),
              _buildReceiptRow('Status', payment['status'] ?? 'SUCCESS', color: AppTheme.success),
              SizedBox(height: 8.h),
              const Divider(),
              SizedBox(height: 8.h),
              _buildReceiptRow(
                'Valid Until',
                () {
                  if (payment['subscription_period_end'] != null) {
                    final raw = payment['subscription_period_end'].toString();
                    if (raw.length >= 10) return raw.substring(0, 10);
                  }
                  if (payment['subscription_end_date'] != null) {
                    final raw = payment['subscription_end_date'].toString();
                    if (raw.length >= 10) return raw.substring(0, 10);
                  }
                  final months = payment['months'] is int ? payment['months'] as int : _selectedMonths;
                  final now = DateTime.now();
                  final calcEnd = DateTime(now.year, now.month + months, now.day);
                  return calcEnd.toString().substring(0, 10);
                }(),
                color: AppTheme.primaryColor,
                isBold: true,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/hospital-dashboard',
                (route) => false,
              );
            },
            child: const Text('Access Dashboard / Accéder au Tableau de bord'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13.sp, color: AppTheme.onSurfaceVariant),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? AppTheme.onSurface,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      appBar: const LifeLinkAppBar(
        title: 'Hospital Subscription / Abonnement Hôpital',
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hospital Header Card
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_hospital, color: Colors.white, size: 28.w),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            widget.hospitalName ?? 'Hospital Access Renewal',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        'Monthly Rate: 25 FCFA / Month',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Duration Selection
              Text(
                'Select Duration / Choisir la durée',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 10.w,
                runSpacing: 10.h,
                children: [
                  _buildMonthChip(1, '1 Month', '25 FCFA'),
                  _buildMonthChip(2, '2 Months', '50 FCFA'),
                  _buildMonthChip(3, '3 Months', '75 FCFA'),
                  _buildMonthChip(6, '6 Months', '150 FCFA'),
                  _buildMonthChip(12, '1 Year', '300 FCFA'),
                ],
              ),
              SizedBox(height: 24.h),

              // Payment Method Options (Cameroon)
              Text(
                'Select Payment Method / Mode de paiement',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              SizedBox(height: 12.h),
              _buildPaymentMethodCard(
                code: 'MTN_MOMO',
                title: 'MTN Mobile Money',
                subtitle: 'Pay directly via MTN MoMo (Cameroon)',
                icon: Icons.phone_android,
                color: Colors.amber[700]!,
              ),
              SizedBox(height: 10.h),
              _buildPaymentMethodCard(
                code: 'ORANGE_MONEY',
                title: 'Orange Money',
                subtitle: 'Pay directly via Orange Money (Cameroon)',
                icon: Icons.smartphone,
                color: Colors.orange[800]!,
              ),
              SizedBox(height: 10.h),
              _buildPaymentMethodCard(
                code: 'CARD',
                title: 'Bank Card / Carte Bancaire',
                subtitle: 'Visa, Mastercard, Debit card',
                icon: Icons.credit_card,
                color: Colors.blue[700]!,
              ),
              SizedBox(height: 10.h),
              _buildPaymentMethodCard(
                code: 'CASH',
                title: 'Cash / Express Union / Transfer',
                subtitle: 'Direct deposit or partner agent payment',
                icon: Icons.account_balance_wallet,
                color: Colors.green[700]!,
              ),
              SizedBox(height: 20.h),

              // Inputs based on selected method
              if (_selectedMethod == 'MTN_MOMO' || _selectedMethod == 'ORANGE_MONEY') ...[
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: _selectedMethod == 'MTN_MOMO'
                        ? 'MTN MoMo Number (e.g. 67XXXXXXX)'
                        : 'Orange Money Number (e.g. 69XXXXXXX)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    hintText: '6XXXXXXXX',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 20.h),
              ] else if (_selectedMethod == 'CARD') ...[
                TextFormField(
                  controller: _cardNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Card Number',
                    prefixIcon: Icon(Icons.credit_card),
                    hintText: '4000 1234 5678 9010',
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cardExpiryController,
                        decoration: const InputDecoration(
                          labelText: 'MM/YY',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextFormField(
                        controller: _cardCvvController,
                        decoration: const InputDecoration(
                          labelText: 'CVV',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
              ],

              // Total Summary Container
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Subscription Fee',
                          style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                        ),
                        Text(
                          '${_totalAmount.toStringAsFixed(0)} FCFA',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$_selectedMonths Month(s)',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Pay Now Button
              ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Confirm Payment / Payer ${_totalAmount.toStringAsFixed(0)} FCFA',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthChip(int months, String label, String price) {
    final isSelected = _selectedMonths == months;
    return ChoiceChip(
      label: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppTheme.onSurface,
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: 11.sp,
              color: isSelected ? Colors.white.withOpacity(0.9) : AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Theme.of(context).cardColor,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedMonths = months);
        }
      },
    );
  }

  Widget _buildPaymentMethodCard({
    required String code,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMethod == code;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = code),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Theme.of(context).cardColor,
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: color, size: 24.w),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 22.w),
          ],
        ),
      ),
    );
  }
}
