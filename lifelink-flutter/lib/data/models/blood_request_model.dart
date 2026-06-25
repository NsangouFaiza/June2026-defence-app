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
  final DateTime createdAt;
  final DateTime? updatedAt;

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
    required this.createdAt,
    this.updatedAt,
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
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
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
    };
  }
}
