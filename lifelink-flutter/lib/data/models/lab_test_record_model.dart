class LabTestRecordModel {
  final int id;
  final int? donor;
  final String? donorName;
  final int? inventoryUnit;
  final String sampleCode;
  final String bloodGroup;
  final String rhFactor;
  final String hivStatus;
  final String hepBStatus;
  final String hepCStatus;
  final String syphilisStatus;
  final String malariaStatus;
  final double hemoglobinGDl;
  final String unitStatus;
  final String? abnormalFindings;
  final bool hasAbnormalFindings;
  final int? testedBy;
  final String? testedByName;
  final DateTime testedAt;

  LabTestRecordModel({
    required this.id,
    this.donor,
    this.donorName,
    this.inventoryUnit,
    required this.sampleCode,
    required this.bloodGroup,
    required this.rhFactor,
    required this.hivStatus,
    required this.hepBStatus,
    required this.hepCStatus,
    required this.syphilisStatus,
    required this.malariaStatus,
    required this.hemoglobinGDl,
    required this.unitStatus,
    this.abnormalFindings,
    required this.hasAbnormalFindings,
    this.testedBy,
    this.testedByName,
    required this.testedAt,
  });

  factory LabTestRecordModel.fromJson(Map<String, dynamic> json) {
    return LabTestRecordModel(
      id: json['id'] as int,
      donor: json['donor'] as int?,
      donorName: json['donor_name'] as String?,
      inventoryUnit: json['inventory_unit'] as int?,
      sampleCode: json['sample_code'] as String? ?? 'LAB-0000',
      bloodGroup: json['blood_group'] as String? ?? 'O+',
      rhFactor: json['rh_factor'] as String? ?? 'POSITIVE',
      hivStatus: json['hiv_status'] as String? ?? 'NEGATIVE',
      hepBStatus: json['hep_b_status'] as String? ?? 'NEGATIVE',
      hepCStatus: json['hep_c_status'] as String? ?? 'NEGATIVE',
      syphilisStatus: json['syphilis_status'] as String? ?? 'NEGATIVE',
      malariaStatus: json['malaria_status'] as String? ?? 'NEGATIVE',
      hemoglobinGDl: json['hemoglobin_g_dl'] != null ? (json['hemoglobin_g_dl'] as num).toDouble() : 14.0,
      unitStatus: json['unit_status'] as String? ?? 'PENDING',
      abnormalFindings: json['abnormal_findings'] as String?,
      hasAbnormalFindings: json['has_abnormal_findings'] as bool? ?? false,
      testedBy: json['tested_by'] as int?,
      testedByName: json['tested_by_name'] as String?,
      testedAt: json['tested_at'] != null
          ? DateTime.parse(json['tested_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donor': donor,
      'inventory_unit': inventoryUnit,
      'sample_code': sampleCode,
      'blood_group': bloodGroup,
      'rh_factor': rhFactor,
      'hiv_status': hivStatus,
      'hep_b_status': hepBStatus,
      'hep_c_status': hepCStatus,
      'syphilis_status': syphilisStatus,
      'malaria_status': malariaStatus,
      'hemoglobin_g_dl': hemoglobinGDl,
      'unit_status': unitStatus,
      'abnormal_findings': abnormalFindings,
      'has_abnormal_findings': hasAbnormalFindings,
      'tested_by': testedBy,
      'tested_at': testedAt.toIso8601String(),
    };
  }
}
