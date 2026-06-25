class DonationModel {
  final int id;
  final int donorId;
  final String donorName;
  final int hospitalId;
  final String hospitalName;
  final String bloodGroup;
  final int units;
  final String status;
  final DateTime date;
  final String? notes;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  DonationModel({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.hospitalId,
    required this.hospitalName,
    required this.bloodGroup,
    required this.units,
    required this.status,
    required this.date,
    this.notes,
    this.verifiedAt,
    required this.createdAt,
  });

  factory DonationModel.fromJson(Map<String, dynamic> json) {
    return DonationModel(
      id: json['id'] as int,
      donorId: json['donor'] as int,
      donorName: json['donor_name'] ?? 'Unknown',
      hospitalId: json['hospital'] as int,
      hospitalName: json['hospital_name'] ?? 'Unknown',
      bloodGroup: json['blood_group'] ?? '',
      units: json['units'] ?? 1,
      status: json['status'] ?? 'PENDING',
      date: DateTime.parse(json['date']),
      notes: json['notes'],
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donor': donorId,
      'hospital': hospitalId,
      'blood_group': bloodGroup,
      'units': units,
      'status': status,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }
}
