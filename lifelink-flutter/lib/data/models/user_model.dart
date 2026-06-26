class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? bloodGroup;
  final String? address;
  final String? city;
  final String? region;
  final String role;
  final bool isActive;
  final bool? notificationPreferences;
  final bool? emailNotifications;
  final String language;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.gender,
    this.dateOfBirth,
    this.bloodGroup,
    this.address,
    this.city,
    this.region,
    required this.role,
    required this.isActive,
    this.notificationPreferences,
    this.emailNotifications,
    this.language = 'en',
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'] ?? '',
      gender: json['gender'],
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'])
          : null,
      bloodGroup: json['blood_group'] ?? json['bloodGroup'],
      address: json['address'],
      city: json['city'],
      region: json['region'],
      role: json['role'] ?? 'donor',
      isActive: json['is_active'] ?? true,
      notificationPreferences: json['notification_preferences'],
      emailNotifications: json['email_notifications'],
      language: json['language'] ?? 'en',
      createdAt: json['date_joined'] != null
          ? DateTime.parse(json['date_joined'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'gender': gender,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'blood_group': bloodGroup,
      'address': address,
      'city': city,
      'region': region,
      'role': role,
      'is_active': isActive,
      'notification_preferences': notificationPreferences,
      'email_notifications': emailNotifications,
      'language': language,
    };
  }
}
