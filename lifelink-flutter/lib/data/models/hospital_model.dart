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
  final bool isActive;
  final DateTime? createdAt;

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
    required this.isActive,
    this.createdAt,
  });

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
      'is_active': isActive,
    };
  }
}
