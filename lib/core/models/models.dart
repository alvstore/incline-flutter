/// Data models for the Incline mobile platform matching Supabase schema.
library;

import 'package:intl/intl.dart';
import '../config/env_config.dart';

class Profile {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final bool mustSetPassword;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? governmentIdType;
  final String? governmentIdNumber;
  final bool governmentIdVerified;

  const Profile({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.mustSetPassword = false,
    this.gender,
    this.dateOfBirth,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.governmentIdType,
    this.governmentIdNumber,
    this.governmentIdVerified = false,
  });

  /// Dynamic calculation of member's current chronological age in years
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int a = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      a--;
    }
    return a >= 0 ? a : null;
  }

  /// Formatted date of birth string, e.g. "31 Jul 1997"
  String get formattedDob {
    if (dateOfBirth == null) return 'Not Provided';
    return DateFormat('d MMM yyyy').format(dateOfBirth!);
  }

  /// Formatted full residential address
  String get formattedAddress {
    final parts = [
      if (address != null && address!.trim().isNotEmpty) address!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (postalCode != null && postalCode!.trim().isNotEmpty) postalCode!.trim(),
    ];
    return parts.isEmpty ? 'Not Provided' : parts.join(', ');
  }

  /// Formatted masked Aadhaar number (e.g. XXXX XXXX 8209)
  String get maskedAadhaar {
    if (governmentIdNumber == null || governmentIdNumber!.trim().isEmpty) {
      return 'Not Provided';
    }
    final raw = governmentIdNumber!.replaceAll(RegExp(r'\s+'), '');
    if (raw.length >= 12) {
      final last4 = raw.substring(raw.length - 4);
      return 'XXXX XXXX $last4';
    }
    return raw;
  }

  Profile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    bool? mustSetPassword,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? governmentIdType,
    String? governmentIdNumber,
    bool? governmentIdVerified,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      mustSetPassword: mustSetPassword ?? this.mustSetPassword,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      governmentIdType: governmentIdType ?? this.governmentIdType,
      governmentIdNumber: governmentIdNumber ?? this.governmentIdNumber,
      governmentIdVerified: governmentIdVerified ?? this.governmentIdVerified,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDob;
    final rawDob = json['date_of_birth'] ?? json['dob'];
    if (rawDob != null) {
      parsedDob = DateTime.tryParse(rawDob.toString());
    }

    return Profile(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Incline Member',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['photo_url'] as String?,
      mustSetPassword: json['must_set_password'] as bool? ?? false,
      gender: json['gender'] as String?,
      dateOfBirth: parsedDob,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      postalCode: json['postal_code'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      governmentIdType: json['government_id_type'] as String?,
      governmentIdNumber: json['government_id_number'] as String? ?? json['aadhaar_number'] as String?,
      governmentIdVerified: json['government_id_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'avatar_url': avatarUrl,
    'must_set_password': mustSetPassword,
    'gender': gender,
    'date_of_birth': dateOfBirth?.toIso8601String(),
    'address': address,
    'city': city,
    'state': state,
    'country': country,
    'postal_code': postalCode,
    'emergency_contact_name': emergencyContactName,
    'emergency_contact_phone': emergencyContactPhone,
    'government_id_type': governmentIdType,
    'government_id_number': governmentIdNumber,
    'government_id_verified': governmentIdVerified,
  };
}

class Member {
  final String id;
  final String memberCode;
  final String? branchId;
  final String status;
  final String? fitnessGoals;
  final String? assignedTrainer;
  final String? assignedTrainerId;
  final String? biometricPhotoUrl;
  final Profile? profile;
  final Branch? branch;

  const Member({
    required this.id,
    required this.memberCode,
    this.branchId,
    this.status = 'active',
    this.fitnessGoals,
    this.assignedTrainer,
    this.assignedTrainerId,
    this.biometricPhotoUrl,
    this.profile,
    this.branch,
  });

  String get fullName => profile?.fullName ?? 'Incline Member';
  String? get avatarUrl => profile?.avatarUrl ?? biometricPhotoUrl;
  String get branchName => branch?.name ?? 'INCLINE Club';

  Member copyWith({
    String? id,
    String? memberCode,
    String? branchId,
    String? status,
    String? fitnessGoals,
    String? assignedTrainer,
    String? assignedTrainerId,
    String? biometricPhotoUrl,
    Profile? profile,
    Branch? branch,
  }) {
    return Member(
      id: id ?? this.id,
      memberCode: memberCode ?? this.memberCode,
      branchId: branchId ?? this.branchId,
      status: status ?? this.status,
      fitnessGoals: fitnessGoals ?? this.fitnessGoals,
      assignedTrainer: assignedTrainer ?? this.assignedTrainer,
      assignedTrainerId: assignedTrainerId ?? this.assignedTrainerId,
      biometricPhotoUrl: biometricPhotoUrl ?? this.biometricPhotoUrl,
      profile: profile ?? this.profile,
      branch: branch ?? this.branch,
    );
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String? ?? '',
      memberCode: json['member_code'] as String? ?? 'INC-0000',
      branchId: json['branch_id'] as String?,
      status: json['status'] as String? ?? 'active',
      fitnessGoals: json['fitness_goals'] as String?,
      assignedTrainer: json['assigned_trainer'] as String?,
      assignedTrainerId: json['assigned_trainer_id'] as String?,
      biometricPhotoUrl: json['biometric_photo_url'] as String? ??
          json['photo_url'] as String? ??
          json['avatar_url'] as String?,
      profile: json['profiles'] != null
          ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
      branch: json['branches'] != null && json['branches'] is Map<String, dynamic>
          ? Branch.fromJson(json['branches'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'member_code': memberCode,
    'branch_id': branchId,
    'status': status,
    'fitness_goals': fitnessGoals,
    'assigned_trainer': assignedTrainer,
    'assigned_trainer_id': assignedTrainerId,
    'biometric_photo_url': biometricPhotoUrl,
    'profiles': profile?.toJson(),
    if (branch != null) 'branches': branch!.toJson(),
  };
}

class ClubFacility {
  final String icon;
  final String title;
  final String description;

  const ClubFacility({
    required this.icon,
    required this.title,
    required this.description,
  });

  factory ClubFacility.fromJson(Map<String, dynamic> json) {
    return ClubFacility(
      icon: json['icon'] as String? ?? 'dumbbell',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class Branch {
  final String id;
  final String name;
  final String tagline;
  final String code;
  final String address;
  final String city;
  final String state;
  final String postalCode;
  final String phone;
  final String email;
  final String gstin;
  final String openingTime;
  final String closingTime;
  final List<ClubFacility> facilities;

  const Branch({
    required this.id,
    this.name = 'INCLINE Club',
    this.tagline = 'Rise. Reflect. Repeat.',
    this.code = 'INC',
    this.address = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.phone = '',
    this.email = '',
    this.gstin = '',
    this.openingTime = '06:00 AM',
    this.closingTime = '10:00 PM',
    this.facilities = const [
      ClubFacility(
        icon: 'dumbbell',
        title: 'Premium Equipment',
        description: 'State-of-the-art fitness machines, Eleiko bars & calibrated free weights',
      ),
      ClubFacility(
        icon: 'users',
        title: 'Expert Trainers',
        description: 'Certified personal performance coaches to elevate your fitness journey',
      ),
      ClubFacility(
        icon: 'activity',
        title: 'Group Classes & Conditioning',
        description: 'High-intensity athletic conditioning, mobility, and functional sessions',
      ),
      ClubFacility(
        icon: 'clock',
        title: '24/7 Member Access',
        description: 'Train anytime with round-the-clock member access protocol',
      ),
    ],
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    // Check website_theme if loaded from get_org_branding
    final theme = json['website_theme'] is Map<String, dynamic>
        ? json['website_theme'] as Map<String, dynamic>
        : null;

    final themeFeatures = (theme?['features'] as List?)
            ?.map((f) => ClubFacility.fromJson(f as Map<String, dynamic>))
            .toList() ??
        const [];

    return Branch(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'INCLINE Club',
      tagline: json['tagline'] as String? ?? 'Rise. Reflect. Repeat.',
      code: json['code'] as String? ?? 'INC',
      address: theme?['address'] as String? ??
          json['address'] as String? ??
          '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      phone: theme?['contactPhone'] as String? ??
          json['phone'] as String? ??
          '',
      email: theme?['contactEmail'] as String? ??
          json['email'] as String? ??
          '',
      gstin: json['gstin'] as String? ?? '',
      openingTime: json['opening_time'] as String? ?? '06:00 AM',
      closingTime: json['closing_time'] as String? ?? '10:00 PM',
      facilities: themeFeatures.isNotEmpty
          ? themeFeatures
          : const [
              ClubFacility(
                icon: 'dumbbell',
                title: 'Premium Equipment',
                description: 'State-of-the-art fitness machines and free weights',
              ),
              ClubFacility(
                icon: 'users',
                title: 'Expert Trainers',
                description: 'Certified personal performance coaches to guide your journey',
              ),
              ClubFacility(
                icon: 'activity',
                title: 'Group Classes',
                description: 'Athletic conditioning, mobility & functional movement',
              ),
              ClubFacility(
                icon: 'clock',
                title: '24/7 Access',
                description: 'Train anytime with round-the-clock member access protocol',
              ),
            ],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tagline': tagline,
    'code': code,
    'address': address,
    'city': city,
    'state': state,
    'postal_code': postalCode,
    'phone': phone,
    'email': email,
    'gstin': gstin,
    'opening_time': openingTime,
    'closing_time': closingTime,
  };
}

class MyTrainer {
  final String trainerId;
  final String fullName;
  final String? avatarUrl;
  final String? trainerCode;
  final List<String> specializations;
  final String relation; // 'assigned', 'pt_package', 'pt_session', 'class'
  final String? phone;

  const MyTrainer({
    required this.trainerId,
    required this.fullName,
    this.avatarUrl,
    this.trainerCode,
    this.specializations = const [],
    this.relation = 'assigned',
    this.phone,
  });

  bool get isAssigned => relation == 'assigned';

  factory MyTrainer.fromJson(Map<String, dynamic> json) {
    return MyTrainer(
      trainerId: json['trainer_id'] as String? ?? json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Incline Coach',
      avatarUrl: json['avatar_url'] as String?,
      trainerCode: json['trainer_code'] as String? ?? 'TR-INC',
      specializations: (json['specializations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      relation: json['relation'] as String? ?? 'assigned',
      phone: json['phone'] as String? ??
          json['mobile'] as String? ??
          json['contact'] as String? ??
          json['phone_number'] as String?,
    );
  }
}

class MemberRequest {
  final String id;
  final String referenceType; // 'membership_freeze', 'trainer_change', 'locker', 'diet', 'workout', 'general_inquiry'
  final String title;
  final String? reason;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final String? reviewNotes;

  const MemberRequest({
    required this.id,
    required this.referenceType,
    required this.title,
    this.reason,
    this.status = 'pending',
    required this.createdAt,
    this.reviewNotes,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved' || status == 'completed';
  bool get isRejected => status == 'rejected' || status == 'cancelled';

  factory MemberRequest.fromApprovalRequest(Map<String, dynamic> json) {
    final ref = json['reference_type'] as String? ?? 'general_inquiry';
    final reqData = json['request_data'] as Map<String, dynamic>? ?? {};
    
    String label = 'Service Request';
    if (ref == 'trainer_change') {
      label = 'Trainer Consultation / Allocation';
    } else if (ref == 'membership_freeze') {
      label = 'Membership Freeze / Hold';
    } else if (ref == 'membership_unfreeze') {
      label = 'Membership Resume / Unfreeze';
    } else if (ref == 'locker') {
      label = 'Locker Allocation';
    } else if (ref == 'general_inquiry') {
      label = 'Front Desk Inquiry';
    }

    return MemberRequest(
      id: json['id'] as String? ?? '',
      referenceType: ref,
      title: reqData['title'] as String? ?? label,
      reason: reqData['reason'] as String? ?? reqData['note'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      reviewNotes: json['review_notes'] as String?,
    );
  }

  factory MemberRequest.fromTask(Map<String, dynamic> json) {
    final rawTitle = json['title'] as String? ?? 'Service Task';
    final titleLower = rawTitle.toLowerCase();
    final isPtPurchase = titleLower.contains('pt purchase') ||
        titleLower.contains('personal training') ||
        titleLower.contains('pt request');
    final isDiet = titleLower.contains('diet');
    final isWorkout = titleLower.contains('workout');

    String refType = 'general_inquiry';
    String displayTitle = rawTitle;

    if (isPtPurchase) {
      refType = 'pt_purchase';
      displayTitle = rawTitle;
    } else if (isDiet) {
      refType = 'diet';
      displayTitle = rawTitle.toLowerCase().startsWith('diet') ? rawTitle : 'Personalised Diet Plan Request';
    } else if (isWorkout) {
      refType = 'workout';
      displayTitle = rawTitle.toLowerCase().startsWith('workout') ? rawTitle : 'Personalised Workout Plan Request';
    }

    return MemberRequest(
      id: json['id'] as String? ?? '',
      referenceType: refType,
      title: displayTitle,
      reason: json['description'] as String?,
      status: json['status'] == 'completed' ? 'approved' : json['status'] == 'cancelled' ? 'rejected' : 'pending',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      reviewNotes: null,
    );
  }
}

class MemberFeedbackItem {
  final String id;
  final int rating;
  final String category;
  final String? feedbackText;
  final String status;
  final DateTime createdAt;

  const MemberFeedbackItem({
    required this.id,
    required this.rating,
    required this.category,
    this.feedbackText,
    this.status = 'pending',
    required this.createdAt,
  });

  factory MemberFeedbackItem.fromJson(Map<String, dynamic> json) {
    return MemberFeedbackItem(
      id: json['id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      category: json['category'] as String? ?? 'general',
      feedbackText: json['feedback_text'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

class StoreProduct {
  final String id;
  final String name;
  final String? description;
  final String category;
  final double price;
  final String? imageUrl;
  final bool isSellable;
  final bool isActive;

  const StoreProduct({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.price,
    this.imageUrl,
    this.isSellable = true,
    this.isActive = true,
  });

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    final rawPrice = (json['price'] as num?)?.toDouble() ?? 0.0;
    final costPrice = (json['cost_price'] as num?)?.toDouble() ?? 0.0;
    double computedPrice = rawPrice;
    if (computedPrice <= 0 && costPrice > 0) {
      computedPrice = (costPrice * 1.25).roundToDouble();
    }
    if (computedPrice <= 0) computedPrice = 499.0;

    return StoreProduct(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Incline Product',
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'Supplements',
      price: computedPrice,
      imageUrl: json['image_url'] as String?,
      isSellable: json['is_sellable'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class Membership {
  final String id;
  final String memberId;
  final String planName;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int daysRemaining;

  const Membership({
    required this.id,
    required this.memberId,
    required this.planName,
    required this.status,
    this.startDate,
    this.endDate,
    this.daysRemaining = 0,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    DateTime? start = json['start_date'] != null
        ? DateTime.tryParse(json['start_date'] as String)
        : null;
    DateTime? end = json['end_date'] != null
        ? DateTime.tryParse(json['end_date'] as String)
        : null;
    int remaining = 0;
    if (end != null) {
      final now = DateTime.now();
      final endCal = DateTime(end.year, end.month, end.day);
      final nowCal = DateTime(now.year, now.month, now.day);
      remaining = endCal.difference(nowCal).inDays;
      if (remaining < 0) remaining = 0;
    }

    String pName = "Essential Annual - Founder's Pass";
    if (json['membership_plans'] != null && json['membership_plans'] is Map) {
      pName = json['membership_plans']['name'] as String? ?? pName;
    } else if (json['plan_name'] != null) {
      pName = json['plan_name'] as String;
    }

    return Membership(
      id: json['id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      planName: pName,
      status: json['status'] as String? ?? 'active',
      startDate: start,
      endDate: end,
      daysRemaining: remaining,
    );
  }
}

class BenefitCredit {
  final String id;
  final String benefitType;
  final int creditsTotal;
  final int creditsRemaining;
  final DateTime? expiresAt;
  final bool isAddOn;

  const BenefitCredit({
    required this.id,
    required this.benefitType,
    required this.creditsTotal,
    required this.creditsRemaining,
    this.expiresAt,
    this.isAddOn = false,
  });

  factory BenefitCredit.fromJson(Map<String, dynamic> json) {
    return BenefitCredit(
      id: json['id'] as String? ?? '',
      benefitType: json['benefit_type'] as String? ?? 'other',
      creditsTotal: (json['credits_total'] as num?)?.toInt() ?? 0,
      creditsRemaining: (json['credits_remaining'] as num?)?.toInt() ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      isAddOn: json['package_id'] != null,
    );
  }
}

class BenefitPackage {
  final String id;
  final String name;
  final String? description;
  final String benefitType;
  final int quantity;
  final double price;
  final int validityDays;

  const BenefitPackage({
    required this.id,
    required this.name,
    this.description,
    required this.benefitType,
    required this.quantity,
    required this.price,
    required this.validityDays,
  });

  factory BenefitPackage.fromJson(Map<String, dynamic> json) {
    return BenefitPackage(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Add-On Pack',
      description: json['description'] as String?,
      benefitType: json['benefit_type'] as String? ?? 'sauna_access',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      validityDays: (json['validity_days'] as num?)?.toInt() ?? 30,
    );
  }
}

class RecoverySlot {
  final String id;
  final String facilityName;
  final String benefitType;
  final String slotDate;
  final String startTime;
  final String endTime;
  final int capacity;
  final int bookedCount;
  final bool isFreeWithPlan;
  final double? addOnPrice;

  const RecoverySlot({
    required this.id,
    required this.facilityName,
    required this.benefitType,
    required this.slotDate,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.bookedCount,
    this.isFreeWithPlan = false,
    this.addOnPrice,
  });

  int get spotsRemaining => (capacity - bookedCount).clamp(0, capacity);
  bool get isFull => spotsRemaining <= 0;

  factory RecoverySlot.fromJson(Map<String, dynamic> json, {bool isFree = false, double? price}) {
    final facility = json['facility'] as Map<String, dynamic>? ?? json['facilities'] as Map<String, dynamic>?;
    final benefitTypeInfo = json['benefit_type_info'] as Map<String, dynamic>? ?? json['benefit_types'] as Map<String, dynamic>?;
    final bType = (json['benefit_type'] as String? ?? 'steam_access').toLowerCase();

    String facName = facility?['name'] as String? ??
        benefitTypeInfo?['name'] as String? ??
        json['facility_name'] as String? ??
        '';

    if (facName.isEmpty) {
      if (bType.contains('steam')) {
        facName = 'Steam Room Male';
      } else if (bType.contains('sauna')) {
        facName = 'Sauna Therapy Male';
      } else if (bType.contains('ice') || bType.contains('cold') || bType.contains('plunge')) {
        facName = 'Cold Plunge Male';
      } else if (bType.contains('red') || bType.contains('light')) {
        facName = 'Spectrum Red-Light Lounge';
      } else {
        facName = 'Incline Suite';
      }
    }

    final isSteam = bType.contains('steam') || bType == 'steam_access';
    final actualIsFree = isFree || isSteam;
    final actualPrice = actualIsFree ? 0.0 : (price ?? 1500.0);

    String formatSlotTime(String? raw) {
      if (raw == null || raw.isEmpty) return '';
      final trimmed = raw.trim();
      if (trimmed.toUpperCase().contains('AM') || trimmed.toUpperCase().contains('PM')) {
        return trimmed;
      }
      try {
        final parts = trimmed.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          final dt = DateTime(2026, 1, 1, hour, minute);
          return DateFormat('hh:mm a').format(dt);
        }
      } catch (_) {}
      return trimmed;
    }

    return RecoverySlot(
      id: json['id'] as String? ?? '',
      facilityName: facName,
      benefitType: bType,
      slotDate: json['slot_date'] as String? ?? '',
      startTime: formatSlotTime(json['start_time'] as String?),
      endTime: formatSlotTime(json['end_time'] as String?),
      capacity: (json['capacity'] as num?)?.toInt() ?? 4,
      bookedCount: (json['booked_count'] as num?)?.toInt() ?? 0,
      isFreeWithPlan: actualIsFree,
      addOnPrice: actualPrice,
    );
  }
}

class WorkoutExercise {
  final String name;
  final int sets;
  final String reps;
  final String? rest;
  final String? notes;
  final String? machineName;
  final String? coachCue;
  final String? load;
  final String? videoUrl;
  final String? imageUrl;
  final bool showVideo;
  bool isCompleted;

  WorkoutExercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.rest,
    this.notes,
    this.machineName,
    this.coachCue,
    this.load,
    this.videoUrl,
    this.imageUrl,
    this.showVideo = true,
    this.isCompleted = false,
  });

  /// Normalizes relative video paths to the Supabase public storage bucket URL
  static String? _resolveVideoUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final cleanPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '${EnvConfig.supabaseUrl}/storage/v1/object/public/workout-videos/$cleanPath';
  }

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    String? cue = json['coach_cue'] as String? ?? json['cue'] as String?;
    if (cue == null && json['form_tips'] != null) {
      if (json['form_tips'] is List) {
        cue = (json['form_tips'] as List).map((e) => e.toString()).join(' • ');
      } else {
        cue = json['form_tips'].toString();
      }
    }

    final rawVideo = json['video_url'] as String? ?? json['video_file_path'] as String?;
    final rawImage = json['image_url'] as String? ??
        json['photo_url'] as String? ??
        json['thumbnail_url'] as String?;

    final resolvedVideo = _resolveVideoUrl(rawVideo);
    final hasValidVideo = resolvedVideo != null && resolvedVideo.isNotEmpty;

    // Backend toggle: respects 'show_video', 'video_enabled', 'enable_video', 'display_video'
    // If backend sets toggle to false -> showVideo is false (only show image).
    // If backend sets toggle to true -> showVideo is true (show inline video).
    // If not specified -> showVideo is true if valid video exists, otherwise false.
    final bool? backendToggle = json['show_video'] as bool? ??
        json['video_enabled'] as bool? ??
        json['enable_video'] as bool? ??
        json['display_video'] as bool?;
    final bool effectiveShowVideo = backendToggle ?? hasValidVideo;

    return WorkoutExercise(
      name: json['name'] as String? ?? json['exercise'] as String? ?? 'Exercise',
      sets: (json['sets'] is num
              ? (json['sets'] as num).toInt()
              : (num.tryParse(json['sets']?.toString().trim() ?? '')?.toInt())) ?? 3,
      reps: json['reps']?.toString() ?? '10-12',
      rest: json['rest']?.toString() ?? (json['rest_seconds'] != null ? '${json['rest_seconds']}s' : '60s'),
      notes: json['notes'] as String? ?? json['tempo'] as String?,
      machineName: json['machine_name'] as String? ?? json['machine'] as String? ?? json['equipment'] as String?,
      coachCue: cue,
      load: json['load']?.toString() ?? json['weight']?.toString(),
      videoUrl: resolvedVideo,
      imageUrl: rawImage,
      showVideo: effectiveShowVideo,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  /// Helper to get numeric rest seconds for interactive timer
  int get restSeconds {
    if (rest == null) return 60;
    final digits = rest!.replaceAll(RegExp(r'\D'), '');
    return int.tryParse(digits) ?? 60;
  }

  WorkoutExercise copyWith({
    String? name,
    int? sets,
    String? reps,
    String? rest,
    String? notes,
    String? machineName,
    String? coachCue,
    String? load,
    String? videoUrl,
    String? imageUrl,
    bool? showVideo,
    bool? isCompleted,
  }) {
    return WorkoutExercise(
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      rest: rest ?? this.rest,
      notes: notes ?? this.notes,
      machineName: machineName ?? this.machineName,
      coachCue: coachCue ?? this.coachCue,
      load: load ?? this.load,
      videoUrl: videoUrl ?? this.videoUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      showVideo: showVideo ?? this.showVideo,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'sets': sets,
    'reps': reps,
    'rest': rest,
    'notes': notes,
    'machine_name': machineName,
    'coach_cue': coachCue,
    'load': load,
    'video_url': videoUrl,
    'image_url': imageUrl,
    'show_video': showVideo,
    'is_completed': isCompleted,
  };
}

class WorkoutDay {
  final String id;
  final String dayLabel;
  final String? weekLabel;
  final String? focus;
  final bool isRest;
  final List<WorkoutExercise> exercises;
  final int? weekdayIndex;
  final String? warmUp;
  final String? coolDown;

  const WorkoutDay({
    required this.id,
    required this.dayLabel,
    this.weekLabel,
    this.focus,
    this.isRest = false,
    required this.exercises,
    this.weekdayIndex,
    this.warmUp,
    this.coolDown,
  });

  int get totalSets => exercises.fold(0, (sum, ex) => sum + ex.sets);
  int get estimatedMinutes => isRest ? 0 : (exercises.length * 5).clamp(20, 90);
  int get completedExercisesCount => exercises.where((ex) => ex.isCompleted).length;

  WorkoutDay copyWith({
    String? id,
    String? dayLabel,
    String? weekLabel,
    String? focus,
    bool? isRest,
    List<WorkoutExercise>? exercises,
    int? weekdayIndex,
    String? warmUp,
    String? coolDown,
  }) {
    return WorkoutDay(
      id: id ?? this.id,
      dayLabel: dayLabel ?? this.dayLabel,
      weekLabel: weekLabel ?? this.weekLabel,
      focus: focus ?? this.focus,
      isRest: isRest ?? this.isRest,
      exercises: exercises ?? this.exercises,
      weekdayIndex: weekdayIndex ?? this.weekdayIndex,
      warmUp: warmUp ?? this.warmUp,
      coolDown: coolDown ?? this.coolDown,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'day_label': dayLabel,
    'week_label': weekLabel,
    'focus': focus,
    'is_rest': isRest,
    'weekday_index': weekdayIndex,
    'warm_up': warmUp,
    'cool_down': coolDown,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    final rawEx = json['exercises'] as List<dynamic>? ?? [];
    final exercises = rawEx.map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>)).toList();
    return WorkoutDay(
      id: json['id'] as String? ?? '',
      dayLabel: json['day_label'] as String? ?? 'Day',
      weekLabel: json['week_label'] as String?,
      focus: json['focus'] as String?,
      isRest: json['is_rest'] as bool? ?? false,
      weekdayIndex: json['weekday_index'] as int?,
      warmUp: json['warm_up'] as String?,
      coolDown: json['cool_down'] as String?,
      exercises: exercises,
    );
  }
}

class WorkoutPlan {
  final String id;
  final String planName;
  final String? description;
  final String? trainerName;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final List<WorkoutDay> days;
  final bool isPersonalTraining;
  final String targetGoal;
  final String? pdfUrl;
  final String? docId;
  final String? quote;
  final List<String> dos;
  final List<String> donts;
  final List<String> proTips;
  final bool isCustomAssigned;

  const WorkoutPlan({
    required this.id,
    required this.planName,
    this.description,
    this.trainerName,
    this.validFrom,
    this.validUntil,
    required this.days,
    this.isPersonalTraining = false,
    this.targetGoal = 'General Fitness',
    this.pdfUrl,
    this.docId,
    this.quote,
    this.dos = const [],
    this.donts = const [],
    this.proTips = const [],
    this.isCustomAssigned = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan_name': planName,
    'description': description,
    'trainer_name': trainerName,
    'valid_from': validFrom?.toIso8601String(),
    'valid_until': validUntil?.toIso8601String(),
    'is_personal_training': isPersonalTraining,
    'target_goal': targetGoal,
    'pdf_url': pdfUrl,
    'doc_id': docId,
    'quote': quote,
    'dos': dos,
    'donts': donts,
    'pro_tips': proTips,
    'is_custom_assigned': isCustomAssigned,
    'days': days.map((d) => d.toJson()).toList(),
  };

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? [];
    final days = rawDays.map((d) => WorkoutDay.fromJson(d as Map<String, dynamic>)).toList();
    return WorkoutPlan(
      id: json['id'] as String? ?? '',
      planName: json['plan_name'] as String? ?? 'Assigned Workout Program',
      description: json['description'] as String?,
      trainerName: json['trainer_name'] as String?,
      validFrom: json['valid_from'] != null ? DateTime.tryParse(json['valid_from'].toString()) : null,
      validUntil: json['valid_until'] != null ? DateTime.tryParse(json['valid_until'].toString()) : null,
      days: days,
      isPersonalTraining: json['is_personal_training'] as bool? ?? false,
      targetGoal: json['target_goal'] as String? ?? 'General Fitness',
      pdfUrl: json['pdf_url'] as String?,
      docId: json['doc_id'] as String?,
      quote: json['quote'] as String?,
      dos: (json['dos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      donts: (json['donts'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      proTips: (json['pro_tips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isCustomAssigned: json['is_custom_assigned'] as bool? ?? false,
    );
  }

  WorkoutPlan copyWith({
    String? id,
    String? planName,
    String? description,
    String? trainerName,
    DateTime? validFrom,
    DateTime? validUntil,
    List<WorkoutDay>? days,
    bool? isPersonalTraining,
    String? targetGoal,
    String? pdfUrl,
    String? docId,
    String? quote,
    List<String>? dos,
    List<String>? donts,
    List<String>? proTips,
    bool? isCustomAssigned,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      planName: planName ?? this.planName,
      description: description ?? this.description,
      trainerName: trainerName ?? this.trainerName,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      days: days ?? this.days,
      isPersonalTraining: isPersonalTraining ?? this.isPersonalTraining,
      targetGoal: targetGoal ?? this.targetGoal,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      docId: docId ?? this.docId,
      quote: quote ?? this.quote,
      dos: dos ?? this.dos,
      donts: donts ?? this.donts,
      proTips: proTips ?? this.proTips,
      isCustomAssigned: isCustomAssigned ?? this.isCustomAssigned,
    );
  }
}

class AttendanceRecord {
  final String id;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String branchName;
  final String method;
  final String gateCheckIn;
  final String? gateCheckOut;
  final String facialConfidence;

  const AttendanceRecord({
    required this.id,
    required this.checkInTime,
    this.checkOutTime,
    required this.branchName,
    this.method = 'MIPS Facial Biometric',
    this.gateCheckIn = 'Turnstile Gate A • North Portal',
    this.gateCheckOut = 'Turnstile Gate B • South Portal',
    this.facialConfidence = '99.8%',
  });

  bool get isCurrentlyActive => checkOutTime == null;

  String get durationFormatted {
    if (checkOutTime == null) return 'Active in Club';
    final diff = checkOutTime!.difference(checkInTime);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '$mins mins';
  }
}

class InvoiceItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double taxAmount;
  final double taxRate;
  final double totalAmount;
  final String hsnCode;

  const InvoiceItem({
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
    this.taxAmount = 0.0,
    this.taxRate = 18.0,
    required this.totalAmount,
    this.hsnCode = '999723',
  });
}

class MemberInvoice {
  final String id;
  final String invoiceNumber;
  final String invoiceType; // 'membership', 'addon', 'store'
  final DateTime createdAt;
  final String status; // 'paid', 'pending', 'refunded'
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final double amountPaid;
  final String paymentMethod;
  final String transactionRef;
  final bool isGstInvoice;
  final double gstRate;
  final String gstin;
  final String? notes;
  final List<InvoiceItem> items;

  const MemberInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceType,
    required this.createdAt,
    this.status = 'paid',
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.amountPaid,
    this.paymentMethod = 'UPI • Incline Pay',
    this.transactionRef = '',
    this.isGstInvoice = true,
    this.gstRate = 0.0,
    this.gstin = '',
    this.notes,
    this.items = const [],
  });

  bool get isPaid => status.toLowerCase() == 'paid';

  /// Whether the invoice actually carries GST (taxAmount > 0 and flagged as GST invoice)
  bool get hasGst => taxAmount > 0;

  /// Effective combined GST percentage rate (e.g. 18.0 for 18% GST)
  double get effectiveGstRate {
    if (gstRate > 0) return gstRate;
    if (items.isNotEmpty && items.first.taxRate > 0) return items.first.taxRate;
    if (subtotal > 0 && taxAmount > 0) {
      final calculated = (taxAmount / subtotal) * 100;
      return double.parse(calculated.toStringAsFixed(1));
    }
    return 18.0;
  }

  /// Formatted total GST rate (e.g. "18%" or "5%")
  String get gstRateFormatted {
    final r = effectiveGstRate;
    return r % 1 == 0 ? '${r.toInt()}%' : '${r.toStringAsFixed(1)}%';
  }

  /// Formatted half GST rate for CGST / SGST split (e.g. "9%" or "2.5%")
  String get cgstRateFormatted {
    final r = effectiveGstRate / 2;
    return r % 1 == 0 ? '${r.toInt()}%' : '${r.toStringAsFixed(1)}%';
  }

  /// Formatted SGST rate matches CGST rate
  String get sgstRateFormatted => cgstRateFormatted;
}

/// Member Payment Record from Backend Supabase Database
class MemberPayment {
  final String id;
  final String invoiceId;
  final String invoiceNumber;
  final String memberId;
  final double amount;
  final String paymentMethod;
  final String paymentSource;
  final String status;
  final DateTime paymentDate;
  final String? notes;
  final String? transactionId;

  const MemberPayment({
    required this.id,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.memberId,
    required this.amount,
    required this.paymentMethod,
    this.paymentSource = 'manual',
    this.status = 'completed',
    required this.paymentDate,
    this.notes,
    this.transactionId,
  });

  String get channel {
    final src = paymentSource.isNotEmpty ? '${paymentSource[0].toUpperCase()}${paymentSource.substring(1)}' : 'Manual';
    final meth = paymentMethod.isNotEmpty ? '${paymentMethod[0].toUpperCase()}${paymentMethod.substring(1)}' : 'Cash';
    return '$src · $meth';
  }

  String get reference => (transactionId != null && transactionId!.isNotEmpty)
      ? transactionId!
      : '—';

  factory MemberPayment.fromJson(Map<String, dynamic> json, [Map<String, String>? invoiceNumberMap]) {
    final invId = json['invoice_id'] as String? ?? '';
    final invNum = invoiceNumberMap?[invId] ??
        (json['invoices'] != null ? json['invoices']['invoice_number'] as String? : null) ??
        (invId.isNotEmpty ? 'INV-${invId.substring(0, invId.length >= 6 ? 6 : invId.length).toUpperCase()}' : '—');
    return MemberPayment(
      id: json['id'] as String? ?? '',
      invoiceId: invId,
      invoiceNumber: invNum,
      memberId: json['member_id'] as String? ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paymentSource: json['payment_source'] as String? ?? 'manual',
      status: json['status'] as String? ?? 'completed',
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes'] as String?,
      transactionId: json['transaction_id'] as String?,
    );
  }
}

class WatchSyncData {
  final int steps;
  final int goalSteps;
  final int activeCalories;
  final int goalCalories;
  final int heartRate;
  final DateTime? heartRateRecordedAt;
  final double heartRateVariabilityMs;
  final DateTime? heartRateVariabilityRecordedAt;
  final double sleepHours;
  final double goalSleepHours;
  final bool isManualSleep;
  final int workoutMinutes;
  final int goalWorkoutMinutes;
  final DateTime? lastSyncTime;
  /// True when a native provider has granted access or returned health data.
  final bool isConnected;
  final bool hasSyncedToday;

  const WatchSyncData({
    this.steps = -1,
    this.goalSteps = 10000,
    this.activeCalories = -1,
    this.goalCalories = 750,
    this.heartRate = -1,
    this.heartRateRecordedAt,
    this.heartRateVariabilityMs = -1,
    this.heartRateVariabilityRecordedAt,
    this.sleepHours = 0,
    this.goalSleepHours = 8,
    this.isManualSleep = false,
    this.workoutMinutes = -1,
    this.goalWorkoutMinutes = 60,
    this.lastSyncTime,
    this.isConnected = false,
    this.hasSyncedToday = false,
  });

  double get stepProgress => goalSteps > 0 ? (steps / goalSteps).clamp(0.0, 1.0) : 0.0;
  double get caloriesProgress => goalCalories > 0 ? (activeCalories / goalCalories).clamp(0.0, 1.0) : 0.0;
  double get sleepProgress => goalSleepHours > 0 ? (sleepHours / goalSleepHours).clamp(0.0, 1.0) : 0.0;
  double get workoutProgress => goalWorkoutMinutes > 0 ? (workoutMinutes / goalWorkoutMinutes).clamp(0.0, 1.0) : 0.0;

  WatchSyncData copyWith({
    int? steps,
    int? goalSteps,
    int? activeCalories,
    int? goalCalories,
    int? heartRate,
    DateTime? heartRateRecordedAt,
    bool clearHeartRateRecordedAt = false,
    double? heartRateVariabilityMs,
    DateTime? heartRateVariabilityRecordedAt,
    bool clearHeartRateVariabilityRecordedAt = false,
    double? sleepHours,
    double? goalSleepHours,
    bool? isManualSleep,
    int? workoutMinutes,
    int? goalWorkoutMinutes,
    DateTime? lastSyncTime,
    bool clearLastSyncTime = false,
    bool? isConnected,
    bool? hasSyncedToday,
  }) {
    return WatchSyncData(
      steps: steps ?? this.steps,
      goalSteps: goalSteps ?? this.goalSteps,
      activeCalories: activeCalories ?? this.activeCalories,
      goalCalories: goalCalories ?? this.goalCalories,
      heartRate: heartRate ?? this.heartRate,
      heartRateRecordedAt: clearHeartRateRecordedAt
          ? null
          : (heartRateRecordedAt ?? this.heartRateRecordedAt),
      heartRateVariabilityMs: heartRateVariabilityMs ?? this.heartRateVariabilityMs,
      heartRateVariabilityRecordedAt: clearHeartRateVariabilityRecordedAt
          ? null
          : (heartRateVariabilityRecordedAt ?? this.heartRateVariabilityRecordedAt),
      sleepHours: sleepHours ?? this.sleepHours,
      goalSleepHours: goalSleepHours ?? this.goalSleepHours,
      isManualSleep: isManualSleep ?? this.isManualSleep,
      workoutMinutes: workoutMinutes ?? this.workoutMinutes,
      goalWorkoutMinutes: goalWorkoutMinutes ?? this.goalWorkoutMinutes,
      lastSyncTime: clearLastSyncTime ? null : (lastSyncTime ?? this.lastSyncTime),
      isConnected: isConnected ?? this.isConnected,
      hasSyncedToday: hasSyncedToday ?? this.hasSyncedToday,
    );
  }
}

/// Dynamic attendance and daily routine analysis for smart motivation cues
class MemberAttendanceAnalysis {
  final int streakDays;
  final int bestStreakDays;
  final int totalVisits;
  final int monthlyVisits;
  final bool isVisitedToday;
  final DateTime? todayCheckIn;
  final String habitualTime;
  final String motivationTitle;
  final String motivationMessage;
  final String motivationUrgency; // 'gentle', 'habitual', 'urgent_evening', 'completed'
  final List<bool> weekActivity;

  const MemberAttendanceAnalysis({
    required this.streakDays,
    this.bestStreakDays = 23,
    this.totalVisits = 66,
    required this.monthlyVisits,
    required this.isVisitedToday,
    this.todayCheckIn,
    required this.habitualTime,
    required this.motivationTitle,
    required this.motivationMessage,
    required this.motivationUrgency,
    required this.weekActivity,
  });
}

class GymClass {
  final String id;
  final String title;
  final String category;
  final String instructorName;
  final String? instructorAvatar;
  final String? bannerUrl;
  final String studio;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final int capacity;
  final int bookedCount;
  final String intensity;
  final int burnKcal;
  final bool isIncludedWithPlan;
  final DateTime date;
  final String description;

  const GymClass({
    required this.id,
    required this.title,
    required this.category,
    required this.instructorName,
    this.instructorAvatar,
    this.bannerUrl,
    required this.studio,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.capacity,
    required this.bookedCount,
    required this.intensity,
    required this.burnKcal,
    this.isIncludedWithPlan = true,
    required this.date,
    this.description = '',
  });

  int get spotsRemaining => (capacity - bookedCount).clamp(0, capacity);
  bool get isFull => spotsRemaining <= 0;
  double get occupancyRate => capacity > 0 ? (bookedCount / capacity).clamp(0.0, 1.0) : 0.0;

  factory GymClass.fromJson(Map<String, dynamic> json, {DateTime? date}) {
    final parent = json['parent'] as Map<String, dynamic>? ?? json['class_types'] as Map<String, dynamic>?;
    final scheduledAtStr = json['scheduled_at'] as String? ?? '';
    DateTime scheduledDate = date ?? DateTime.now();
    String startTime = '08:00 AM';
    String endTime = '08:30 AM';
    final dur = (json['duration_minutes'] as num?)?.toInt() ?? 30;

    if (scheduledAtStr.isNotEmpty) {
      try {
        final parsed = DateTime.parse(scheduledAtStr).toLocal();
        scheduledDate = parsed;
        startTime = DateFormat('hh:mm a').format(parsed);
        endTime = DateFormat('hh:mm a').format(parsed.add(Duration(minutes: dur)));
      } catch (_) {}
    }

    final cat = (parent?['category'] as String? ?? json['class_type'] as String? ?? 'other').toLowerCase();
    final name = json['name'] as String? ?? parent?['name'] as String? ?? 'Studio Class';

    String categoryDisplay = 'Studio';
    if (cat.contains('pilates') || name.toLowerCase().contains('pilates')) {
      categoryDisplay = 'Reformer Pilates';
    } else if (cat.contains('yoga') || name.toLowerCase().contains('yoga')) {
      categoryDisplay = 'Yoga & Mind';
    } else if (cat.contains('zumba') || name.toLowerCase().contains('zumba')) {
      categoryDisplay = 'Zumba';
    } else if (cat.contains('aerobic') || name.toLowerCase().contains('aerobic')) {
      categoryDisplay = 'Aerobics';
    } else if (cat.contains('spin') || name.toLowerCase().contains('spin')) {
      categoryDisplay = 'Power Spin';
    } else if (cat.contains('hiit') || name.toLowerCase().contains('hiit')) {
      categoryDisplay = 'Functional HIIT';
    } else if (cat.contains('mobility') || name.toLowerCase().contains('mobility')) {
      categoryDisplay = 'Mobility';
    } else if (cat.contains('dance') || name.toLowerCase().contains('dance')) {
      categoryDisplay = 'Dance Fitness';
    } else {
      categoryDisplay = parent?['name'] as String? ?? (cat.isNotEmpty && cat != 'other' ? cat : 'Studio Class');
    }

    final bannerUrl = json['banner_url'] as String? ?? parent?['image_url'] as String?;
    final trainerObj = json['trainer'] as Map<String, dynamic>?;
    final externalTrainer = json['external_trainer_name'] as String?;
    final profileTrainer = trainerObj?['profiles']?['full_name'] as String?;
    final trainerName = (externalTrainer != null && externalTrainer.isNotEmpty)
        ? externalTrainer
        : (profileTrainer != null && profileTrainer.isNotEmpty)
            ? profileTrainer
            : 'Incline Lead Instructor';

    final venue = json['venue'] as String? ?? parent?['default_venue'] as String? ?? 'Incline Studio A';
    final isPaid = json['is_paid'] as bool? ?? false;

    return GymClass(
      id: json['id'] as String? ?? '',
      title: name,
      category: categoryDisplay,
      instructorName: trainerName,
      instructorAvatar: parent?['image_url'] as String?,
      bannerUrl: bannerUrl,
      studio: venue,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: dur,
      capacity: (json['capacity'] as num?)?.toInt() ?? 4,
      bookedCount: (json['booked_count'] as num?)?.toInt() ?? 0,
      intensity: dur >= 45 ? 'High' : 'Moderate',
      burnKcal: dur * 10,
      isIncludedWithPlan: !isPaid,
      date: scheduledDate,
      description: json['description'] as String? ?? parent?['description'] as String? ?? 'Signature Incline studio masterclass.',
    );
  }
}

class GymNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type; // 'announcement', 'booking', 'streak', 'workout'
  final bool isRead;
  final String? badge;
  final String? actionLabel;

  const GymNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.badge,
    this.actionLabel,
  });
}

class StreakData {
  final int currentStreak;
  final int bestStreak;
  final int monthlyVisits;
  final List<bool> weekActivity; // 7 days Mon-Sun
  final String nextMilestone;
  final double milestoneProgress;

  const StreakData({
    required this.currentStreak,
    required this.bestStreak,
    required this.monthlyVisits,
    required this.weekActivity,
    required this.nextMilestone,
    required this.milestoneProgress,
  });
}

/// Clinical Micronutrients and Essential Electrolytes for Athletic Performance & Recovery
class DietMicronutrients {
  final double fiber; // grams (Athletic RDA: 38g)
  final double sodium; // mg (Athletic RDA: 2300mg)
  final double potassium; // mg (Athletic RDA: 3500mg)
  final double magnesium; // mg (Athletic RDA: 420mg)
  final double zinc; // mg (Athletic RDA: 15mg)
  final double iron; // mg (Athletic RDA: 18mg)
  final double calcium; // mg (Athletic RDA: 1000mg)
  final double vitaminD; // IU (Athletic RDA: 2000 IU)
  final double vitaminC; // mg (Athletic RDA: 90mg)
  final double vitaminB12; // mcg (Athletic RDA: 6.0 mcg)
  final double omega3; // mg (Athletic RDA: 1500mg)

  const DietMicronutrients({
    this.fiber = 0.0,
    this.sodium = 0.0,
    this.potassium = 0.0,
    this.magnesium = 0.0,
    this.zinc = 0.0,
    this.iron = 0.0,
    this.calcium = 0.0,
    this.vitaminD = 0.0,
    this.vitaminC = 0.0,
    this.vitaminB12 = 0.0,
    this.omega3 = 0.0,
  });

  /// Standard athletic clinical daily RDA targets
  static const DietMicronutrients athleticRda = DietMicronutrients(
    fiber: 38.0,
    sodium: 2300.0,
    potassium: 3500.0,
    magnesium: 420.0,
    zinc: 15.0,
    iron: 18.0,
    calcium: 1000.0,
    vitaminD: 2000.0,
    vitaminC: 90.0,
    vitaminB12: 6.0,
    omega3: 1500.0,
  );

  DietMicronutrients operator +(DietMicronutrients other) {
    return DietMicronutrients(
      fiber: fiber + other.fiber,
      sodium: sodium + other.sodium,
      potassium: potassium + other.potassium,
      magnesium: magnesium + other.magnesium,
      zinc: zinc + other.zinc,
      iron: iron + other.iron,
      calcium: calcium + other.calcium,
      vitaminD: vitaminD + other.vitaminD,
      vitaminC: vitaminC + other.vitaminC,
      vitaminB12: vitaminB12 + other.vitaminB12,
      omega3: omega3 + other.omega3,
    );
  }

  factory DietMicronutrients.fromJson(Map<String, dynamic> json) {
    return DietMicronutrients(
      fiber: MealFoodItem._safeDouble(json['fiber']),
      sodium: MealFoodItem._safeDouble(json['sodium'] ?? json['na']),
      potassium: MealFoodItem._safeDouble(json['potassium'] ?? json['k']),
      magnesium: MealFoodItem._safeDouble(json['magnesium'] ?? json['mg']),
      zinc: MealFoodItem._safeDouble(json['zinc'] ?? json['zn']),
      iron: MealFoodItem._safeDouble(json['iron'] ?? json['fe']),
      calcium: MealFoodItem._safeDouble(json['calcium'] ?? json['ca']),
      vitaminD: MealFoodItem._safeDouble(json['vitamin_d'] ?? json['vitaminD'] ?? json['vit_d']),
      vitaminC: MealFoodItem._safeDouble(json['vitamin_c'] ?? json['vitaminC'] ?? json['vit_c']),
      vitaminB12: MealFoodItem._safeDouble(json['vitamin_b12'] ?? json['vitaminB12'] ?? json['vit_b12']),
      omega3: MealFoodItem._safeDouble(json['omega3'] ?? json['omega_3']),
    );
  }

  Map<String, dynamic> toJson() => {
    'fiber': fiber,
    'sodium': sodium,
    'potassium': potassium,
    'magnesium': magnesium,
    'zinc': zinc,
    'iron': iron,
    'calcium': calcium,
    'vitamin_d': vitaminD,
    'vitamin_c': vitaminC,
    'vitamin_b12': vitaminB12,
    'omega3': omega3,
  };
}

class MealFoodItem {
  final String name;
  final String quantity;
  final int calories;
  final double protein; // grams
  final double carbs;   // grams
  final double fats;    // grams
  final double? fiber;  // grams
  final String? alternative;
  final DietMicronutrients? micros;

  const MealFoodItem({
    required this.name,
    required this.quantity,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.fiber,
    this.alternative,
    this.micros,
  });

  static int _safeInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is num) return val.toInt();
    if (val is String) {
      final match = RegExp(r'[-+]?\d+').firstMatch(val);
      if (match != null) return int.tryParse(match.group(0)!) ?? fallback;
    }
    return fallback;
  }

  static double _safeDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) {
      final match = RegExp(r'[-+]?\d+(\.\d+)?').firstMatch(val);
      if (match != null) return double.tryParse(match.group(0)!) ?? fallback;
    }
    return fallback;
  }

  factory MealFoodItem.fromJson(Map<String, dynamic> json) {
    DietMicronutrients? itemMicros;
    if (json['micros'] != null && json['micros'] is Map<String, dynamic>) {
      itemMicros = DietMicronutrients.fromJson(json['micros'] as Map<String, dynamic>);
    } else if (json['fiber'] != null || json['potassium'] != null || json['sodium'] != null || json['magnesium'] != null) {
      itemMicros = DietMicronutrients.fromJson(json);
    }

    final fib = json['fiber'] != null ? _safeDouble(json['fiber']) : itemMicros?.fiber;

    return MealFoodItem(
      name: json['name'] as String? ?? json['food'] as String? ?? 'Nutritional Item',
      quantity: json['quantity'] as String? ?? '1 Serving',
      calories: _safeInt(json['calories']),
      protein: _safeDouble(json['protein']),
      carbs: _safeDouble(json['carbs']),
      fats: _safeDouble(json['fats'] ?? json['fat']),
      fiber: fib,
      alternative: json['alternative'] as String?,
      micros: itemMicros,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fats': fats,
    if (fiber != null) 'fiber': fiber,
    if (alternative != null) 'alternative': alternative,
    if (micros != null) 'micros': micros!.toJson(),
  };
}

class DietMeal {
  final String id;
  final String name;
  final String? slotLabel;
  final String time;
  final int targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFats;
  final List<MealFoodItem> items;
  final String? prepTips;
  final String? recipeLink;
  final DietMicronutrients? micros;
  bool isCompleted;
  DateTime? completedAt;

  DietMeal({
    required this.id,
    required this.name,
    this.slotLabel,
    required this.time,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFats,
    required this.items,
    this.prepTips,
    this.recipeLink,
    this.micros,
    this.isCompleted = false,
    this.completedAt,
  });

  /// Dynamic slot label fallback logic
  String get displaySlotLabel {
    if (slotLabel != null && slotLabel!.trim().isNotEmpty) {
      return slotLabel!.trim();
    }
    // Infer dynamically from meal id or slot key
    final lowerId = id.toLowerCase();
    if (lowerId.contains('pre_workout') || lowerId.contains('preworkout')) return 'Pre-Workout';
    if (lowerId.contains('post_workout') || lowerId.contains('postworkout')) return 'Post-Workout';
    if (lowerId.contains('breakfast')) return 'Breakfast';
    if (lowerId.contains('snack1') || lowerId.contains('mid_morning') || lowerId.contains('midmorning')) return 'Mid-Morning Snack';
    if (lowerId.contains('lunch')) return 'Lunch';
    if (lowerId.contains('snack2') || lowerId.contains('evening_snack') || lowerId.contains('afternoon')) return 'Evening Snack';
    if (lowerId.contains('dinner')) return 'Dinner';
    return name;
  }

  /// Aggregate meal micronutrients across items, or fallback to parsed meal micros
  DietMicronutrients get totalMicros {
    if (micros != null) return micros!;
    return items.fold(const DietMicronutrients(), (sum, it) {
      if (it.micros != null) return sum + it.micros!;
      if (it.fiber != null && it.fiber! > 0) {
        return sum + DietMicronutrients(fiber: it.fiber!);
      }
      return sum;
    });
  }

  factory DietMeal.fromJson(Map<String, dynamic> json, {String id = ''}) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems.map((item) {
      if (item is Map<String, dynamic>) {
        return MealFoodItem.fromJson(item);
      } else {
        return MealFoodItem(
          name: item.toString(),
          quantity: '1 serving',
          calories: 150,
          protein: 10,
          carbs: 15,
          fats: 5,
        );
      }
    }).toList();

    DietMicronutrients? mealMicros;
    if (json['micros'] != null && json['micros'] is Map<String, dynamic>) {
      mealMicros = DietMicronutrients.fromJson(json['micros'] as Map<String, dynamic>);
    }

    final slotTotals = json['totals'] as Map<String, dynamic>?;
    final int cal = MealFoodItem._safeInt(
      json['targetCalories'] ?? json['target_calories'] ?? json['calories'] ?? slotTotals?['calories'],
      itemsList.fold(0, (sum, it) => sum + it.calories),
    );
    final double prot = MealFoodItem._safeDouble(
      json['targetProtein'] ?? json['target_protein'] ?? json['protein'] ?? slotTotals?['protein'],
      itemsList.fold(0.0, (sum, it) => sum + it.protein),
    );
    final double carb = MealFoodItem._safeDouble(
      json['targetCarbs'] ?? json['target_carbs'] ?? json['carbs'] ?? slotTotals?['carbs'],
      itemsList.fold(0.0, (sum, it) => sum + it.carbs),
    );
    final double fat = MealFoodItem._safeDouble(
      json['targetFats'] ?? json['target_fats'] ?? json['fats'] ?? json['fat'] ?? slotTotals?['fats'],
      itemsList.fold(0.0, (sum, it) => sum + it.fats),
    );

    final String? parsedSlotLabel = json['slot_label'] as String? ??
        json['slotLabel'] as String? ??
        json['slot'] as String? ??
        json['meal_type'] as String?;

    return DietMeal(
      id: id.isNotEmpty ? id : (json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString()),
      name: json['name'] as String? ?? json['meal'] as String? ?? 'Meal',
      slotLabel: parsedSlotLabel,
      time: json['time'] as String? ?? '08:00 AM',
      targetCalories: cal,
      targetProtein: prot,
      targetCarbs: carb,
      targetFats: fat,
      items: itemsList,
      prepTips: json['prep_tips'] as String? ?? json['notes'] as String?,
      recipeLink: json['recipe_link'] as String? ?? json['prep_video_url'] as String?,
      micros: mealMicros,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slot_label': slotLabel ?? displaySlotLabel,
    'slotLabel': slotLabel ?? displaySlotLabel,
    'time': time,
    'calories': targetCalories,
    'targetCalories': targetCalories,
    'target_calories': targetCalories,
    'protein': targetProtein,
    'targetProtein': targetProtein,
    'target_protein': targetProtein,
    'carbs': targetCarbs,
    'targetCarbs': targetCarbs,
    'target_carbs': targetCarbs,
    'fats': targetFats,
    'targetFats': targetFats,
    'target_fats': targetFats,
    'prep_tips': prepTips,
    'recipe_link': recipeLink,
    'is_completed': isCompleted,
    if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    if (micros != null) 'micros': micros!.toJson(),
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class DietDayPlan {
  final String dayLabel;
  final int weekdayIndex; // 1 = Monday, 7 = Sunday
  final int targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFats;
  final int targetWaterMl;
  final List<DietMeal> meals;
  final List<String> supplements;
  final String? nutritionistNote;
  final DietMicronutrients? targetMicros;

  const DietDayPlan({
    required this.dayLabel,
    required this.weekdayIndex,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFats,
    this.targetWaterMl = 3800,
    required this.meals,
    this.supplements = const [],
    this.nutritionistNote,
    this.targetMicros,
  });

  int get consumedCalories => meals.where((m) => m.isCompleted).fold(0, (sum, m) => sum + m.targetCalories);
  double get consumedProtein => meals.where((m) => m.isCompleted).fold(0.0, (sum, m) => sum + m.targetProtein);
  double get consumedCarbs => meals.where((m) => m.isCompleted).fold(0.0, (sum, m) => sum + m.targetCarbs);
  double get consumedFats => meals.where((m) => m.isCompleted).fold(0.0, (sum, m) => sum + m.targetFats);
  int get completedMealsCount => meals.where((m) => m.isCompleted).length;

  /// Aggregated consumed micronutrients across all logged meals today
  DietMicronutrients get consumedMicros => meals
      .where((m) => m.isCompleted)
      .fold(const DietMicronutrients(), (sum, m) => sum + m.totalMicros);

  /// Target micronutrients, defaulting to Incline athletic RDA if not overridden by coach
  DietMicronutrients get effectiveTargetMicros => targetMicros ?? DietMicronutrients.athleticRda;

  Map<String, dynamic> toJson() => {
    'day_label': dayLabel,
    'weekday_index': weekdayIndex,
    'target_calories': targetCalories,
    'target_protein': targetProtein,
    'target_carbs': targetCarbs,
    'target_fats': targetFats,
    'target_water_ml': targetWaterMl,
    'supplements': supplements,
    'nutritionist_note': nutritionistNote,
    if (targetMicros != null) 'target_micros': targetMicros!.toJson(),
    'meals': meals.map((m) => m.toJson()).toList(),
  };

  factory DietDayPlan.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'] as List<dynamic>? ?? [];
    final meals = rawMeals
        .map((m) => DietMeal.fromJson(m as Map<String, dynamic>, id: m['id']?.toString() ?? ''))
        .toList();
    return DietDayPlan(
      dayLabel: json['day_label'] as String? ?? json['dayLabel'] as String? ?? 'Day',
      weekdayIndex: json['weekday_index'] as int? ?? json['weekdayIndex'] as int? ?? 1,
      targetCalories: MealFoodItem._safeInt(
        json['target_calories'] ?? json['targetCalories'] ?? json['calories'],
        meals.fold(0, (sum, m) => sum + m.targetCalories),
      ),
      targetProtein: MealFoodItem._safeDouble(
        json['target_protein'] ?? json['targetProtein'] ?? json['protein'],
        meals.fold(0.0, (sum, m) => sum + m.targetProtein),
      ),
      targetCarbs: MealFoodItem._safeDouble(
        json['target_carbs'] ?? json['targetCarbs'] ?? json['carbs'],
        meals.fold(0.0, (sum, m) => sum + m.targetCarbs),
      ),
      targetFats: MealFoodItem._safeDouble(
        json['target_fats'] ?? json['targetFats'] ?? json['fats'] ?? json['fat'],
        meals.fold(0.0, (sum, m) => sum + m.targetFats),
      ),
      targetWaterMl: MealFoodItem._safeInt(json['target_water_ml'] ?? json['targetWaterMl'], 3800),
      supplements: (json['supplements'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      nutritionistNote: json['nutritionist_note'] as String? ?? json['nutritionistNote'] as String?,
      targetMicros: json['target_micros'] != null
          ? DietMicronutrients.fromJson(json['target_micros'] as Map<String, dynamic>)
          : (json['targetMicros'] != null
              ? DietMicronutrients.fromJson(json['targetMicros'] as Map<String, dynamic>)
              : null),
      meals: meals,
    );
  }
}

class MemberDietPlan {
  final String id;
  final String planName;
  final String? description;
  final String? nutritionistName;
  final String dietaryType;
  final String? cuisine;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final List<DietDayPlan> days;
  final bool isPersonalTraining;
  final String? pdfUrl;

  const MemberDietPlan({
    required this.id,
    required this.planName,
    this.description,
    this.nutritionistName,
    this.dietaryType = 'High-Protein Clean Fuel',
    this.cuisine = 'Modern Indian & Mediterranean',
    this.validFrom,
    this.validUntil,
    required this.days,
    this.isPersonalTraining = false,
    this.pdfUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan_name': planName,
    'description': description,
    'nutritionist_name': nutritionistName,
    'dietary_type': dietaryType,
    'cuisine': cuisine,
    'valid_from': validFrom?.toIso8601String(),
    'valid_until': validUntil?.toIso8601String(),
    'is_personal_training': isPersonalTraining,
    'pdf_url': pdfUrl,
    'days': days.map((d) => d.toJson()).toList(),
  };

  factory MemberDietPlan.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? [];
    final days = rawDays.map((d) => DietDayPlan.fromJson(d as Map<String, dynamic>)).toList();
    return MemberDietPlan(
      id: json['id'] as String? ?? '',
      planName: json['plan_name'] as String? ?? json['planName'] as String? ?? 'Incline Nutrition Plan',
      description: json['description'] as String?,
      nutritionistName: json['nutritionist_name'] as String? ?? json['nutritionistName'] as String?,
      dietaryType: json['dietary_type'] as String? ?? json['dietaryType'] as String? ?? 'High-Protein Clean Fuel',
      cuisine: json['cuisine'] as String?,
      validFrom: json['valid_from'] != null ? DateTime.tryParse(json['valid_from'].toString()) : null,
      validUntil: json['valid_until'] != null ? DateTime.tryParse(json['valid_until'].toString()) : null,
      isPersonalTraining: json['is_personal_training'] as bool? ?? json['isPersonalTraining'] as bool? ?? false,
      pdfUrl: json['pdf_url'] as String? ?? json['pdfUrl'] as String?,
      days: days,
    );
  }
}

class MemberPtPackage {
  final String id;
  final String memberId;
  final String packageName;
  final String packageType; // 'session_based' or 'monthly'
  final int sessionsTotal;
  final int sessionsRemaining;
  final String status; // 'active', 'expired', 'completed'
  final DateTime? startDate;
  final DateTime? expiryDate;
  final String? trainerId;
  final String? trainerName;
  final double? price;

  const MemberPtPackage({
    required this.id,
    required this.memberId,
    required this.packageName,
    this.packageType = 'session_based',
    this.sessionsTotal = 16,
    this.sessionsRemaining = 4,
    this.status = 'active',
    this.startDate,
    this.expiryDate,
    this.trainerId,
    this.trainerName,
    this.price,
  });

  int get completedSessions => (sessionsTotal - sessionsRemaining).clamp(0, sessionsTotal);
  double get progressRate => sessionsTotal > 0 ? (completedSessions / sessionsTotal).clamp(0.0, 1.0) : 0.0;
  bool get isExhausted => sessionsRemaining <= 0;

  factory MemberPtPackage.fromJson(Map<String, dynamic> json) {
    return MemberPtPackage(
      id: json['id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      packageName: json['package_name'] as String? ?? json['name'] as String? ?? '1-on-1 Elite Transformation Pack',
      packageType: json['package_type'] as String? ?? 'session_based',
      sessionsTotal: (json['sessions_total'] as num?)?.toInt() ?? 16,
      sessionsRemaining: (json['sessions_remaining'] as num?)?.toInt() ?? 4,
      status: json['status'] as String? ?? 'active',
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'] as String) : null,
      expiryDate: json['expiry_date'] != null ? DateTime.tryParse(json['expiry_date'] as String) : null,
      trainerId: json['trainer_id'] as String?,
      trainerName: json['trainer_name'] as String?,
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

class PtSession {
  final String id;
  final String memberPtPackageId;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String status; // 'scheduled', 'completed', 'cancelled', 'no_show'
  final String? trainerId;
  final String? trainerName;
  final String? focus;
  final String? notes;

  const PtSession({
    required this.id,
    required this.memberPtPackageId,
    required this.scheduledAt,
    this.durationMinutes = 60,
    this.status = 'scheduled',
    this.trainerId,
    this.trainerName,
    this.focus,
    this.notes,
  });

  factory PtSession.fromJson(Map<String, dynamic> json) {
    final trainerObj = json['trainer'] as Map<String, dynamic>?;
    final tName = trainerObj?['profiles']?['full_name'] as String? ?? json['trainer_name'] as String?;
    return PtSession(
      id: json['id'] as String? ?? '',
      memberPtPackageId: json['member_pt_package_id'] as String? ?? '',
      scheduledAt: json['scheduled_at'] != null ? DateTime.parse(json['scheduled_at'] as String).toLocal() : DateTime.now(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      status: json['status'] as String? ?? 'scheduled',
      trainerId: json['trainer_id'] as String?,
      trainerName: tName,
      focus: json['focus'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

/// Member Referral model matching Supabase `referrals` table
class MemberReferral {
  final String id;
  final String referrerMemberId;
  final String referralCode;
  final String referredName;
  final String? referredPhone;
  final String? referredMemberId;
  final String status; // 'pending', 'joined', 'converted', 'rewarded'
  final DateTime? convertedAt;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const MemberReferral({
    required this.id,
    required this.referrerMemberId,
    required this.referralCode,
    required this.referredName,
    this.referredPhone,
    this.referredMemberId,
    this.status = 'pending',
    this.convertedAt,
    required this.createdAt,
    this.metadata,
  });

  bool get isConverted => status == 'converted' || status == 'rewarded' || status == 'joined';

  factory MemberReferral.fromJson(Map<String, dynamic> json) {
    return MemberReferral(
      id: json['id'] as String? ?? '',
      referrerMemberId: json['referrer_member_id'] as String? ?? '',
      referralCode: json['referral_code'] as String? ?? '',
      referredName: json['referred_name'] as String? ?? 'Invited Guest',
      referredPhone: json['referred_phone'] as String?,
      referredMemberId: json['referred_member_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      convertedAt: json['converted_at'] != null ? DateTime.tryParse(json['converted_at'].toString())?.toLocal() : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now() : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Member Referral Reward model matching Supabase `referral_rewards` table
class ReferralReward {
  final String id;
  final String memberId;
  final String referralId;
  final String rewardType;
  final double rewardValue;
  final String? description;
  final bool isClaimed;
  final String? claimStatus; // 'pending', 'pending_approval', 'approved', 'rejected'
  final DateTime? claimedAt;
  final DateTime createdAt;

  const ReferralReward({
    required this.id,
    required this.memberId,
    required this.referralId,
    required this.rewardType,
    required this.rewardValue,
    this.description,
    this.isClaimed = false,
    this.claimStatus,
    this.claimedAt,
    required this.createdAt,
  });

  bool get isAwaitingApproval => claimStatus == 'pending_approval';

  factory ReferralReward.fromJson(Map<String, dynamic> json) {
    final rawClaimed = json['is_claimed'] as bool?;
    final cStatus = json['claim_status'] as String? ?? (rawClaimed == true ? 'approved' : 'pending');
    final isClaimed = rawClaimed ?? (cStatus == 'claimed' || cStatus == 'approved' || json['claimed_at'] != null);

    return ReferralReward(
      id: json['id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      referralId: json['referral_id'] as String? ?? '',
      rewardType: json['reward_type'] as String? ?? 'wallet_credit',
      rewardValue: (json['reward_value'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      isClaimed: isClaimed,
      claimStatus: cStatus,
      claimedAt: json['claimed_at'] != null ? DateTime.tryParse(json['claimed_at'].toString())?.toLocal() : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now() : DateTime.now(),
    );
  }
}

/// Referral Program Configuration matching backend and Supabase schema
class ReferralSettings {
  final String id;
  final String? branchId;
  final bool isEnabled;
  final String rewardMode; // 'percentage' or 'fixed'
  final double referrerRewardValue; // 10 (%) or 2500 (₹)
  final String referrerRewardType; // 'wallet_credit', 'cash', 'gift_card'
  final double minMembershipValue; // minimum purchase to unlock reward (e.g. 24000)
  final String? termsAndConditions;

  const ReferralSettings({
    required this.id,
    this.branchId,
    this.isEnabled = true,
    this.rewardMode = 'percentage',
    this.referrerRewardValue = 10.0,
    this.referrerRewardType = 'wallet_credit',
    this.minMembershipValue = 24000.0,
    this.termsAndConditions,
  });

  /// Formatted badge string, e.g. "10% REWARD" or "₹2,500 REWARD"
  String get rewardBadgeText {
    if (rewardMode == 'percentage') {
      return '${referrerRewardValue.toInt()}% REWARD';
    }
    return '₹${referrerRewardValue.toInt()} REWARD';
  }

  /// Formatted subtitle description, e.g. "10% wallet credit on memberships"
  String get rewardDescription {
    if (rewardMode == 'percentage') {
      return '${referrerRewardValue.toInt()}% wallet credit on friends joining';
    }
    return '₹${referrerRewardValue.toInt()} wallet credits on friends joining';
  }

  /// Calculates total credits earned for a number of converted members
  int calculateTotalEarned(int convertedCount) {
    if (convertedCount <= 0) return 0;
    if (rewardMode == 'percentage') {
      final perMember = (referrerRewardValue / 100.0) * minMembershipValue;
      return (perMember * convertedCount).round();
    }
    return (referrerRewardValue * convertedCount).round();
  }

  factory ReferralSettings.fromJson(Map<String, dynamic> json) {
    final mode = json['reward_mode'] as String? ?? 'percentage';
    final val = (json['referrer_reward_value'] as num?)?.toDouble() ??
        (json['referral_membership_bonus'] as num?)?.toDouble() ??
        10.0;
    final minVal = (json['min_membership_value'] as num?)?.toDouble() ?? 24000.0;
    final type = json['referrer_reward_type'] as String? ?? 'wallet_credit';

    return ReferralSettings(
      id: json['id'] as String? ?? 'default_referral_settings',
      branchId: json['branch_id'] as String?,
      isEnabled: json['is_active'] as bool? ?? json['is_enabled'] as bool? ?? json['referral_enabled'] as bool? ?? false,
      rewardMode: mode,
      referrerRewardValue: val,
      referrerRewardType: type,
      minMembershipValue: minVal,
      termsAndConditions: json['terms_and_conditions'] as String?,
    );
  }

  static ReferralSettings standardDefault([String? branchId]) {
    return ReferralSettings(
      id: 'default_incline_settings',
      branchId: branchId,
      isEnabled: true,
      rewardMode: 'percentage',
      referrerRewardValue: 10.0,
      referrerRewardType: 'wallet_credit',
      minMembershipValue: 24000.0,
      termsAndConditions:
          '10% Wallet Credit awarded upon friend purchase of an Incline Club Membership (min. ₹24,000).',
    );
  }
}

/// Represents a confirmed member booking (Class, Contrast Suite, or PT session)
class MemberReservation {
  final String id;
  final String bookingId;
  final String type; // 'class', 'recovery', 'pt'
  final String title;
  final String subtitle;
  final String category;
  final DateTime dateTime;
  final String startTime;
  final String endTime;
  final String venue;
  final String status; // 'confirmed', 'completed', 'cancelled'
  final String? instructorName;
  final bool canCancel;

  const MemberReservation({
    required this.id,
    required this.bookingId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.dateTime,
    required this.startTime,
    required this.endTime,
    required this.venue,
    this.status = 'confirmed',
    this.instructorName,
    this.canCancel = true,
  });

  bool get isUpcoming => dateTime.isAfter(DateTime.now().subtract(const Duration(hours: 1))) && status == 'confirmed';
}

/// Authentic, clinical-grade member health biometrics retrieved from Supabase
/// (`howbody_body_reports`, `howbody_posture_reports`, `member_measurements`).
/// Never uses fabricated dummy numbers.
class MemberBiometrics {
  final double currentWeightKg;
  final double targetWeightKg;
  final double weightControlKg;
  final double fatControlKg;
  final double muscleControlKg;
  final double heightCm;
  final double bmi;
  final double bodyFatPercentage;
  final double skeletalMuscleMassKg;
  final double bmrKcal;
  final int visceralFatRating;
  final double waistHipRatio;
  final int healthScore;
  final int postureScore;
  final String postureType;
  final double chestCm;
  final double waistCm;
  final double hipsCm;
  final double thighLeftCm;
  final double thighRightCm;
  final double calfLeftCm;
  final double calfRightCm;
  final double armLeftCm;
  final double armRightCm;
  final String fitnessGoal;
  final DateTime? recordedAt;
  final String? modelUrl;
  final String? frontImg;
  final String? leftImg;
  final String? rightImg;
  final String? backImg;

  const MemberBiometrics({
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.weightControlKg,
    this.fatControlKg = -0.3,
    this.muscleControlKg = 0.0,
    required this.heightCm,
    required this.bmi,
    required this.bodyFatPercentage,
    required this.skeletalMuscleMassKg,
    required this.bmrKcal,
    required this.visceralFatRating,
    required this.waistHipRatio,
    required this.healthScore,
    required this.postureScore,
    required this.postureType,
    required this.chestCm,
    required this.waistCm,
    required this.hipsCm,
    required this.thighLeftCm,
    required this.thighRightCm,
    required this.calfLeftCm,
    required this.calfRightCm,
    required this.armLeftCm,
    required this.armRightCm,
    required this.fitnessGoal,
    this.recordedAt,
    this.modelUrl,
    this.frontImg,
    this.leftImg,
    this.rightImg,
    this.backImg,
  });

  bool get hasReal3DScan => modelUrl?.trim().isNotEmpty ?? false;

  List<PosturePhoto> get photos {
    final list = <PosturePhoto>[];
    if (frontImg != null && frontImg!.trim().isNotEmpty) {
      list.add(PosturePhoto(label: 'Front View', url: frontImg!.trim(), angle: 'Front'));
    }
    if (leftImg != null && leftImg!.trim().isNotEmpty) {
      list.add(PosturePhoto(label: 'Left Profile', url: leftImg!.trim(), angle: 'Left'));
    }
    if (rightImg != null && rightImg!.trim().isNotEmpty) {
      list.add(PosturePhoto(label: 'Right Profile', url: rightImg!.trim(), angle: 'Right'));
    }
    if (backImg != null && backImg!.trim().isNotEmpty) {
      list.add(PosturePhoto(label: 'Back View', url: backImg!.trim(), angle: 'Back'));
    }
    return list;
  }

  /// Clinically calculated target Body Fat Percentage based on fat control recommendation
  double get targetBodyFatPercentage {
    final currentFatKg = currentWeightKg * (bodyFatPercentage / 100.0);
    final targetFatKg = currentFatKg + fatControlKg;
    if (targetWeightKg <= 0) return bodyFatPercentage;
    return double.parse(((targetFatKg / targetWeightKg) * 100.0).clamp(5.0, 50.0).toStringAsFixed(1));
  }

  /// Target Skeletal Muscle Mass in kg based on muscle control recommendation
  double get targetSkeletalMuscleMassKg {
    return double.parse((skeletalMuscleMassKg + muscleControlKg).toStringAsFixed(1));
  }

  /// Generic standard baseline biometrics
  factory MemberBiometrics.genericBaseline() {
    return MemberBiometrics(
      currentWeightKg: 70.0,
      targetWeightKg: 70.0,
      weightControlKg: 0.0,
      fatControlKg: 0.0,
      muscleControlKg: 0.0,
      heightCm: 172.0,
      bmi: 23.5,
      bodyFatPercentage: 16.0,
      skeletalMuscleMassKg: 33.0,
      bmrKcal: 1650.0,
      visceralFatRating: 4,
      waistHipRatio: 0.88,
      healthScore: 80,
      postureScore: 85,
      postureType: 'Neutral',
      chestCm: 96.0,
      waistCm: 80.0,
      hipsCm: 98.0,
      thighLeftCm: 56.0,
      thighRightCm: 56.0,
      calfLeftCm: 38.0,
      calfRightCm: 38.0,
      armLeftCm: 33.0,
      armRightCm: 33.0,
      fitnessGoal: 'General Fitness',
      recordedAt: DateTime.now(),
    );
  }

  factory MemberBiometrics.fromSupabase({
    Map<String, dynamic>? bodyReport,
    Map<String, dynamic>? postureReport,
    Map<String, dynamic>? measurement,
    String? goal,
  }) {
    final weight = (bodyReport?['weight'] as num?)?.toDouble() ??
        (measurement?['weight_kg'] as num?)?.toDouble() ??
        0.0;
    final target = (bodyReport?['target_weight'] as num?)?.toDouble() ?? (weight > 0 ? weight : 0.0);
    final control = (bodyReport?['weight_control'] as num?)?.toDouble() ?? (target > 0 && weight > 0 ? target - weight : 0.0);
    final fatCtrl = (bodyReport?['fat_control'] as num?)?.toDouble() ?? 0.0;
    final muscleCtrl = (bodyReport?['muscle_control'] as num?)?.toDouble() ?? 0.0;
    final height = (bodyReport?['height_cm'] as num?)?.toDouble() ??
        (measurement?['height_cm'] as num?)?.toDouble() ??
        0.0;
    final bmi = (bodyReport?['bmi'] as num?)?.toDouble() ?? (height > 0 && weight > 0 ? (weight / ((height / 100) * (height / 100))) : 0.0);
    final pbf = (bodyReport?['pbf'] as num?)?.toDouble() ??
        (measurement?['body_fat_percentage'] as num?)?.toDouble() ??
        0.0;
    final smm = (bodyReport?['smm'] as num?)?.toDouble() ?? 0.0;
    final bmr = (bodyReport?['bmr'] as num?)?.toDouble() ?? 0.0;
    final vfr = (bodyReport?['vfr'] as num?)?.toInt() ?? 0;
    final whr = (bodyReport?['whr'] as num?)?.toDouble() ?? 0.0;
    final hScore = (bodyReport?['health_score'] as num?)?.toInt() ?? 0;
    final pScore = (postureReport?['score'] as num?)?.toInt() ?? 0;
    final pType = (measurement?['posture_type'] as String?) ?? (postureReport != null ? 'Analyzed' : 'Standard');

    final chest = (postureReport?['bust'] as num?)?.toDouble() ??
        (measurement?['chest_cm'] as num?)?.toDouble() ??
        0.0;
    final waist = (postureReport?['waist'] as num?)?.toDouble() ??
        (measurement?['waist_cm'] as num?)?.toDouble() ??
        0.0;
    final hips = (postureReport?['hip'] as num?)?.toDouble() ??
        (measurement?['hips_cm'] as num?)?.toDouble() ??
        0.0;

    final thighL = (postureReport?['left_thigh'] as num?)?.toDouble() ??
        (measurement?['thighs_left_cm'] as num?)?.toDouble() ??
        0.0;
    final thighR = (postureReport?['right_thigh'] as num?)?.toDouble() ??
        (measurement?['thighs_right_cm'] as num?)?.toDouble() ??
        0.0;
    final calfL = (postureReport?['calf_left'] as num?)?.toDouble() ?? 0.0;
    final calfR = (postureReport?['calf_right'] as num?)?.toDouble() ?? 0.0;
    final armL = (postureReport?['up_arm_left'] as num?)?.toDouble() ??
        (measurement?['biceps_left_cm'] as num?)?.toDouble() ??
        0.0;
    final armR = (postureReport?['up_arm_right'] as num?)?.toDouble() ??
        (measurement?['biceps_right_cm'] as num?)?.toDouble() ??
        0.0;

    final recAt = measurement?['recorded_at'] != null
        ? DateTime.tryParse(measurement!['recorded_at'] as String)
        : (bodyReport?['test_time'] != null
            ? DateTime.tryParse(bodyReport!['test_time'] as String)
            : DateTime.now());

    final mUrl = postureReport?['model_url'] as String? ??
        postureReport?['modelUrl'] as String? ??
        postureReport?['murl'] as String?;
    final fImg = postureReport?['front_img'] as String? ?? postureReport?['frontImg'] as String?;
    final lImg = postureReport?['left_img'] as String? ?? postureReport?['leftImg'] as String?;
    final rImg = postureReport?['right_img'] as String? ?? postureReport?['rightImg'] as String?;
    final bImg = postureReport?['back_img'] as String? ?? postureReport?['backImg'] as String?;

    return MemberBiometrics(
      currentWeightKg: weight,
      targetWeightKg: target,
      weightControlKg: control,
      fatControlKg: fatCtrl,
      muscleControlKg: muscleCtrl,
      heightCm: height,
      bmi: double.parse(bmi.toStringAsFixed(1)),
      bodyFatPercentage: double.parse(pbf.toStringAsFixed(1)),
      skeletalMuscleMassKg: double.parse(smm.toStringAsFixed(1)),
      bmrKcal: double.parse(bmr.toStringAsFixed(0)),
      visceralFatRating: vfr,
      waistHipRatio: double.parse(whr.toStringAsFixed(2)),
      healthScore: hScore,
      postureScore: pScore,
      postureType: pType,
      chestCm: double.parse(chest.toStringAsFixed(1)),
      waistCm: double.parse(waist.toStringAsFixed(1)),
      hipsCm: double.parse(hips.toStringAsFixed(1)),
      thighLeftCm: double.parse(thighL.toStringAsFixed(1)),
      thighRightCm: double.parse(thighR.toStringAsFixed(1)),
      calfLeftCm: double.parse(calfL.toStringAsFixed(1)),
      calfRightCm: double.parse(calfR.toStringAsFixed(1)),
      armLeftCm: double.parse(armL.toStringAsFixed(1)),
      armRightCm: double.parse(armR.toStringAsFixed(1)),
      fitnessGoal: goal ?? 'Muscle Gain',
      recordedAt: recAt,
      modelUrl: mUrl,
      frontImg: fImg,
      leftImg: lImg,
      rightImg: rImg,
      backImg: bImg,
    );
  }
}

/// Represents a posture photo taken by the HowBody device scanner
class PosturePhoto {
  final String label;
  final String url;
  final String angle;

  const PosturePhoto({
    required this.label,
    required this.url,
    required this.angle,
  });
}

/// Official HowBody 3D Body Composition Report row
class HowbodyBodyReport {
  final String id;
  final String? memberId;
  final String? dataKey;
  final DateTime? testTime;
  final DateTime? createdAt;
  final double? weight;
  final double? bmi;
  final double? pbf; // Body fat percentage %
  final double? fat; // Fat mass kg
  final double? smm; // Skeletal muscle mass kg
  final double? tbw; // Total body water kg
  final double? bmr; // Basal metabolic rate kcal
  final int? vfr; // Visceral fat rating
  final int? metabolicAge;
  final double? whr; // Waist-to-hip ratio
  final int? healthScore;
  final double? targetWeight;
  final double? weightControl;
  final double? fatControl;
  final double? muscleControl;
  final double? icf;
  final double? ecf;
  final String? equipmentNo;

  const HowbodyBodyReport({
    required this.id,
    this.memberId,
    this.dataKey,
    this.testTime,
    this.createdAt,
    this.weight,
    this.bmi,
    this.pbf,
    this.fat,
    this.smm,
    this.tbw,
    this.bmr,
    this.vfr,
    this.metabolicAge,
    this.whr,
    this.healthScore,
    this.targetWeight,
    this.weightControl,
    this.fatControl,
    this.muscleControl,
    this.icf,
    this.ecf,
    this.equipmentNo,
  });

  factory HowbodyBodyReport.fromJson(Map<String, dynamic> json) {
    double? toD(dynamic v) => (v is num) ? v.toDouble() : (v is String ? double.tryParse(v) : null);
    int? toI(dynamic v) => (v is num) ? v.toInt() : (v is String ? int.tryParse(v) : null);

    final payload = (json['full_payload'] is Map) ? json['full_payload'] as Map : null;

    return HowbodyBodyReport(
      id: json['id'] as String? ?? '',
      memberId: json['member_id'] as String?,
      dataKey: json['data_key'] as String?,
      testTime: json['test_time'] != null ? DateTime.tryParse(json['test_time'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      weight: toD(json['weight'] ?? payload?['weight']),
      bmi: toD(json['bmi'] ?? payload?['bmi']),
      pbf: toD(json['pbf'] ?? payload?['pbf']),
      fat: toD(json['fat'] ?? payload?['fat']),
      smm: toD(json['smm'] ?? payload?['smm']),
      tbw: toD(json['tbw'] ?? payload?['tbw']),
      bmr: toD(json['bmr'] ?? payload?['bmr']),
      vfr: toI(json['vfr'] ?? payload?['vfr']),
      metabolicAge: toI(json['metabolic_age'] ?? payload?['metabolicAge'] ?? payload?['metabolic_age']),
      whr: toD(json['whr'] ?? payload?['whr']),
      healthScore: toI(json['health_score'] ?? payload?['healthScore'] ?? payload?['health_score']),
      targetWeight: toD(json['target_weight'] ?? payload?['targetWeight'] ?? payload?['target_weight']),
      weightControl: toD(json['weight_control'] ?? payload?['weightControl'] ?? payload?['weight_control']),
      fatControl: toD(json['fat_control'] ?? payload?['fatControl'] ?? payload?['fat_control']),
      muscleControl: toD(json['muscle_control'] ?? payload?['muscleControl'] ?? payload?['muscle_control']),
      icf: toD(json['icf'] ?? payload?['icf']),
      ecf: toD(json['ecf'] ?? payload?['ecf']),
      equipmentNo: (json['equipment_no'] ?? payload?['equipmentNo'] ?? payload?['equipment_no']) as String?,
    );
  }
}

/// Official HowBody 3D Posture & Circumference Assessment Report row
class HowbodyPostureReport {
  final String id;
  final String? memberId;
  final String? dataKey;
  final DateTime? testTime;
  final DateTime? createdAt;
  final int? score;
  final double? bodySlope;
  final double? headForward;
  final double? headSlant;
  final double? shoulderLeft;
  final double? shoulderRight;
  final double? highLowShoulder;
  final double? pelvisForward;
  final double? kneeLeft;
  final double? kneeRight;
  final double? legLeft;
  final double? legRight;
  final double? shoulderBack;
  // Circumferences
  final double? bust;
  final double? waist;
  final double? hip;
  final double? leftThigh;
  final double? rightThigh;
  final double? calfLeft;
  final double? calfRight;
  final double? upArmLeft;
  final double? upArmRight;
  // Device Photos & Visuals
  final String? frontImg;
  final String? leftImg;
  final String? rightImg;
  final String? backImg;
  final String? modelUrl;
  final String? equipmentNo;
  final String? postureType;
  final String? bodyShapeProfile;

  const HowbodyPostureReport({
    required this.id,
    this.memberId,
    this.dataKey,
    this.testTime,
    this.createdAt,
    this.score,
    this.bodySlope,
    this.headForward,
    this.headSlant,
    this.shoulderLeft,
    this.shoulderRight,
    this.highLowShoulder,
    this.pelvisForward,
    this.kneeLeft,
    this.kneeRight,
    this.legLeft,
    this.legRight,
    this.shoulderBack,
    this.bust,
    this.waist,
    this.hip,
    this.leftThigh,
    this.rightThigh,
    this.calfLeft,
    this.calfRight,
    this.upArmLeft,
    this.upArmRight,
    this.frontImg,
    this.leftImg,
    this.rightImg,
    this.backImg,
    this.modelUrl,
    this.equipmentNo,
    this.postureType,
    this.bodyShapeProfile,
  });

  List<PosturePhoto> get photos {
    final list = <PosturePhoto>[];
    if (frontImg != null && frontImg!.trim().isNotEmpty) {
      list.add(PosturePhoto(label: 'Front View', url: frontImg!.trim(), angle: 'Front'));
    }
    if (leftImg != null && leftImg!.trim().isNotEmpty) {
      list.add(PosturePhoto(label: 'Left Profile', url: leftImg!.trim(), angle: 'Left'));
    }
    if (rightImg != null && rightImg!.trim().isNotEmpty) {
      list.add(PosturePhoto(label: 'Right Profile', url: rightImg!.trim(), angle: 'Right'));
    }
    if (backImg != null && backImg!.trim().isNotEmpty) {
      list.add(PosturePhoto(label: 'Back View', url: backImg!.trim(), angle: 'Back'));
    }
    return list;
  }

  factory HowbodyPostureReport.fromJson(Map<String, dynamic> json) {
    double? toD(dynamic v) => (v is num) ? v.toDouble() : (v is String ? double.tryParse(v) : null);
    int? toI(dynamic v) => (v is num) ? v.toInt() : (v is String ? int.tryParse(v) : null);

    final payload = (json['full_payload'] is Map) ? json['full_payload'] as Map : null;

    String? extractImg(String snake, String camel, [String? alt]) {
      final v1 = json[snake];
      if (v1 is String && v1.trim().isNotEmpty) return v1.trim();
      final v2 = json[camel];
      if (v2 is String && v2.trim().isNotEmpty) return v2.trim();
      if (payload != null) {
        final p1 = payload[snake] ?? payload[camel] ?? (alt != null ? payload[alt] : null);
        if (p1 is String && p1.trim().isNotEmpty) return p1.trim();
      }
      return null;
    }

    final fImg = extractImg('front_img', 'frontImg', 'frontImage');
    final lImg = extractImg('left_img', 'leftImg', 'leftImage');
    final rImg = extractImg('right_img', 'rightImg', 'rightImage');
    final bImg = extractImg('back_img', 'backImg', 'backImage');
    final mUrl = extractImg('model_url', 'modelUrl', 'murl');

    return HowbodyPostureReport(
      id: json['id'] as String? ?? '',
      memberId: json['member_id'] as String?,
      dataKey: json['data_key'] as String?,
      testTime: json['test_time'] != null ? DateTime.tryParse(json['test_time'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      score: toI(json['score'] ?? payload?['score']),
      bodySlope: toD(json['body_slope'] ?? payload?['bodySlope'] ?? payload?['body_slope']),
      headForward: toD(json['head_forward'] ?? payload?['headForward'] ?? payload?['head_forward']),
      headSlant: toD(json['head_slant'] ?? payload?['headSlant'] ?? payload?['head_slant']),
      shoulderLeft: toD(json['shoulder_left'] ?? payload?['shoulderLeft'] ?? payload?['shoulder_left']),
      shoulderRight: toD(json['shoulder_right'] ?? payload?['shoulderRight'] ?? payload?['shoulder_right']),
      highLowShoulder: toD(json['high_low_shoulder'] ?? payload?['highLowShoulder'] ?? payload?['high_low_shoulder']),
      pelvisForward: toD(json['pelvis_forward'] ?? payload?['pelvisForward'] ?? payload?['pelvis_forward']),
      kneeLeft: toD(json['knee_left'] ?? payload?['kneeLeft'] ?? payload?['knee_left']),
      kneeRight: toD(json['knee_right'] ?? payload?['kneeRight'] ?? payload?['knee_right']),
      legLeft: toD(json['leg_left'] ?? payload?['legLeft'] ?? payload?['leg_left']),
      legRight: toD(json['leg_right'] ?? payload?['legRight'] ?? payload?['leg_right']),
      shoulderBack: toD(json['shoulder_back'] ?? payload?['shoulderBack'] ?? payload?['shoulder_back']),
      bust: toD(json['bust'] ?? payload?['bust']),
      waist: toD(json['waist'] ?? payload?['waist']),
      hip: toD(json['hip'] ?? payload?['hip']),
      leftThigh: toD(json['left_thigh'] ?? payload?['leftThigh'] ?? payload?['left_thigh']),
      rightThigh: toD(json['right_thigh'] ?? payload?['rightThigh'] ?? payload?['right_thigh']),
      calfLeft: toD(json['calf_left'] ?? payload?['calfLeft'] ?? payload?['calf_left']),
      calfRight: toD(json['calf_right'] ?? payload?['calfRight'] ?? payload?['calf_right']),
      upArmLeft: toD(json['up_arm_left'] ?? payload?['upArmLeft'] ?? payload?['up_arm_left']),
      upArmRight: toD(json['up_arm_right'] ?? payload?['upArmRight'] ?? payload?['up_arm_right']),
      frontImg: fImg,
      leftImg: lImg,
      rightImg: rImg,
      backImg: bImg,
      modelUrl: mUrl,
      equipmentNo: (json['equipment_no'] ?? payload?['equipmentNo'] ?? payload?['equipment_no']) as String?,
      postureType: (json['posture_type'] ?? payload?['postureType'] ?? payload?['posture_type']) as String?,
      bodyShapeProfile: (json['body_shape_profile'] ?? payload?['bodyShapeProfile'] ?? payload?['body_shape_profile']) as String?,
    );
  }
}

/// Unified 3D HowBody Scan Result containing composition, posture, photos & manual logs
class HowbodyScanResult {
  final HowbodyBodyReport? body;
  final HowbodyPostureReport? posture;
  final List<Map<String, dynamic>> manualLogs;
  final String? pdfUrl;
  final String? pdfSource;

  const HowbodyScanResult({
    this.body,
    this.posture,
    this.manualLogs = const [],
    this.pdfUrl,
    this.pdfSource,
  });

  const HowbodyScanResult.empty()
      : body = null,
        posture = null,
        manualLogs = const [],
        pdfUrl = null,
        pdfSource = null;

  bool get hasData => body != null || posture != null || manualLogs.isNotEmpty;

  List<PosturePhoto> get photos => posture?.photos ?? const [];
}
