class BloodInventoryModel {
  final int id;
  final int hospitalId;
  final String hospitalName;
  final String bloodGroup;
  final int quantity;
  final DateTime collectionDate;
  final DateTime expirationDate;
  final String status;
  final DateTime? createdAt;

  BloodInventoryModel({
    required this.id,
    required this.hospitalId,
    required this.hospitalName,
    required this.bloodGroup,
    required this.quantity,
    required this.collectionDate,
    required this.expirationDate,
    required this.status,
    this.createdAt,
  });

  factory BloodInventoryModel.fromJson(Map<String, dynamic> json) {
    return BloodInventoryModel(
      id: json['id'] as int,
      hospitalId: json['hospital'] as int,
      hospitalName: json['hospital_name'] ?? 'Unknown Hospital',
      bloodGroup: json['blood_group'] ?? '',
      quantity: json['quantity'] ?? 0,
      collectionDate: DateTime.parse(json['collection_date']),
      expirationDate: DateTime.parse(json['expiration_date']),
      status: json['status'] ?? 'available',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hospital': hospitalId,
      'blood_group': bloodGroup,
      'quantity': quantity,
      'collection_date': collectionDate.toIso8601String(),
      'expiration_date': expirationDate.toIso8601String(),
      'status': status,
    };
  }
}
