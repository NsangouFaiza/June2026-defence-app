import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/payment_repository.dart';
import '../../payment/screens/hospital_subscription_payment_screen.dart';

class HospitalSubscriptionHistoryScreen extends ConsumerStatefulWidget {
  final int? hospitalId;

  const HospitalSubscriptionHistoryScreen({super.key, this.hospitalId});

  @override
  ConsumerState<HospitalSubscriptionHistoryScreen> createState() =>
      _HospitalSubscriptionHistoryScreenState();
}

class _HospitalSubscriptionHistoryScreenState
    extends ConsumerState<HospitalSubscriptionHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final data = await paymentRepo.getHospitalSubscriptionHistory(hospitalId: widget.hospitalId);
      if (mounted) {
        setState(() {
          _history = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showInvoiceModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Invoice Details',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            SizedBox(height: 12.h),
            _buildDetailRow('Invoice #', item['invoice_number'] ?? 'N/A', isBold: true),
            _buildDetailRow('Hospital Name', item['hospital_name'] ?? 'N/A'),
            _buildDetailRow('Paid By', item['staff_name'] ?? 'Staff Representative'),
            _buildDetailRow('Amount Paid', '${item['amount']} FCFA', color: AppTheme.primaryColor, isBold: true),
            _buildDetailRow('Duration', '${item['months']} Month(s)'),
            _buildDetailRow('Payment Method', item['payment_method'] ?? 'N/A'),
            _buildDetailRow('Transaction ID', item['transaction_id'] ?? 'N/A'),
            _buildDetailRow('Status', item['status'] ?? 'SUCCESS', color: AppTheme.success),
            _buildDetailRow('Payment Date', item['paid_at'] != null ? item['paid_at'].toString().substring(0, 10) : 'N/A'),
            if (item['subscription_period_end'] != null)
              _buildDetailRow('Valid Until', item['subscription_period_end'].toString().substring(0, 10), color: AppTheme.primaryColor),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14.sp, color: AppTheme.onSurfaceVariant)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Invoices / Factures'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error loading history: $_error'),
                      SizedBox(height: 12.h),
                      ElevatedButton(onPressed: _loadHistory, child: const Text('Retry')),
                    ],
                  ),
                )
              : _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64.w, color: Colors.grey),
                          SizedBox(height: 16.h),
                          Text(
                            'No payment invoices found',
                            style: TextStyle(fontSize: 16.sp, color: AppTheme.onSurfaceVariant),
                          ),
                          SizedBox(height: 24.h),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => HospitalSubscriptionPaymentScreen(
                                    hospitalId: widget.hospitalId,
                                  ),
                                ),
                              ).then((_) => _loadHistory());
                            },
                            icon: const Icon(Icons.payment),
                            label: const Text('Pay Subscription Now'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(14.w),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                child: Icon(Icons.receipt, color: AppTheme.primaryColor),
                              ),
                              title: Text(
                                item['invoice_number'] ?? 'Invoice',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4.h),
                                  Text('${item['amount']} FCFA • ${item['months']} Month(s)'),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Paid on: ${item['created_at'] != null ? item['created_at'].toString().substring(0, 10) : ''}',
                                    style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              trailing: Icon(Icons.chevron_right, color: AppTheme.onSurfaceVariant),
                              onTap: () => _showInvoiceModal(item),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HospitalSubscriptionPaymentScreen(
                hospitalId: widget.hospitalId,
              ),
            ),
          ).then((_) => _loadHistory());
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Renew Subscription', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
