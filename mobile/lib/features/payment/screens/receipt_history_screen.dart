import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/services/api_service.dart';

// Provider for fetching payment/receipt history
final receiptHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiService().get('/payments/history/');
  return (response.data as List).cast<Map<String, dynamic>>();
});

class ReceiptHistoryScreen extends ConsumerWidget {
  final bool isTab;
  const ReceiptHistoryScreen({super.key, this.isTab = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(receiptHistoryProvider);

    final content = receiptsAsync.when(
      data: (receipts) {
        if (receipts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 64.w,
                  color: Colors.grey.shade300,
                ),
                SizedBox(height: 16.h),
                Text(
                  'No transactions found',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Your financial transactions will appear here.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          itemCount: receipts.length,
          itemBuilder: (context, index) {
            final receipt = receipts[index];
            return _buildReceiptCard(context, receipt);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 40),
              SizedBox(height: 12.h),
              Text(
                'Failed to load payment history',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6.h),
              Text(err.toString(), style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
              TextButton(
                onPressed: () => ref.refresh(receiptHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );

    if (isTab) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Payment History'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: content,
    );
  }

  Widget _buildReceiptCard(BuildContext context, Map<String, dynamic> receipt) {
    final status = (receipt['status'] ?? 'PENDING').toString().toUpperCase();
    final amount = receipt['amount'] ?? 0.0;
    final dateStr = receipt['created_at'] ?? '';
    final parsedDate = dateStr.isNotEmpty ? DateTime.parse(dateStr) : DateTime.now();
    final dateFormatted = DateFormat('dd MMM yyyy, HH:mm').format(parsedDate);
    final paymentType = receipt['payment_type'] ?? 'Payment';

    Color statusColor = AppTheme.warning;
    IconData statusIcon = Icons.pending_outlined;
    if (status == 'SUCCESS' || status == 'PAID') {
      statusColor = AppTheme.success;
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (status == 'FAILED') {
      statusColor = AppTheme.error;
      statusIcon = Icons.cancel_outlined;
    }

    IconData typeIcon = Icons.payment_rounded;
    if (paymentType.contains('Subscription')) {
      typeIcon = Icons.card_membership_rounded;
    } else if (paymentType.contains('Request') || paymentType.contains('Blood')) {
      typeIcon = Icons.local_hospital_rounded;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: () => _showReceiptDetailsSheet(context, receipt),
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(typeIcon, color: AppTheme.primaryColor, size: 20.w),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paymentType,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      dateFormatted,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${amount.toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 10.sp),
                        SizedBox(width: 4.w),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptDetailsSheet(BuildContext context, Map<String, dynamic> receipt) {
    final status = (receipt['status'] ?? 'PENDING').toString().toUpperCase();
    final amount = receipt['amount'] ?? 0.0;
    final dateStr = receipt['created_at'] ?? '';
    final parsedDate = dateStr.isNotEmpty ? DateTime.parse(dateStr) : DateTime.now();
    final dateFormatted = DateFormat('dd MMMM yyyy, HH:mm').format(parsedDate);
    final description = receipt['description'] ?? '';
    final paymentMethod = receipt['payment_method'] ?? 'N/A';
    final receiptNum = receipt['receipt_number'] ?? 'N/A';
    final refId = receipt['reference_id'] ?? 'N/A';
    final userName = receipt['user_name'] ?? 'Guest User';
    final userRole = receipt['user_role'] ?? 'User';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.r),
              topRight: Radius.circular(24.r),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull bar
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Title Header with logo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 28.h,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'LifeLink Receipt',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: (status == 'SUCCESS' || status == 'PAID')
                          ? AppTheme.success.withOpacity(0.1)
                          : AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: (status == 'SUCCESS' || status == 'PAID')
                            ? AppTheme.success
                            : AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32, thickness: 1),

              // Transaction Details table layout
              _buildDetailItem('Receipt No / Txn ID', receiptNum),
              _buildDetailItem('User Name', userName),
              _buildDetailItem('User Role', userRole),
              _buildDetailItem('Date & Time', dateFormatted),
              _buildDetailItem('Payment Type', receipt['payment_type'] ?? 'N/A'),
              _buildDetailItem('Payment Method', paymentMethod),
              _buildDetailItem('Reference ID / Invoice', refId.toString()),
              SizedBox(height: 12.h),
              
              // Description box
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DESCRIPTION',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Total Amount box
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amount Paid',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${amount.toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // PDF Download and Share actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _simulateShare(context, receiptNum);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        foregroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Receipt'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _simulatePDFDownload(context, receiptNum);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                      label: const Text('Download PDF'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _simulatePDFDownload(BuildContext context, String receiptNum) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Row(
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryColor),
                SizedBox(width: 20.w),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generating Receipt PDF',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Signing digital authenticity seal...',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      Navigator.pop(context); // Pop loading dialog
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8.w),
              Expanded(child: Text('Official receipt PDF ($receiptNum) saved to Downloads successfully!')),
            ],
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    });
  }

  void _simulateShare(BuildContext context, String receiptNum) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receipt $receiptNum shared successfully!'),
        backgroundColor: AppTheme.success,
      ),
    );
  }
}
