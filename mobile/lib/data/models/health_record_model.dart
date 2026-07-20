class HealthRecordModel {
  final int id;
  final int donor;
  final DateTime recordedAt;
  final double? hemoglobin;
  final int? systolicBp;
  final int? diastolicBp;
  final int? pulseRate;
  final double? weightKg;
  final double? temperatureC;
  final String screeningResult;
  final String? notes;

  HealthRecordModel({
    required this.id,
    required this.donor,
    required this.recordedAt,
    this.hemoglobin,
    this.systolicBp,
    this.diastolicBp,
    this.pulseRate,
    this.weightKg,
    this.temperatureC,
    required this.screeningResult,
    this.notes,
  });

  factory HealthRecordModel.fromJson(Map<String, dynamic> json) {
    return HealthRecordModel(
      id: json['id'] as int,
      donor: json['donor'] as int? ?? 0,
      recordedAt: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at'] as String)
          : DateTime.now(),
      hemoglobin: json['hemoglobin'] != null ? (json['hemoglobin'] as num).toDouble() : null,
      systolicBp: json['systolic_bp'] as int?,
      diastolicBp: json['diastolic_bp'] as int?,
      pulseRate: json['pulse_rate'] as int?,
      weightKg: json['weight_kg'] != null ? (json['weight_kg'] as num).toDouble() : null,
      temperatureC: json['temperature_c'] != null ? (json['temperature_c'] as num).toDouble() : null,
      screeningResult: json['screening_result'] as String? ?? 'PASSED',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donor': donor,
      'recorded_at': recordedAt.toIso8601String(),
      'hemoglobin': hemoglobin,
      'systolic_bp': systolicBp,
      'diastolic_bp': diastolicBp,
      'pulse_rate': pulseRate,
      'weight_kg': weightKg,
      'temperature_c': temperatureC,
      'screening_result': screeningResult,
      'notes': notes,
    };
  }
}
