import '../services/api_service.dart';

class ContactModel {
  final int id;
  final int userId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String role;
  final String? bloodGroup;
  final String? city;
  final String? region;
  final String? profilePicture;
  final String? hospitalName;
  final String? position;
  final int activeRequestsCount;
  final bool isEligible;
  final String? donorCode;
  final String? medicalConditions;

  ContactModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.bloodGroup,
    this.city,
    this.region,
    this.profilePicture,
    this.hospitalName,
    this.position,
    this.activeRequestsCount = 0,
    this.isEligible = true,
    this.donorCode,
    this.medicalConditions,
  });

  String? get fullProfilePictureUrl {
    if (profilePicture == null || profilePicture!.isEmpty) return null;
    if (profilePicture!.startsWith('http://') || profilePicture!.startsWith('https://')) {
      return profilePicture;
    }
    final server = ApiService.serverBaseUrl;
    final path = profilePicture!.startsWith('/') ? profilePicture : '/$profilePicture';
    return '$server$path';
  }

  String get displayRole {
    switch (role.toLowerCase()) {
      case 'donor':
        return 'Blood Donor';
      case 'patient':
        return 'Patient';
      case 'hospital_staff':
        return position ?? 'Hospital Staff';
      case 'blood_bank_admin':
        return 'Blood Bank Admin';
      case 'system_admin':
        return 'System Administrator';
      default:
        return role;
    }
  }

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    final uid = (json['user_id'] ?? json['id'] ?? 0) as int;
    return ContactModel(
      id: uid,
      userId: uid,
      fullName: json['full_name'] ?? json['fullName'] ?? 'Unknown User',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'] ?? '',
      role: json['role'] ?? 'user',
      bloodGroup: json['blood_group'] ?? json['bloodGroup'],
      city: json['city'],
      region: json['region'],
      profilePicture: json['profile_picture'] ?? json['profilePicture'],
      hospitalName: json['hospital_name'] ?? json['hospitalName'],
      position: json['position'],
      activeRequestsCount: (json['active_requests_count'] ?? 0) as int,
      isEligible: json['is_eligible'] ?? true,
      donorCode: json['donor_code'] ?? json['donorCode'],
      medicalConditions: json['medical_conditions'] ?? json['medicalConditions'],
    );
  }
}
