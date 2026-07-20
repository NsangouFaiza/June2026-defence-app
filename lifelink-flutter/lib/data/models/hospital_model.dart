class HospitalModel {
  final int id;
  final String name;
  final String? address;
  final String? city;
  final String? region;
  final String? phoneNumber;
  final String? email;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String openingHours;
  final bool hasBloodBank;
  final bool hasEmergencyServices;
  final String? services;
  final bool isActive;
  final DateTime? createdAt;

  // Real-time dynamic distance calculated from user's current GPS location
  double? distanceKm;

  HospitalModel({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.region,
    this.phoneNumber,
    this.email,
    this.description,
    this.latitude,
    this.longitude,
    this.openingHours = '24/7 Emergency & Blood Bank',
    this.hasBloodBank = true,
    this.hasEmergencyServices = true,
    this.services = 'Blood Bank, Emergency Care, Transfusion, ICU, Lab Testing',
    required this.isActive,
    this.createdAt,
    this.distanceKm,
  });

  List<String> get servicesList {
    if (services == null || services!.trim().isEmpty) {
      return ['Blood Bank', 'Emergency Care', 'Transfusion'];
    }
    return services!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    return HospitalModel(
      id: json['id'] as int,
      name: json['name'] ?? '',
      address: json['address'],
      city: json['city'],
      region: json['region'],
      phoneNumber: json['phone_number'] ?? json['phoneNumber'],
      email: json['email'],
      description: json['description'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      openingHours: json['opening_hours'] as String? ?? '24/7 Emergency & Blood Bank',
      hasBloodBank: json['has_blood_bank'] as bool? ?? true,
      hasEmergencyServices: json['has_emergency_services'] as bool? ?? true,
      services: json['services'] as String? ?? 'Blood Bank, Emergency Care, Transfusion, ICU, Lab Testing',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'region': region,
      'phone_number': phoneNumber,
      'email': email,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'opening_hours': openingHours,
      'has_blood_bank': hasBloodBank,
      'has_emergency_services': hasEmergencyServices,
      'services': services,
      'is_active': isActive,
    };
  }
}
