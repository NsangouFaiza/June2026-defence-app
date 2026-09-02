import 'dart:io';
import '../services/api_service.dart';

class DonorModel {
  final int id;
  final int userId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? bloodGroup;
  final String? address;
  final String? city;
  final String? region;
  final int totalDonations;
  final int totalUnits;
  final bool isEligible;
  final String? eligibilityStatus;
  final String? eligibilityReason;
  final DateTime? lastDonationDate;
  final DateTime? nextEligibleDate;
  final DateTime? createdAt;
  final int points;
  final String level;
  final String? donorCode;
  
  final double? latitude;
  final double? longitude;
  final String? profilePicture;

  String get donorIdCode => (donorCode != null && donorCode!.isNotEmpty)
      ? donorCode!
      : 'DON-2026-${id.toString().padLeft(4, '0')}';

  String? get fullProfilePictureUrl {
    if (profilePicture == null || profilePicture!.isEmpty) return null;
    
    String url = profilePicture!;
    try {
      if (Platform.isAndroid) {
        url = url.replaceAll('127.0.0.1:8000', '10.0.2.2:8000')
                 .replaceAll('localhost:8000', '10.0.2.2:8000');
      }
    } catch (_) {}

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final server = ApiService.serverBaseUrl;
    final path = url.startsWith('/') ? url : '/$url';
    return '$server$path';
  }

  String get formattedLocation {
    final hasRegion = region != null && region!.trim().isNotEmpty && region != 'null';
    final hasCity = city != null && city!.trim().isNotEmpty && city != 'null';

    if (hasRegion && hasCity) {
      return '$region, $city';
    } else if (hasCity) {
      return city!;
    } else if (hasRegion) {
      return region!;
    } else if (address != null && address!.trim().isNotEmpty && address != 'null') {
      return address!;
    }
    return 'Location not provided';
  }

  String get formattedPhone {
    if (phoneNumber.trim().isEmpty || phoneNumber == 'null') {
      return 'Phone not provided';
    }
    return phoneNumber;
  }

  String get formattedEmail {
    if (email.trim().isEmpty || email == 'null') {
      return 'Email not provided';
    }
    return email;
  }

  int get age {
    if (dateOfBirth == null) return 25; // Default fallback age
    return DateTime.now().year - dateOfBirth!.year;
  }


  DonorModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.gender,
    this.dateOfBirth,
    this.bloodGroup,
    this.address,
    this.city,
    this.region,
    this.totalDonations = 0,
    this.totalUnits = 0,
    this.isEligible = true,
    this.eligibilityStatus,
    this.eligibilityReason,
    this.lastDonationDate,
    this.nextEligibleDate,
    this.createdAt,
    this.points = 0,
    this.level = 'Bronze',
    this.donorCode,
    this.latitude,
    this.longitude,
    this.profilePicture,
  });

  factory DonorModel.fromJson(Map<String, dynamic> json) {
    return DonorModel(
      id: json['id'] as int,
      userId: json['user'] is int
          ? json['user'] as int
          : (json['user']?['id'] as int? ?? 0),
      fullName: json['full_name'] ?? json['user']?['full_name'] ?? 'Unknown',
      email: json['email'] ?? json['user']?['email'] ?? '',
      phoneNumber: json['phone_number'] ?? json['user']?['phone_number'] ?? '',
      gender: json['gender'] ?? json['user']?['gender'],
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'])
          : (json['user']?['date_of_birth'] != null
              ? DateTime.parse(json['user']['date_of_birth'])
              : null),
      bloodGroup: json['blood_group'] ?? json['user']?['blood_group'],
      address: json['address'] ?? json['user']?['address'],
      city: json['city'] ?? json['user']?['city'],
      region: json['region'] ?? json['user']?['region'],
      totalDonations: json['total_donations'] ?? 0,
      totalUnits: json['total_blood_units'] ?? json['total_units'] ?? 0,
      isEligible: json['is_eligible'] ?? true,
      eligibilityStatus: json['eligibility_status'],
      eligibilityReason: json['eligibility_reason'],
      lastDonationDate: json['last_donation_date'] != null
          ? DateTime.parse(json['last_donation_date'])
          : null,
      nextEligibleDate: json['next_eligible_date'] != null
          ? DateTime.parse(json['next_eligible_date'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      points: json['points'] as int? ?? 0,
      level: json['level'] as String? ?? 'Bronze',
      donorCode: json['donor_code'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      profilePicture: json['profile_picture'] ?? json['user']?['profile_picture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': userId,
      'total_donations': totalDonations,
      'total_units': totalUnits,
      'is_eligible': isEligible,
      'eligibility_status': eligibilityStatus,
      'eligibility_reason': eligibilityReason,
      'last_donation_date': lastDonationDate?.toIso8601String(),
      'next_eligible_date': nextEligibleDate?.toIso8601String(),
      'points': points,
      'level': level,
      'latitude': latitude,
      'longitude': longitude,
      'profile_picture': profilePicture,
    };
  }
}
