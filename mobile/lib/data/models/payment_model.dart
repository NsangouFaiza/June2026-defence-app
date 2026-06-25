class PaymentModel {
  final int id;
  final int requestId;
  final double amount;
  final String paymentMethod;
  final String phoneNumber;
  final String status;
  final String? transactionId;
  final String? provider;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PaymentModel({
    required this.id,
    required this.requestId,
    required this.amount,
    required this.paymentMethod,
    required this.phoneNumber,
    required this.status,
    this.transactionId,
    this.provider,
    required this.createdAt,
    this.updatedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as int,
      requestId: json['request'] as int,
      amount: (json['amount'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      status: json['status'] ?? 'PENDING',
      transactionId: json['transaction_id'],
      provider: json['provider'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request': requestId,
      'amount': amount,
      'payment_method': paymentMethod,
      'phone_number': phoneNumber,
      'status': status,
      'transaction_id': transactionId,
      'provider': provider,
    };
  }
}
