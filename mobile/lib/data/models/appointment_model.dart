class AppointmentModel {
  final int id;
  final int donorId;
  final String donorName;
  final int hospitalId;
  final String hospitalName;
  final DateTime date;
  final String time;
  final String status;
  final String? notes;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;

  AppointmentModel({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.hospitalId,
    required this.hospitalName,
    required this.date,
    required this.time,
    required this.status,
    this.notes,
    this.confirmedAt,
    this.cancelledAt,
    required this.createdAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as int,
      donorId: json['donor'] as int,
      donorName: json['donor_name'] ?? 'Unknown',
      hospitalId: json['hospital'] as int,
      hospitalName: json['hospital_name'] ?? 'Unknown',
      date: DateTime.parse(json['date']),
      time: json['time'] ?? '',
      status: json['status'] ?? 'PENDING',
      notes: json['notes'],
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'])
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donor': donorId,
      'hospital': hospitalId,
      'date': date.toIso8601String(),
      'time': time,
      'status': status,
      'notes': notes,
    };
  }
}
