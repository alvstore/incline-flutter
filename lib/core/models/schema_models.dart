import 'package:flutter/foundation.dart';

/// Strict, null-safe Dart models mapped directly to live PostgreSQL schema
/// Generated from introspecting Supabase production migrations & schema definitions.

/// ---------------------------------------------------------------------------
/// 1. MEMBER MODEL (public.members table)
/// ---------------------------------------------------------------------------
@immutable
class InclineMember {
  final String id;
  final String? userId;
  final String branchId;
  final String memberCode;
  final String status; // 'active', 'inactive', 'suspended', 'cancelled', 'expired', 'transferred'
  final String? source;
  final String? referredBy;
  final String? leadId;
  final String? healthConditions;
  final String? fitnessGoals;
  final String? notes;
  final List<String> workoutActivities;
  final String? gstin;
  final String? mipsPersonId;
  final String? mipsSyncStatus;
  final String? mipsPersonSn;
  final String? facePhotoSource;
  final String? mipsPhotoHash;
  final DateTime? mipsPhotoSyncedAt;
  final String? mipsDispatchStatus;
  final String? hardwareAccessStatus;
  final bool hardwareAccessEnabled;
  final String? wiegandCode;
  final String? customWelcomeMessage;
  final int rewardPoints;
  final bool botActive;
  final DateTime joinedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? deactivatedAt;
  final DateTime? mipsFaceVerifiedAt;

  const InclineMember({
    required this.id,
    this.userId,
    required this.branchId,
    required this.memberCode,
    this.status = 'active',
    this.source,
    this.referredBy,
    this.leadId,
    this.healthConditions,
    this.fitnessGoals,
    this.notes,
    this.workoutActivities = const [],
    this.gstin,
    this.mipsPersonId,
    this.mipsSyncStatus,
    this.mipsPersonSn,
    this.facePhotoSource,
    this.mipsPhotoHash,
    this.mipsPhotoSyncedAt,
    this.mipsDispatchStatus,
    this.hardwareAccessStatus,
    this.hardwareAccessEnabled = true,
    this.wiegandCode,
    this.customWelcomeMessage,
    this.rewardPoints = 0,
    this.botActive = true,
    required this.joinedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.deactivatedAt,
    this.mipsFaceVerifiedAt,
  });

  factory InclineMember.fromJson(Map<String, dynamic> json) {
    return InclineMember(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      branchId: json['branch_id'] as String? ?? '',
      memberCode: json['member_code'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      source: json['source'] as String?,
      referredBy: json['referred_by'] as String?,
      leadId: json['lead_id'] as String?,
      healthConditions: json['health_conditions'] as String?,
      fitnessGoals: json['fitness_goals'] as String?,
      notes: json['notes'] as String?,
      workoutActivities: (json['workout_activities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      gstin: json['gstin'] as String?,
      mipsPersonId: json['mips_person_id'] as String?,
      mipsSyncStatus: json['mips_sync_status'] as String?,
      mipsPersonSn: json['mips_person_sn'] as String?,
      facePhotoSource: json['face_photo_source'] as String?,
      mipsPhotoHash: json['mips_photo_hash'] as String?,
      mipsPhotoSyncedAt: json['mips_photo_synced_at'] != null
          ? DateTime.tryParse(json['mips_photo_synced_at'] as String)
          : null,
      mipsDispatchStatus: json['mips_dispatch_status'] as String?,
      hardwareAccessStatus: json['hardware_access_status'] as String?,
      hardwareAccessEnabled: json['hardware_access_enabled'] as bool? ?? true,
      wiegandCode: json['wiegand_code'] as String?,
      customWelcomeMessage: json['custom_welcome_message'] as String?,
      rewardPoints: (json['reward_points'] as num?)?.toInt() ?? 0,
      botActive: json['bot_active'] as bool? ?? true,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
      deactivatedAt: json['deactivated_at'] != null
          ? DateTime.tryParse(json['deactivated_at'] as String)
          : null,
      mipsFaceVerifiedAt: json['mips_face_verified_at'] != null
          ? DateTime.tryParse(json['mips_face_verified_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'branch_id': branchId,
      'member_code': memberCode,
      'status': status,
      'source': source,
      'referred_by': referredBy,
      'lead_id': leadId,
      'health_conditions': healthConditions,
      'fitness_goals': fitnessGoals,
      'notes': notes,
      'workout_activities': workoutActivities,
      'gstin': gstin,
      'mips_person_id': mipsPersonId,
      'mips_sync_status': mipsSyncStatus,
      'mips_person_sn': mipsPersonSn,
      'face_photo_source': facePhotoSource,
      'mips_photo_hash': mipsPhotoHash,
      'mips_photo_synced_at': mipsPhotoSyncedAt?.toIso8601String(),
      'mips_dispatch_status': mipsDispatchStatus,
      'hardware_access_status': hardwareAccessStatus,
      'hardware_access_enabled': hardwareAccessEnabled,
      'wiegand_code': wiegandCode,
      'custom_welcome_message': customWelcomeMessage,
      'reward_points': rewardPoints,
      'bot_active': botActive,
      'joined_at': joinedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
      if (deactivatedAt != null) 'deactivated_at': deactivatedAt!.toIso8601String(),
      if (mipsFaceVerifiedAt != null)
        'mips_face_verified_at': mipsFaceVerifiedAt!.toIso8601String(),
    };
  }
}

/// ---------------------------------------------------------------------------
/// 2. PT SESSION SETTLEMENT & COMMISSION (public.pt_commission_installments & public.pt_sessions)
/// ---------------------------------------------------------------------------
@immutable
class PtSessionSettlement {
  final String id;
  final String commissionId;
  final String trainerId;
  final String? branchId;
  final DateTime payoutMonth;
  final int installmentIndex;
  final double installmentAmount;
  final String status; // 'pending', 'paid', 'cancelled'
  final String? payrollItemId;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PtSessionSettlement({
    required this.id,
    required this.commissionId,
    required this.trainerId,
    this.branchId,
    required this.payoutMonth,
    this.installmentIndex = 1,
    this.installmentAmount = 0.0,
    this.status = 'pending',
    this.payrollItemId,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PtSessionSettlement.fromJson(Map<String, dynamic> json) {
    return PtSessionSettlement(
      id: json['id'] as String? ?? '',
      commissionId: json['commission_id'] as String? ?? '',
      trainerId: json['trainer_id'] as String? ?? '',
      branchId: json['branch_id'] as String?,
      payoutMonth: json['payout_month'] != null
          ? DateTime.parse(json['payout_month'] as String)
          : DateTime.now(),
      installmentIndex: (json['installment_index'] as num?)?.toInt() ?? 1,
      installmentAmount: (json['installment_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      payrollItemId: json['payroll_item_id'] as String?,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'commission_id': commissionId,
      'trainer_id': trainerId,
      'branch_id': branchId,
      'payout_month': payoutMonth.toIso8601String().substring(0, 10),
      'installment_index': installmentIndex,
      'installment_amount': installmentAmount,
      'status': status,
      'payroll_item_id': payrollItemId,
      'paid_at': paidAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// ---------------------------------------------------------------------------
/// 3. BOOKINGS MODELS (public.class_bookings & public.benefit_bookings)
/// ---------------------------------------------------------------------------
@immutable
class ClassBookingRecord {
  final String id;
  final String classId;
  final String memberId;
  final String status; // 'booked', 'cancelled', 'attended', 'no_show'
  final DateTime bookedAt;
  final DateTime? attendedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime createdAt;

  const ClassBookingRecord({
    required this.id,
    required this.classId,
    required this.memberId,
    this.status = 'booked',
    required this.bookedAt,
    this.attendedAt,
    this.cancelledAt,
    this.cancellationReason,
    required this.createdAt,
  });

  factory ClassBookingRecord.fromJson(Map<String, dynamic> json) {
    return ClassBookingRecord(
      id: json['id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      status: json['status'] as String? ?? 'booked',
      bookedAt: json['booked_at'] != null
          ? DateTime.parse(json['booked_at'] as String)
          : DateTime.now(),
      attendedAt: json['attended_at'] != null
          ? DateTime.tryParse(json['attended_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'] as String)
          : null,
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'member_id': memberId,
      'status': status,
      'booked_at': bookedAt.toIso8601String(),
      'attended_at': attendedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancellation_reason': cancellationReason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

@immutable
class BenefitBookingRecord {
  final String id;
  final String slotId;
  final String memberId;
  final String membershipId;
  final String status; // 'booked', 'cancelled', 'attended', 'no_show'
  final DateTime bookedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime? checkInAt;
  final DateTime? noShowMarkedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BenefitBookingRecord({
    required this.id,
    required this.slotId,
    required this.memberId,
    required this.membershipId,
    this.status = 'booked',
    required this.bookedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.checkInAt,
    this.noShowMarkedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BenefitBookingRecord.fromJson(Map<String, dynamic> json) {
    return BenefitBookingRecord(
      id: json['id'] as String? ?? '',
      slotId: json['slot_id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      membershipId: json['membership_id'] as String? ?? '',
      status: json['status'] as String? ?? 'booked',
      bookedAt: json['booked_at'] != null
          ? DateTime.parse(json['booked_at'] as String)
          : DateTime.now(),
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'] as String)
          : null,
      cancellationReason: json['cancellation_reason'] as String?,
      checkInAt: json['check_in_at'] != null
          ? DateTime.tryParse(json['check_in_at'] as String)
          : null,
      noShowMarkedAt: json['no_show_marked_at'] != null
          ? DateTime.tryParse(json['no_show_marked_at'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slot_id': slotId,
      'member_id': memberId,
      'membership_id': membershipId,
      'status': status,
      'booked_at': bookedAt.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancellation_reason': cancellationReason,
      'check_in_at': checkInAt?.toIso8601String(),
      'no_show_marked_at': noShowMarkedAt?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
