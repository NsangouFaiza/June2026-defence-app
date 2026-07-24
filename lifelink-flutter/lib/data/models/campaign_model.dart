import 'dart:io';
import '../services/api_service.dart';
import 'donor_model.dart';

class CampaignModel {
  final int id;
  final String title;
  final String subtitle;
  final String description;
  final String type;
  final String category;
  final String? imageUrl;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? registrationDeadline;
  final String? eventStartTime;
  final String? eventEndTime;
  final int? expectedDonors;
  final int? participantsCount;
  final bool isActive;
  final DateTime? createdAt;

  final String priority;
  final String? targetBloodGroup;
  final String? targetBloodGroups;
  final String? targetLocation;
  final String? targetEligibility;
  final String? eligibilityCriteria;
  final int? targetAgeMin;
  final int? targetAgeMax;
  final String genderRestriction;
  final String? city;
  final String? region;
  final double? targetRadius;
  
  final String? contactInfo;
  final String? organizerNotes;
  final String? participationInstructions;
  final String? benefitsRewards;
  final String? requiredDocuments;
  final String? hashtags;
  final String visibilitySettings;

  final DateTime? scheduledDelivery;
  final bool isSent;
  final String status;
  final int recipientCount;
  final int viewsCount;
  final int registeredCount;
  final int attendedCount;
  final int donatedCount;
  final bool isRegistered;

  List<String> get targetBloodGroupsList => targetBloodGroups != null && targetBloodGroups!.isNotEmpty
      ? targetBloodGroups!.split(',').map((e) => e.trim()).toList()
      : [];

  List<String> get requiredDocumentsList => requiredDocuments != null && requiredDocuments!.isNotEmpty
      ? requiredDocuments!.split(',').map((e) => e.trim()).toList()
      : [];

  List<String> get hashtagsList => hashtags != null && hashtags!.isNotEmpty
      ? hashtags!.split(',').map((e) => e.trim()).toList()
      : [];

  String? get fullImageUrl {
    if (imageUrl == null || imageUrl!.isEmpty) return null;
    
    String url = imageUrl!;
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

  CampaignModel({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.description,
    required this.type,
    this.category = 'Blood Donation',
    this.imageUrl,
    this.location,
    this.latitude,
    this.longitude,
    required this.startDate,
    required this.endDate,
    this.registrationDeadline,
    this.eventStartTime,
    this.eventEndTime,
    this.expectedDonors,
    this.participantsCount,
    required this.isActive,
    this.createdAt,
    this.priority = 'Normal',
    this.targetBloodGroup,
    this.targetBloodGroups,
    this.targetLocation,
    this.targetEligibility,
    this.eligibilityCriteria,
    this.targetAgeMin,
    this.targetAgeMax,
    this.genderRestriction = 'None',
    this.city,
    this.region,
    this.targetRadius,
    this.contactInfo,
    this.organizerNotes,
    this.participationInstructions,
    this.benefitsRewards,
    this.requiredDocuments,
    this.hashtags,
    this.visibilitySettings = 'Public',
    this.scheduledDelivery,
    this.isSent = false,
    this.status = 'DRAFT',
    this.recipientCount = 0,
    this.viewsCount = 0,
    this.registeredCount = 0,
    this.attendedCount = 0,
    this.donatedCount = 0,
    this.isRegistered = false,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return CampaignModel(
      id: json['id'] as int,
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      description: json['description'] ?? '',
      type: json['campaign_type'] ?? json['type'] ?? 'DONATION_AWARENESS',
      category: json['category'] ?? 'Blood Donation',
      imageUrl: json['image'],
      location: json['location'],
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      registrationDeadline: json['registration_deadline'] != null ? DateTime.parse(json['registration_deadline']) : null,
      eventStartTime: json['event_start_time'],
      eventEndTime: json['event_end_time'],
      expectedDonors: json['expected_donors'] as int?,
      participantsCount: json['participants'] != null 
          ? (json['participants'] as List).length 
          : (json['participants_count'] as int? ?? 0),
      isActive: json['status'] == 'PUBLISHED' || json['is_active'] == true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      priority: json['priority'] ?? 'Normal',
      targetBloodGroup: json['target_blood_group'],
      targetBloodGroups: json['target_blood_groups'],
      targetLocation: json['target_location'],
      targetEligibility: json['target_eligibility'],
      eligibilityCriteria: json['eligibility_criteria'],
      targetAgeMin: json['target_age_min'] as int?,
      targetAgeMax: json['target_age_max'] as int?,
      genderRestriction: json['gender_restriction'] ?? 'None',
      city: json['city'],
      region: json['region'],
      targetRadius: parseDouble(json['target_radius']),
      contactInfo: json['contact_info'],
      organizerNotes: json['organizer_notes'],
      participationInstructions: json['participation_instructions'],
      benefitsRewards: json['benefits_rewards'],
      requiredDocuments: json['required_documents'],
      hashtags: json['hashtags'],
      visibilitySettings: json['visibility_settings'] ?? 'Public',
      scheduledDelivery: json['scheduled_delivery'] != null ? DateTime.parse(json['scheduled_delivery']) : null,
      isSent: json['is_sent'] ?? false,
      status: json['status'] ?? 'DRAFT',
      recipientCount: json['recipient_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      registeredCount: json['registered_count'] ?? 0,
      attendedCount: json['attended_count'] ?? 0,
      donatedCount: json['donated_count'] ?? 0,
      isRegistered: json['is_registered'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'campaign_type': type,
      'category': category,
      'image': imageUrl,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'start_date': startDate.toIso8601String().substring(0, 10),
      'end_date': endDate.toIso8601String().substring(0, 10),
      'registration_deadline': registrationDeadline?.toIso8601String().substring(0, 10),
      'event_start_time': eventStartTime,
      'event_end_time': eventEndTime,
      'expected_donors': expectedDonors,
      'priority': priority,
      'target_blood_group': targetBloodGroup,
      'target_blood_groups': targetBloodGroups,
      'target_location': targetLocation,
      'target_eligibility': targetEligibility,
      'eligibility_criteria': eligibilityCriteria,
      'target_age_min': targetAgeMin,
      'target_age_max': targetAgeMax,
      'gender_restriction': genderRestriction,
      'city': city,
      'region': region,
      'target_radius': targetRadius,
      'contact_info': contactInfo,
      'organizer_notes': organizerNotes,
      'participation_instructions': participationInstructions,
      'benefits_rewards': benefitsRewards,
      'required_documents': requiredDocuments,
      'hashtags': hashtags,
      'visibility_settings': visibilitySettings,
      'scheduled_delivery': scheduledDelivery?.toIso8601String(),
      'is_sent': isSent,
      'status': status,
      'recipient_count': recipientCount,
    };
  }
}

class CampaignRegistrationModel {
  final int id;
  final int campaignId;
  final int donorId;
  final String status;
  final bool donated;
  final DateTime registeredAt;
  final DonorModel donorDetails;

  CampaignRegistrationModel({
    required this.id,
    required this.campaignId,
    required this.donorId,
    required this.status,
    required this.donated,
    required this.registeredAt,
    required this.donorDetails,
  });

  factory CampaignRegistrationModel.fromJson(Map<String, dynamic> json) {
    return CampaignRegistrationModel(
      id: json['id'] as int,
      campaignId: json['campaign'] as int,
      donorId: json['donor'] as int,
      status: json['status'] ?? 'REGISTERED',
      donated: json['donated'] ?? false,
      registeredAt: DateTime.parse(json['registered_at'] ?? DateTime.now().toIso8601String()),
      donorDetails: DonorModel.fromJson(json['donor_details'] as Map<String, dynamic>),
    );
  }
}
