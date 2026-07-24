class BloodRequestModel {
  final int id;
  final int patientId;
  final String patientName;
  final int? hospitalId;
  final String? hospitalName;
  final String bloodGroup;
  final int quantity;
  final String urgency;
  final String status;
  final bool isEmergency;
  final String? reason;
  final String paymentStatus;
  final String? paymentReference;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? fulfillmentType;
  final int? donorId;
  final String? donorName;
  final String? donorPhone;
  final String? donorEmail;
  final Map<String, dynamic>? appointmentDetails;

  BloodRequestModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.hospitalId,
    this.hospitalName,
    required this.bloodGroup,
    required this.quantity,
    required this.urgency,
    required this.status,
    required this.isEmergency,
    this.reason,
    required this.paymentStatus,
    this.paymentReference,
    required this.createdAt,
    this.updatedAt,
    this.fulfillmentType,
    this.donorId,
    this.donorName,
    this.donorPhone,
    this.donorEmail,
    this.appointmentDetails,
  });

  factory BloodRequestModel.fromJson(Map<String, dynamic> json) {
    return BloodRequestModel(
      id: json['id'] as int,
      patientId: json['patient'] as int,
      patientName: json['patient_name'] ?? 'Unknown',
      hospitalId: json['hospital'] as int?,
      hospitalName: json['hospital_name'],
      bloodGroup: json['blood_group'] ?? '',
      quantity: json['quantity'] ?? 1,
      urgency: json['urgency'] ?? 'MEDIUM',
      status: json['status'] ?? 'PENDING',
      isEmergency: json['is_emergency'] ?? false,
      reason: json['reason'],
      paymentStatus: json['payment_status'] ?? 'PENDING',
      paymentReference: json['payment_reference'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      fulfillmentType: json['fulfillment_type'] as String?,
      donorId: json['donor'] as int?,
      donorName: json['donor_name'] as String?,
      donorPhone: json['donor_phone'] as String?,
      donorEmail: json['donor_email'] as String?,
      appointmentDetails: json['appointment_details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient': patientId,
      'hospital': hospitalId,
      'blood_group': bloodGroup,
      'quantity': quantity,
      'urgency': urgency,
      'status': status,
      'is_emergency': isEmergency,
      'reason': reason,
      'payment_status': paymentStatus,
      'payment_reference': paymentReference,
      'fulfillment_type': fulfillmentType,
      'donor': donorId,
      'appointment_details': appointmentDetails,
    };
  }
}
