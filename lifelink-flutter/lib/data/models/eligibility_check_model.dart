class EligibilityCheckModel {
  final int id;
  final int donorId;
  final int age;
  final double weight;
  final bool hasRecentSurgery;
  final bool isPregnant;
  final bool hasInfectiousDisease;
  final bool isOnMedication;
  final bool hasMedicalCondition;
  final String status;
  final String? notes;
  final DateTime checkedAt;

  EligibilityCheckModel({
    required this.id,
    required this.donorId,
    required this.age,
    required this.weight,
    required this.hasRecentSurgery,
    required this.isPregnant,
    required this.hasInfectiousDisease,
    required this.isOnMedication,
    required this.hasMedicalCondition,
    required this.status,
    this.notes,
    required this.checkedAt,
  });

  factory EligibilityCheckModel.fromJson(Map<String, dynamic> json) {
    return EligibilityCheckModel(
      id: json['id'] as int,
      donorId: json['donor'] as int,
      age: json['age'] ?? 0,
      weight: (json['weight'] ?? 0).toDouble(),
      hasRecentSurgery: json['has_recent_surgery'] ?? false,
      isPregnant: json['is_pregnant'] ?? false,
      hasInfectiousDisease: json['has_infectious_disease'] ?? false,
      isOnMedication: json['is_on_medication'] ?? false,
      hasMedicalCondition: json['has_medical_condition'] ?? false,
      status: json['status'] ?? 'UNKNOWN',
      notes: json['notes'],
      checkedAt: DateTime.parse(json['checked_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donor': donorId,
      'age': age,
      'weight': weight,
      'has_recent_surgery': hasRecentSurgery,
      'is_pregnant': isPregnant,
      'has_infectious_disease': hasInfectiousDisease,
      'is_on_medication': isOnMedication,
      'has_medical_condition': hasMedicalCondition,
      'status': status,
      'notes': notes,
    };
  }
}
