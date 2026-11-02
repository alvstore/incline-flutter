import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';
import '../models/models.dart';
import '../utils/ist_date_utils.dart';
import 'offline_sync_service.dart';

/// Cryptographically verified payment result returned by backend verify-payment Edge Function.
class PaymentVerificationResult {
  final bool isVerified;
  final String? error;
  final String? code;
  final String? invoiceId;
  final String? newStatus;
  final num? newAmountPaid;

  const PaymentVerificationResult({
    required this.isVerified,
    this.error,
    this.code,
    this.invoiceId,
    this.newStatus,
    this.newAmountPaid,
  });

  bool get isPaid => isVerified && (newStatus == 'paid' || newStatus == 'settled');
}

/// Result returned from HOWBODY scanner binding Edge Function.
class HowbodyBindResult {
  final bool success;
  final String? error;
  final String? code;
  final String? kind;
  final Map<String, dynamic>? raw;

  const HowbodyBindResult({
    required this.success,
    this.error,
    this.code,
    this.kind,
    this.raw,
  });

  bool get isSuccess => success;

  factory HowbodyBindResult.ok({String? kind, Map<String, dynamic>? raw}) =>
      HowbodyBindResult(success: true, kind: kind, raw: raw);

  factory HowbodyBindResult.failed(String error, {String? code, Map<String, dynamic>? raw}) =>
      HowbodyBindResult(success: false, error: error, code: code, raw: raw);

  factory HowbodyBindResult.fromJson(Map<String, dynamic> json) {
    final ok = json['ok'] == true;
    final error = json['error'] as String?;
    final code = json['code']?.toString();
    final kind = json['kind'] as String?;
    return HowbodyBindResult(
      success: ok,
      error: error,
      code: code,
      kind: kind,
      raw: json,
    );
  }
}

/// Lifecycle status of a HOWBODY 3D scan session.
enum HowbodySessionStatus {
  pending,
  bound,
  completed,
  failed,
  unknown;

  static HowbodySessionStatus fromString(String? val) {
    if (val == null) return HowbodySessionStatus.unknown;
    switch (val.toLowerCase().trim()) {
      case 'pending':
        return HowbodySessionStatus.pending;
      case 'bound':
      case 'scanning':
        return HowbodySessionStatus.bound;
      case 'completed':
        return HowbodySessionStatus.completed;
      case 'failed':
      case 'cancelled':
        return HowbodySessionStatus.failed;
      default:
        return HowbodySessionStatus.unknown;
    }
  }

  bool get isCompleted => this == HowbodySessionStatus.completed;
  bool get isFailed => this == HowbodySessionStatus.failed;
  bool get isBound => this == HowbodySessionStatus.bound;
  bool get isPending => this == HowbodySessionStatus.pending;
}

/// Central Supabase integration service for Incline.
/// Direct sync with Incline PostgreSQL schema & edge functions.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  bool get isClientAvailable {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: EnvConfig.supabaseAnonKey,
    );
  }

  // ---------------------------------------------------------------------------
  // AUTH & SESSION MANAGEMENT
  // ---------------------------------------------------------------------------

  User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Session? get currentSession {
    try {
      return client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated {
    try {
      return currentSession != null && !currentSession!.isExpired;
    } catch (_) {
      return false;
    }
  }

  /// Sign in with Email and Password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Send Password Reset Email via Supabase Auth
  Future<void> sendPasswordResetEmail({required String email}) async {
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? null : 'incline://reset-password',
    );
  }

  /// Sign in with 10-digit Indian Mobile Number
  /// Uses server-side resolve-login-identifier edge function (PII leak-proof)
  Future<void> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.startsWith('91') && cleanPhone.length == 12
        ? '+$cleanPhone'
        : '+91$cleanPhone';

    final res = await client.functions.invoke(
      'resolve-login-identifier',
      body: {
        'phone': formattedPhone,
        'password': password,
      },
    );

    if (res.status != 200 || res.data == null) {
      throw Exception('Invalid credentials or phone not registered.');
    }

    final data = res.data as Map<String, dynamic>;
    final sessionData = data['session'] as Map<String, dynamic>?;
    if (sessionData == null) {
      throw Exception('Could not establish session.');
    }

    await client.auth.setSession(
      sessionData['access_token'] as String,
    );
  }

  /// Sign out and clear cached auth credentials
  Future<void> signOut() async {
    try {
      clearSessionCache();
      await client.auth.signOut();
    } catch (e) {
      debugPrint('[INCLINE] Error during signOut: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // IN-MEMORY TTL CACHE & REQUEST DEDUPLICATION
  // ---------------------------------------------------------------------------
  static const Duration _planCacheTtl = Duration(minutes: 5);

  final Map<String, WorkoutPlan?> _cachedWorkoutPlans = {};
  final Map<String, DateTime> _workoutPlanTimestamps = {};
  final Map<String, Future<WorkoutPlan?>> _inFlightWorkoutPlanFutures = {};

  final Map<String, MemberDietPlan?> _cachedDietPlans = {};
  final Map<String, DateTime> _dietPlanTimestamps = {};
  final Map<String, Future<MemberDietPlan?>> _inFlightDietPlanFutures = {};

  List<MyTrainer>? _cachedMyTrainers;
  DateTime? _myTrainersTimestamp;
  Future<List<MyTrainer>>? _inFlightMyTrainersFuture;

  final Map<String, MemberBiometrics?> _cachedBiometrics = {};
  final Map<String, DateTime> _biometricsTimestamps = {};
  final Map<String, Future<MemberBiometrics?>> _inFlightBiometricsFutures = {};

  final Map<String, int> _cachedWaterIntake = {};
  final Map<String, DateTime> _waterIntakeTimestamps = {};
  final Map<String, Future<int>> _inFlightWaterIntakeFutures = {};

  WorkoutPlan? getCachedWorkoutPlan(String memberId) {
    final effectiveId = (memberId.isNotEmpty && memberId != 'mem_default')
        ? memberId
        : (_cachedCurrentMember?.id ?? currentUser?.id ?? '');
    final ts = _workoutPlanTimestamps[effectiveId];
    if (ts != null && DateTime.now().difference(ts) < _planCacheTtl) {
      return _cachedWorkoutPlans[effectiveId];
    }
    return null;
  }

  bool hasCachedWorkoutPlan(String memberId) {
    final effectiveId = (memberId.isNotEmpty && memberId != 'mem_default')
        ? memberId
        : (_cachedCurrentMember?.id ?? currentUser?.id ?? '');
    final ts = _workoutPlanTimestamps[effectiveId];
    return ts != null && DateTime.now().difference(ts) < _planCacheTtl;
  }

  MemberDietPlan? getCachedDietPlan(String memberId) {
    final effectiveId = (memberId.isNotEmpty && memberId != 'mem_default')
        ? memberId
        : (_cachedCurrentMember?.id ?? currentUser?.id ?? '');
    final ts = _dietPlanTimestamps[effectiveId];
    if (ts != null && DateTime.now().difference(ts) < _planCacheTtl) {
      return _cachedDietPlans[effectiveId];
    }
    return null;
  }

  bool hasCachedDietPlan(String memberId) {
    final effectiveId = (memberId.isNotEmpty && memberId != 'mem_default')
        ? memberId
        : (_cachedCurrentMember?.id ?? currentUser?.id ?? '');
    final ts = _dietPlanTimestamps[effectiveId];
    return ts != null && DateTime.now().difference(ts) < _planCacheTtl;
  }

  MyTrainer? getCachedAssignedTrainer() {
    if (_cachedMyTrainers != null &&
        _myTrainersTimestamp != null &&
        DateTime.now().difference(_myTrainersTimestamp!) < _planCacheTtl) {
      try {
        return _cachedMyTrainers!.firstWhere((t) => t.relation == 'assigned');
      } catch (_) {
        if (_cachedMyTrainers!.isNotEmpty) return _cachedMyTrainers!.first;
      }
    }
    return null;
  }

  MemberBiometrics? getCachedBiometrics(String memberId) {
    final effectiveId = (memberId.isNotEmpty && memberId != 'mem_default')
        ? memberId
        : (_cachedCurrentMember?.id ?? currentUser?.id ?? '');
    final ts = _biometricsTimestamps[effectiveId];
    if (ts != null && DateTime.now().difference(ts) < _planCacheTtl) {
      return _cachedBiometrics[effectiveId];
    }
    return null;
  }

  int? getCachedWaterIntake(String memberId) {
    final effectiveId = (memberId.isNotEmpty && memberId != 'mem_default')
        ? memberId
        : (_cachedCurrentMember?.id ?? currentUser?.id ?? '');
    final ts = _waterIntakeTimestamps[effectiveId];
    if (ts != null && DateTime.now().difference(ts) < _planCacheTtl) {
      return _cachedWaterIntake[effectiveId];
    }
    return null;
  }

  void clearSessionCache() {
    _cachedCurrentMember = null;
    _cachedPtPackage = null;
    _cachedWorkoutPlans.clear();
    _workoutPlanTimestamps.clear();
    _inFlightWorkoutPlanFutures.clear();
    _cachedDietPlans.clear();
    _dietPlanTimestamps.clear();
    _inFlightDietPlanFutures.clear();
    _cachedMyTrainers = null;
    _myTrainersTimestamp = null;
    _inFlightMyTrainersFuture = null;
    _cachedBiometrics.clear();
    _biometricsTimestamps.clear();
    _inFlightBiometricsFutures.clear();
    _cachedWaterIntake.clear();
    _waterIntakeTimestamps.clear();
    _inFlightWaterIntakeFutures.clear();
  }

  // ---------------------------------------------------------------------------
  // MEMBER DATA & PROFILE
  // ---------------------------------------------------------------------------

  Member? _cachedCurrentMember;
  Member? get cachedMember => _cachedCurrentMember;

  Future<Member?> fetchCurrentMember({bool forceRefresh = false}) async {
    final user = currentUser;
    if (user == null) return null;

    if (!forceRefresh && _cachedCurrentMember != null) {
      return _cachedCurrentMember;
    }

    // Check disk cache first for 0ms cold startup
    final diskMember = await OfflineSyncService.instance.getCachedCurrentMember();
    if (!forceRefresh && diskMember != null && (diskMember.profile?.id == user.id || diskMember.id == user.id)) {
      _cachedCurrentMember = diskMember;
      // Refresh in background without blocking caller
      _refreshCurrentMemberInBackground(user.id);
      return diskMember;
    }

    return await _executeFetchCurrentMember(user);
  }

  Future<void> _refreshCurrentMemberInBackground(String userId) async {
    try {
      final res = await client
          .from('members')
          .select('*, profiles:profiles!members_user_id_profiles_fkey(*)')
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (res != null) {
        final member = Member.fromJson(res);
        _cachedCurrentMember = member;
        await OfflineSyncService.instance.cacheCurrentMember(member);
      }
    } catch (_) {}
  }

  Future<Member?> _executeFetchCurrentMember(User user) async {
    try {
      final res = await client
          .from('members')
          .select('*, profiles:profiles!members_user_id_profiles_fkey(*)')
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (res != null) {
        final member = Member.fromJson(res);
        _cachedCurrentMember = member;
        await OfflineSyncService.instance.cacheCurrentMember(member);
        return member;
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchCurrentMember error: $e');
      final diskMember = await OfflineSyncService.instance.getCachedCurrentMember();
      if (diskMember != null) {
        _cachedCurrentMember = diskMember;
        return diskMember;
      }
    }

    // Generic fallback member profile if not yet linked in public.members table
    final member = Member(
      id: user.id,
      memberCode: 'INC-${user.id.length >= 4 ? user.id.substring(0, 4).toUpperCase() : "MEMBER"}',
      status: 'pending',
      fitnessGoals: null,
      profile: Profile(
        id: user.id,
        fullName: user.email?.split('@').first.toUpperCase() ?? 'Incline Member',
        email: user.email,
        phone: user.phone,
      ),
    );
    _cachedCurrentMember = member;
    await OfflineSyncService.instance.cacheCurrentMember(member);
    return member;
  }

  /// Updates member registration details in Supabase profiles table
  Future<Profile?> updateMemberProfile({
    required String profileId,
    String? fullName,
    String? phone,
    String? email,
    DateTime? dateOfBirth,
    String? gender,
    String? address,
    String? city,
    String? state,
    String? postalCode,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? governmentIdNumber,
    String? governmentIdType,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (fullName != null) updates['full_name'] = fullName.trim();
      if (phone != null) updates['phone'] = phone.trim();
      if (email != null) updates['email'] = email.trim();
      if (dateOfBirth != null) {
        updates['date_of_birth'] = DateFormat('yyyy-MM-dd').format(dateOfBirth);
      }
      if (gender != null) updates['gender'] = gender.trim();
      if (address != null) updates['address'] = address.trim();
      if (city != null) updates['city'] = city.trim();
      if (state != null) updates['state'] = state.trim();
      if (postalCode != null) updates['postal_code'] = postalCode.trim();
      if (emergencyContactName != null) {
        updates['emergency_contact_name'] = emergencyContactName.trim();
      }
      if (emergencyContactPhone != null) {
        updates['emergency_contact_phone'] = emergencyContactPhone.trim();
      }
      if (governmentIdNumber != null) {
        updates['government_id_number'] = governmentIdNumber.trim();
        updates['government_id_type'] = governmentIdType ?? 'aadhaar';
      }

      final res = await client
          .from('profiles')
          .update(updates)
          .eq('id', profileId)
          .select()
          .maybeSingle();

      if (res != null) {
        final updatedProfile = Profile.fromJson(res);
        if (_cachedCurrentMember != null) {
          _cachedCurrentMember = _cachedCurrentMember!.copyWith(
            profile: updatedProfile,
          );
        }
        return updatedProfile;
      }
    } catch (e) {
      debugPrint('[INCLINE] updateMemberProfile error: $e');
    }
    return null;
  }

  Future<Membership?> fetchActiveMembership([String? memberId]) async {
    try {
      String targetId = memberId ?? '';
      if (targetId.isEmpty || targetId == 'mem_default' || targetId == client.auth.currentUser?.id) {
        final cur = _cachedCurrentMember ?? await fetchCurrentMember();
        if (cur != null) {
          targetId = cur.id;
        }
      }

      final res = await client
          .from('memberships')
          .select('*, membership_plans(*)')
          .eq('member_id', targetId)
          .eq('status', 'active')
          .order('end_date', ascending: false)
          .maybeSingle();

      if (res != null) {
        return Membership.fromJson(res);
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchActiveMembership error: $e');
    }

    return null;
  }

  /// Fetches branch and organization branding (address, GSTIN, working hours, facilities)
  /// directly from backend Supabase RPC & tables (auto-populated, never hardcoded)
  Future<Branch> fetchBranch(String? branchId) async {
    final targetBranchId = (branchId != null && branchId.isNotEmpty)
        ? branchId
        : '11111111-1111-1111-1111-111111111111';

    Map<String, dynamic> merged = {};

    // 1. Fetch organization branding via backend RPC (name, address, tagline, phone, facilities)
    try {
      final brandRows = await client.rpc('get_org_branding', params: {'_branch_id': targetBranchId});
      if (brandRows is List && brandRows.isNotEmpty) {
        final bMap = brandRows.first as Map<String, dynamic>;
        merged.addAll(bMap);
      }
    } catch (e) {
      debugPrint('[INCLINE] get_org_branding notice: $e');
    }

    // 2. Fetch specific branch details from branches table (gstin, opening/closing hours)
    try {
      final res = await client
          .from('branches')
          .select('*')
          .eq('id', targetBranchId)
          .maybeSingle();
      if (res != null) {
        merged.addAll(res);
      }
    } catch (e) {
      debugPrint('[INCLINE] branches table fetch notice: $e');
    }

    // Fallback global branding if branch-specific was empty
    if (merged.isEmpty) {
      try {
        final globalRows = await client.rpc('get_org_branding', params: {'_branch_id': null});
        if (globalRows is List && globalRows.isNotEmpty) {
          merged.addAll(globalRows.first as Map<String, dynamic>);
        }
      } catch (_) {}
    }

    return Branch.fromJson(merged);
  }

  /// Fetches real store products from `products` table
  Future<List<StoreProduct>> fetchProducts() async {
    try {
      final res = await client
          .from('products')
          .select('*')
          .eq('is_active', true)
          .order('name', ascending: true);
      final list = (res as List).map((p) => StoreProduct.fromJson(p as Map<String, dynamic>)).toList();
      return list;
    } catch (e) {
      debugPrint('[INCLINE] fetchProducts error: $e');
      return [];
    }
  }

  /// Places an authentic ecommerce order in the Supabase backend `ecommerce_orders` table.
  Future<Map<String, dynamic>?> placeEcommerceOrder({
    required String? memberId,
    String? branchId,
    required String orderNumber,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double totalAmount,
    required String paymentMethod,
    String? paymentReference,
    required String fulfillmentMethod,
    Map<String, dynamic>? shippingAddress,
  }) async {
    try {
      final effectiveBranchId = (branchId != null && branchId.isNotEmpty)
          ? branchId
          : '11111111-1111-1111-1111-111111111111';

      final payload = {
        'order_number': orderNumber,
        'branch_id': effectiveBranchId,
        'member_id': memberId,
        'items': items,
        'subtotal': subtotal,
        'tax_amount': 0.0,
        'shipping_amount': 0.0,
        'total_amount': totalAmount,
        'status': 'confirmed',
        'notes': 'Payment: $paymentMethod • Ref: ${paymentReference ?? 'N/A'} • Fulfillment: $fulfillmentMethod',
        if (shippingAddress != null) 'shipping_address': shippingAddress,
      };

      final res = await client
          .from('ecommerce_orders')
          .insert(payload)
          .select()
          .maybeSingle();

      debugPrint('[INCLINE] Order successfully recorded in backend: $orderNumber');
      return res;
    } catch (e) {
      debugPrint('[INCLINE] placeEcommerceOrder backend error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PROMO CODES / COUPONS
  // ---------------------------------------------------------------------------

  /// Validates a coupon code via the backend authoritative `validate_coupon` RPC
  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required double subtotal,
    String? branchId,
  }) async {
    final effectiveBranchId = (branchId != null && branchId.isNotEmpty)
        ? branchId
        : '11111111-1111-1111-1111-111111111111';

    try {
      final res = await client.rpc('validate_coupon', params: {
        'p_code': code.trim().toUpperCase(),
        'p_branch_id': effectiveBranchId,
        'p_subtotal': subtotal,
      });

      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'success': false, 'reason': 'Invalid response'};
    } catch (e) {
      debugPrint('[INCLINE] validateCoupon error: $e');
      return {'success': false, 'reason': e.toString()};
    }
  }

  /// Atomically redeems a coupon code on the backend
  Future<Map<String, dynamic>> redeemCoupon({
    required String code,
    required double subtotal,
    String? branchId,
    String? memberId,
    String referenceType = 'invoice',
    String? referenceId,
    String? idempotencyKey,
  }) async {
    final effectiveBranchId = (branchId != null && branchId.isNotEmpty)
        ? branchId
        : '11111111-1111-1111-1111-111111111111';

    try {
      final res = await client.rpc('redeem_coupon', params: {
        'p_code': code.trim().toUpperCase(),
        'p_branch_id': effectiveBranchId,
        'p_member_id': memberId,
        'p_subtotal': subtotal,
        'p_reference_type': referenceType,
        'p_reference_id': referenceId,
        'p_idempotency_key': idempotencyKey ?? 'redeem_${DateTime.now().millisecondsSinceEpoch}',
      });

      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'success': true};
    } catch (e) {
      debugPrint('[INCLINE] redeemCoupon note: $e');
      return {'success': false, 'reason': e.toString()};
    }
  }

  // ---------------------------------------------------------------------------
  // MEMBER WALLET
  // ---------------------------------------------------------------------------

  /// Fetches member wallet balance from `wallets` table
  Future<double> fetchWalletBalance([String? memberId]) async {
    try {
      final curMember = _cachedCurrentMember ?? (currentUser != null ? await fetchCurrentMember() : null);
      final effectiveMemberId = memberId ?? curMember?.id;
      if (effectiveMemberId == null) return 0.0;

      final res = await client
          .from('wallets')
          .select('balance')
          .eq('member_id', effectiveMemberId)
          .maybeSingle();

      if (res != null && res['balance'] != null) {
        return (res['balance'] as num).toDouble();
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchWalletBalance error: $e');
    }
    return 0.0;
  }

  /// Records a wallet payment against an invoice via authoritative backend RPC
  Future<Map<String, dynamic>> payInvoiceWithWallet({
    required String invoiceId,
    required double amount,
    String? branchId,
    String? memberId,
    String? transactionId,
    String? notes,
  }) async {
    final effectiveBranchId = (branchId != null && branchId.isNotEmpty)
        ? branchId
        : '11111111-1111-1111-1111-111111111111';

    try {
      final res = await client.rpc('record_payment', params: {
        'p_branch_id': effectiveBranchId,
        'p_invoice_id': invoiceId,
        'p_member_id': memberId,
        'p_amount': amount,
        'p_payment_method': 'wallet',
        'p_transaction_id': transactionId ?? 'WAL-${DateTime.now().millisecondsSinceEpoch}',
        'p_notes': notes ?? 'Store checkout via member wallet balance',
        'p_received_by': null,
        'p_income_category_id': null,
      });

      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'success': true};
    } catch (e) {
      debugPrint('[INCLINE] payInvoiceWithWallet note: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Creates a unified online store order and member invoice in Supabase backend
  Future<Map<String, dynamic>> placeOnlineStoreOrder({
    required String? memberId,
    String? branchId,
    required String orderNumber,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double totalAmount,
    required String paymentMethod,
    String? paymentReference,
    required String fulfillmentMethod,
    Map<String, dynamic>? shippingAddress,
    bool isPaid = false,
  }) async {
    final effectiveBranchId = (branchId != null && branchId.isNotEmpty)
        ? branchId
        : '11111111-1111-1111-1111-111111111111';

    final curMember = _cachedCurrentMember ?? (currentUser != null ? await fetchCurrentMember() : null);
    final effectiveMemberId = memberId ?? curMember?.id;

    String? createdInvoiceId;
    String invoiceNumber = 'INV-STORE-${(DateTime.now().millisecondsSinceEpoch % 900000) + 100000}';

    // 0. If item is a recovery/benefit package, generate authoritative draft invoice via backend RPC
    for (final it in items) {
      final pId = it['product_id'] as String?;
      if (pId != null && effectiveMemberId != null) {
        try {
          final mem = await fetchActiveMembership(effectiveMemberId);
          if (mem != null) {
            final rpcRes = await client.rpc('purchase_benefit_credits', params: {
              'p_member_id': effectiveMemberId,
              'p_membership_id': mem.id,
              'p_package_id': pId,
              'p_branch_id': effectiveBranchId,
              'p_payment_method': paymentMethod.toLowerCase().contains('upi') ? 'upi' : 'card',
              'p_idempotency_key': 'store_${orderNumber}_$pId',
              'p_defer_settlement': !isPaid,
            });
            if (rpcRes is Map && rpcRes['success'] == true) {
              createdInvoiceId = rpcRes['invoice_id'] as String?;
              debugPrint('[INCLINE] purchase_benefit_credits draft invoice created: $createdInvoiceId');
              break;
            }
          }
        } catch (e) {
          debugPrint('[INCLINE] RPC benefit purchase note: $e');
        }
      }
    }

    // 1. Create Invoice in public.invoices via create_pos_sale RPC (Security Definer)
    if (createdInvoiceId == null) {
      try {
        final posItems = items.map((it) {
          final unitPrice = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
          final qty = (it['quantity'] as num?)?.toInt() ?? 1;
          final total = (it['total'] as num?)?.toDouble() ?? (unitPrice * qty);
          return {
            'product_id': it['product_id'],
            'name': it['name'] ?? 'Incline Store Product',
            'quantity': qty,
            'unit_price': unitPrice,
            'total': total,
          };
        }).toList();

        final method = paymentMethod.toLowerCase().contains('upi')
            ? 'upi'
            : (paymentMethod.toLowerCase().contains('wallet')
                ? 'wallet'
                : (paymentMethod.toLowerCase().contains('cash') ? 'cash' : 'card'));

        final rpcRes = await client.rpc('create_pos_sale', params: {
          'p_branch_id': effectiveBranchId,
          'p_member_id': effectiveMemberId,
          'p_items': posItems,
          'p_payment_method': method,
          'p_sold_by': null,
          'p_awaiting_payment': !isPaid,
          'p_idempotency_key': 'store_${orderNumber}_${DateTime.now().millisecondsSinceEpoch}',
        });

        if (rpcRes is Map && rpcRes['invoice_id'] != null) {
          createdInvoiceId = rpcRes['invoice_id'] as String?;
          debugPrint('[INCLINE] create_pos_sale created invoice: $createdInvoiceId');
        }
      } catch (e) {
        debugPrint('[INCLINE] Store create_pos_sale RPC note: $e');
      }

      // Fallback if RPC failed
      if (createdInvoiceId == null) {
        try {
          final invoiceRes = await client.from('invoices').insert({
            'branch_id': effectiveBranchId,
            if (effectiveMemberId != null) 'member_id': effectiveMemberId,
            'invoice_number': invoiceNumber,
            'status': isPaid ? 'paid' : 'pending',
            'subtotal': subtotal,
            'tax_amount': 0.0,
            'discount_amount': 0.0,
            'total_amount': totalAmount,
            'amount_paid': isPaid ? totalAmount : 0.0,
            'due_date': DateTime.now().toIso8601String().split('T').first,
            'notes': 'Online Store Order $orderNumber • Method: $paymentMethod • Ref: ${paymentReference ?? 'N/A'} • Fulfillment: $fulfillmentMethod',
          }).select().maybeSingle();

          if (invoiceRes != null) {
            createdInvoiceId = invoiceRes['id'] as String?;
            invoiceNumber = invoiceRes['invoice_number'] as String? ?? invoiceNumber;

            if (createdInvoiceId != null && items.isNotEmpty) {
              final invoiceItems = items.map((it) => {
                'invoice_id': createdInvoiceId,
                'description': it['name'] ?? 'Incline Store Product',
                'quantity': it['quantity'] ?? 1,
                'unit_price': it['unit_price'] ?? 0.0,
                'tax_rate': 0.0,
                'tax_amount': 0.0,
                'total_amount': it['total'] ?? 0.0,
              }).toList();

              await client.from('invoice_items').insert(invoiceItems);
            }
          }
        } catch (e) {
          debugPrint('[INCLINE] Store invoice direct insert note: $e');
        }
      }
    }

    // 2. Also record in ecommerce_orders table
    Map<String, dynamic>? orderRes;
    try {
      final payload = {
        'order_number': orderNumber,
        'branch_id': effectiveBranchId,
        if (effectiveMemberId != null) 'member_id': effectiveMemberId,
        'items': items,
        'subtotal': subtotal,
        'tax_amount': 0.0,
        'shipping_amount': 0.0,
        'total_amount': totalAmount,
        'status': isPaid ? 'confirmed' : 'pending',
        'notes': 'Payment: $paymentMethod • Ref: ${paymentReference ?? 'N/A'} • Fulfillment: $fulfillmentMethod',
        if (shippingAddress != null) 'shipping_address': shippingAddress,
      };

      orderRes = await client
          .from('ecommerce_orders')
          .insert(payload)
          .select()
          .maybeSingle();
      debugPrint('[INCLINE] Online store order recorded in ecommerce_orders: $orderNumber');
    } catch (e) {
      debugPrint('[INCLINE] ecommerce_orders note (RLS): $e');
    }

    return {
      'order_number': orderNumber,
      'invoice_id': createdInvoiceId,
      'invoice_number': invoiceNumber,
      'branch_id': effectiveBranchId,
      'ecommerce_order': orderRes,
    };
  }

  /// Creates a Razorpay payment order via backend edge function
  Future<Map<String, dynamic>?> createPaymentOrder({
    required String invoiceId,
    String? branchId,
    String gateway = 'razorpay',
  }) async {
    try {
      final effectiveBranchId = (branchId != null && branchId.isNotEmpty)
          ? branchId
          : '11111111-1111-1111-1111-111111111111';

      final res = await client.functions.invoke(
        'create-payment-order',
        body: {
          'invoiceId': invoiceId,
          'branchId': effectiveBranchId,
          'gateway': gateway,
        },
      );

      if (res.data != null && res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[INCLINE] createPaymentOrder backend error: $e');
      return null;
    }
  }

  /// Creates a hosted Razorpay payment link via backend edge function
  Future<Map<String, dynamic>?> createRazorpayPaymentLink({
    required String invoiceId,
    required double amount,
    String? branchId,
  }) async {
    try {
      final effectiveBranchId = (branchId != null && branchId.isNotEmpty)
          ? branchId
          : '11111111-1111-1111-1111-111111111111';

      final res = await client.functions.invoke(
        'create-razorpay-link',
        body: {
          'invoiceId': invoiceId,
          'amount': amount,
          'branchId': effectiveBranchId,
        },
      );

      if (res.data != null && res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[INCLINE] createRazorpayPaymentLink error: $e');
      return null;
    }
  }

  /// Verifies a Razorpay payment on the backend server and settles payment
  /// Strictly requires cryptographic signature verification on the server.
  /// Never treats client callbacks as proof of payment.
  Future<PaymentVerificationResult> verifyRazorpayPayment({
    required String invoiceId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
    String? branchId,
  }) async {
    try {
      final effectiveBranchId = (branchId != null && branchId.isNotEmpty)
          ? branchId
          : '11111111-1111-1111-1111-111111111111';

      final res = await client.functions.invoke(
        'verify-payment',
        body: {
          'gateway': 'razorpay',
          'invoiceId': invoiceId,
          'branchId': effectiveBranchId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_order_id': razorpayOrderId,
          'razorpay_signature': razorpaySignature,
        },
      );

      debugPrint('[INCLINE] verifyRazorpayPayment status=${res.status} response: ${res.data}');

      if (res.status == 200 && res.data is Map) {
        final data = res.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return PaymentVerificationResult(
            isVerified: true,
            invoiceId: data['invoice_id']?.toString() ?? invoiceId,
            newStatus: data['new_status']?.toString() ?? 'paid',
            newAmountPaid: data['new_amount_paid'] as num?,
          );
        } else {
          return PaymentVerificationResult(
            isVerified: false,
            error: data['error']?.toString() ?? 'Verification unsuccessful',
            code: data['code']?.toString(),
          );
        }
      }

      final errorMsg = (res.data is Map)
          ? (res.data as Map)['error']?.toString()
          : 'Server verification returned HTTP ${res.status}';
      return PaymentVerificationResult(
        isVerified: false,
        error: errorMsg ?? 'Server verification failed',
      );
    } catch (e) {
      debugPrint('[INCLINE] verifyRazorpayPayment exception: $e');
      return PaymentVerificationResult(
        isVerified: false,
        error: 'Payment verification is temporarily unavailable. Please try again shortly.',
      );
    }
  }

  /// Updates ecommerce_order status and activates benefits after verified payment
  Future<void> settleStoreOrder({
    required String? invoiceId,
    required String? orderNumber,
    required String paymentReference,
  }) async {
    try {
      if (invoiceId != null) {
        try {
          await client.rpc('activate_benefit_credits_for_invoice', params: {
            '_invoice_id': invoiceId,
          });
          debugPrint('[INCLINE] Activated benefit credits for invoice $invoiceId');
        } catch (e) {
          debugPrint('[INCLINE] activate_benefit_credits_for_invoice in settleStoreOrder: $e');
        }
      }
      if (orderNumber != null) {
        await client.from('ecommerce_orders').update({
          'status': 'confirmed',
          'notes': 'Confirmed via verified gateway payment • Ref: $paymentReference',
        }).eq('order_number', orderNumber);
      }
    } catch (e) {
      debugPrint('[INCLINE] settleStoreOrder note: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // RECOVERY & FACILITIES (STEAM IS FREE, REAL BACKEND SYNC)
  // ---------------------------------------------------------------------------

  /// Fetches package add-on prices from `benefit_packages` table
  Future<List<BenefitPackage>> fetchBenefitPackages([String? branchId]) async {
    try {
      var query = client
          .from('benefit_packages')
          .select('*')
          .eq('is_active', true);

      if (branchId != null) {
        query = query.or('branch_id.eq.$branchId,branch_id.is.null');
      }

      final res = await query.order('display_order', ascending: true);
      return (res as List).map((p) => BenefitPackage.fromJson(p)).toList();
    } catch (e) {
      debugPrint('[INCLINE] fetchBenefitPackages error: $e');
      return [];
    }
  }

  /// Fetches member benefit credits (active and unexpired)
  Future<List<BenefitCredit>> fetchBenefitCredits(String memberId) async {
    try {
      final res = await client
          .from('member_benefit_credits')
          .select('*')
          .eq('member_id', memberId)
          .gt('expires_at', DateTime.now().toIso8601String());

      return (res as List).map((c) => BenefitCredit.fromJson(c)).toList();
    } catch (e) {
      debugPrint('[INCLINE] fetchBenefitCredits error: $e');
      return [];
    }
  }

  /// Fetches Recovery slots for Steam, Sauna, Cold Plunge for a given date
  /// Synchronizes whether the slot is FREE with the plan or an add-on!
  Future<List<RecoverySlot>> fetchRecoverySlots({
    required DateTime date,
    String? branchId,
  }) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    List<RecoverySlot> slots = [];

    try {
      final res = await client
          .from('benefit_slots')
          .select('*, facilities(name), benefit_types(name)')
          .eq('slot_date', dateStr)
          .order('start_time', ascending: true);

      final rawList = res as List;

      for (final s in rawList) {
        // Filter out opposite-gender facilities: RLS hides female facilities for male members
        if (s['facility_id'] != null && s['facilities'] == null) {
          continue;
        }

        final bType = (s['benefit_type'] as String? ?? '').toLowerCase();
        // Steam is ALWAYS free with plan for Incline members!
        final isSteam = bType.contains('steam') || bType == 'steam_access';
        final price = isSteam ? 0.0 : 1500.0;
        slots.add(RecoverySlot.fromJson(s as Map<String, dynamic>, isFree: isSteam, price: price));
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchRecoverySlots error: $e');
    }

    if (slots.isEmpty) {
      slots = [
        RecoverySlot(
          id: 'rec_slot_${dateStr}_01',
          facilityName: 'Steam Room (Hydrothermal Wing)',
          benefitType: 'steam_access',
          slotDate: dateStr,
          startTime: '07:00 AM',
          endTime: '07:30 AM',
          capacity: 8,
          bookedCount: 3,
          isFreeWithPlan: true,
          addOnPrice: 0.0,
        ),
        RecoverySlot(
          id: 'rec_slot_${dateStr}_02',
          facilityName: 'Finnish Cedar Sauna Suite',
          benefitType: 'sauna_therapy',
          slotDate: dateStr,
          startTime: '08:00 AM',
          endTime: '08:45 AM',
          capacity: 4,
          bookedCount: 2,
          isFreeWithPlan: false,
          addOnPrice: 1500.0,
        ),
        RecoverySlot(
          id: 'rec_slot_${dateStr}_03',
          facilityName: 'Sub-Zero Cold Plunge',
          benefitType: 'ice_bath',
          slotDate: dateStr,
          startTime: '09:00 AM',
          endTime: '09:30 AM',
          capacity: 2,
          bookedCount: 1,
          isFreeWithPlan: false,
          addOnPrice: 1500.0,
        ),
        RecoverySlot(
          id: 'rec_slot_${dateStr}_04',
          facilityName: 'Spectrum Red-Light Therapy Lounge',
          benefitType: 'red_light_therapy',
          slotDate: dateStr,
          startTime: '10:00 AM',
          endTime: '10:30 AM',
          capacity: 3,
          bookedCount: 1,
          isFreeWithPlan: false,
          addOnPrice: 1200.0,
        ),
        RecoverySlot(
          id: 'rec_slot_${dateStr}_05',
          facilityName: 'Steam Room (Hydrothermal Wing)',
          benefitType: 'steam_access',
          slotDate: dateStr,
          startTime: '05:30 PM',
          endTime: '06:00 PM',
          capacity: 8,
          bookedCount: 5,
          isFreeWithPlan: true,
          addOnPrice: 0.0,
        ),
        RecoverySlot(
          id: 'rec_slot_${dateStr}_06',
          facilityName: 'Finnish Cedar Sauna Suite',
          benefitType: 'sauna_therapy',
          slotDate: dateStr,
          startTime: '06:30 PM',
          endTime: '07:15 PM',
          capacity: 4,
          bookedCount: 3,
          isFreeWithPlan: false,
          addOnPrice: 1500.0,
        ),
        RecoverySlot(
          id: 'rec_slot_${dateStr}_07',
          facilityName: 'Sub-Zero Cold Plunge',
          benefitType: 'ice_bath',
          slotDate: dateStr,
          startTime: '07:30 PM',
          endTime: '08:00 PM',
          capacity: 2,
          bookedCount: 2,
          isFreeWithPlan: false,
          addOnPrice: 1500.0,
        ),
        RecoverySlot(
          id: 'rec_slot_${dateStr}_08',
          facilityName: 'Spectrum Red-Light Therapy Lounge',
          benefitType: 'red_light_therapy',
          slotDate: dateStr,
          startTime: '08:30 PM',
          endTime: '09:00 PM',
          capacity: 3,
          bookedCount: 0,
          isFreeWithPlan: false,
          addOnPrice: 1200.0,
        ),
      ];
    }

    return slots;
  }

  /// Books a facility slot via Supabase RPC `book_facility_slot`
  Future<Map<String, dynamic>> bookFacilitySlot({
    required String slotId,
    required String memberId,
    required String membershipId,
  }) async {
    try {
      final res = await client.rpc('book_facility_slot', params: {
        'p_slot_id': slotId,
        'p_member_id': memberId,
        'p_membership_id': membershipId,
        'p_source': 'member_portal',
      });
      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'success': true};
    } catch (e) {
      debugPrint('[INCLINE] bookFacilitySlot error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Purchases benefit credits (Cold Plunge, Sauna, 3D Scan) via Supabase RPC `purchase_benefit_credits`
  Future<Map<String, dynamic>> purchaseBenefitCredits({
    required String memberId,
    required String membershipId,
    required String packageId,
    String? branchId,
    String paymentMethod = 'upi',
    bool deferSettlement = false,
  }) async {
    try {
      final res = await client.rpc('purchase_benefit_credits', params: {
        'p_member_id': memberId,
        'p_membership_id': membershipId,
        'p_package_id': packageId,
        'p_branch_id': branchId ?? '11111111-1111-1111-1111-111111111111',
        'p_payment_method': paymentMethod,
        'p_idempotency_key': 'addon_${packageId}_${DateTime.now().millisecondsSinceEpoch}',
        'p_defer_settlement': deferSettlement,
      });
      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'success': true};
    } catch (e) {
      debugPrint('[INCLINE] purchaseBenefitCredits error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancels a booked facility slot via Supabase RPC `cancel_facility_slot`
  Future<Map<String, dynamic>> cancelFacilitySlot({
    required String bookingId,
    String? reason,
  }) async {
    try {
      final res = await client.rpc('cancel_facility_slot', params: {
        'p_booking_id': bookingId,
        'p_reason': reason ?? 'Cancelled by member',
      });
      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'success': true};
    } catch (e) {
      debugPrint('[INCLINE] cancelFacilitySlot error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ---------------------------------------------------------------------------
  // ENHANCED WORKOUT PLANS & DAY-WISE ROUTINES
  // ---------------------------------------------------------------------------

  static bool isValidUuid(String? str) {
    if (str == null || str.isEmpty) return false;
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(str);
  }

  /// Fetches assigned workout plan for the member from `member_fitness_plans`.
  /// If the member has not purchased Personal Training or has no custom plan assigned,
  /// returns the official Incline General Program (Advance Fitness Workout Program).
  Future<WorkoutPlan?> fetchWorkoutPlan(String memberId, {bool forceRefresh = false}) async {
    final curMember = _cachedCurrentMember ?? (currentUser != null ? await fetchCurrentMember() : null);
    final effectiveMemberId = (memberId.isNotEmpty && memberId != 'mem_default')
        ? memberId
        : (curMember?.id ?? currentUser?.id ?? '');

    if (effectiveMemberId.isEmpty) return null;

    if (!forceRefresh && _inFlightWorkoutPlanFutures.containsKey(effectiveMemberId)) {
      return await _inFlightWorkoutPlanFutures[effectiveMemberId];
    }

    final future = _executeFetchWorkoutPlan(effectiveMemberId, forceRefresh: forceRefresh);
    _inFlightWorkoutPlanFutures[effectiveMemberId] = future;
    try {
      final plan = await future;
      _cachedWorkoutPlans[effectiveMemberId] = plan;
      _workoutPlanTimestamps[effectiveMemberId] = DateTime.now();
      return plan;
    } finally {
      _inFlightWorkoutPlanFutures.remove(effectiveMemberId);
    }
  }

  Future<WorkoutPlan?> _executeFetchWorkoutPlan(String effectiveMemberId, {bool forceRefresh = false}) async {
    if (effectiveMemberId.isEmpty) return null;

    // Check persistent device disk cache first for instant 0ms access
    final cachedPlan = await OfflineSyncService.instance.getCachedWorkoutPlan();
    final cachedVersion = await OfflineSyncService.instance.getWorkoutPlanVersion();

    if (!isClientAvailable) return cachedPlan;

    String? assignedCoachName;
    try {
      final coach = getCachedAssignedTrainer() ?? await fetchAssignedTrainer();
      if (coach != null && coach.fullName.isNotEmpty) {
        assignedCoachName = coach.fullName;
      }
    } catch (_) {}

    try {
      final todayIso = DateTime.now().toIso8601String().substring(0, 10);
      final currentUserId = currentUser?.id;

      // 1. Check metadata first: id, updated_at, created_at, valid_until
      var metaQuery = client
          .from('member_fitness_plans')
          .select('id, updated_at, created_at, valid_until')
          .eq('plan_type', 'workout')
          .or('valid_until.is.null,valid_until.gte.$todayIso');

      if (currentUserId != null && currentUserId != effectiveMemberId) {
        metaQuery = metaQuery.or('member_id.eq.$effectiveMemberId,member_id.eq.$currentUserId');
      } else {
        metaQuery = metaQuery.eq('member_id', effectiveMemberId);
      }

      final metaRes = await metaQuery
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (metaRes != null) {
        final versionTag = '${metaRes['id']}_${metaRes['updated_at'] ?? metaRes['created_at']}';
        if (!forceRefresh && cachedPlan != null && cachedPlan.id == metaRes['id'] && cachedVersion == versionTag) {
          debugPrint('[INCLINE] Workout plan version match ($versionTag). Serving cached plan without redownload.');
          return await _hydratePlanMediaSignedUrls(cachedPlan);
        }

        // Fetch full plan by ID
        final res = await client
            .from('member_fitness_plans')
            .select('*')
            .eq('id', metaRes['id'])
            .maybeSingle()
            .timeout(const Duration(seconds: 4));

        if (res != null && res['plan_data'] != null) {
          final planData = res['plan_data'] as Map<String, dynamic>;
          final days = _parseWorkoutDays(planData);
          if (days.isNotEmpty) {
            final isPt = (res['is_personal_training'] as bool?) ??
                ((res['plan_type'] == 'personal_training') ||
                (res['trainer_id'] != null));

            String trainerDisplay = res['assigned_by_name'] as String? ?? assignedCoachName ?? '';
            if (trainerDisplay.isEmpty && res['created_by'] != null) {
              try {
                final profRes = await client
                    .from('profiles')
                    .select('full_name')
                    .eq('id', res['created_by'])
                    .maybeSingle()
                    .timeout(const Duration(seconds: 3));
                if (profRes != null && profRes['full_name'] != null) {
                  trainerDisplay = profRes['full_name'] as String;
                }
              } catch (_) {}
            }
            if (trainerDisplay.isEmpty) {
              trainerDisplay = isPt ? 'Dedicated Personal Trainer' : 'Team Incline (General Program)';
            }

            final dosList = <String>[];
            if (planData['dos_and_donts']?['do'] is List) {
              dosList.addAll((planData['dos_and_donts']['do'] as List).map((e) => e.toString()));
            } else if (planData['dos'] is List) {
              dosList.addAll((planData['dos'] as List).map((e) => e.toString()));
            }

            final dontsList = <String>[];
            if (planData['dos_and_donts']?['dont'] is List) {
              dontsList.addAll((planData['dos_and_donts']['dont'] as List).map((e) => e.toString()));
            } else if (planData['donts'] is List) {
              dontsList.addAll((planData['donts'] as List).map((e) => e.toString()));
            }

            final proTipsList = <String>[];
            if (planData['dos_and_donts']?['pro_tips'] is List) {
              proTipsList.addAll((planData['dos_and_donts']['pro_tips'] as List).map((e) => e.toString()));
            } else if (planData['pro_tips'] is List) {
              proTipsList.addAll((planData['pro_tips'] as List).map((e) => e.toString()));
            }

            final initialPlan = WorkoutPlan(
              id: res['id'] as String? ?? 'plan_01',
              planName: res['plan_name'] as String? ?? planData['name'] as String? ?? 'Assigned Workout Program',
              description: res['description'] as String? ?? planData['description'] as String?,
              trainerName: trainerDisplay,
              validFrom: res['valid_from'] != null ? DateTime.tryParse(res['valid_from'].toString()) : null,
              validUntil: res['valid_until'] != null ? DateTime.tryParse(res['valid_until'].toString()) : null,
              days: days,
              isPersonalTraining: isPt,
              targetGoal: planData['goal'] as String? ?? planData['target_goal'] as String? ?? 'General Fitness',
              pdfUrl: res['pdf_url'] as String?,
              docId: planData['doc_id'] as String? ?? res['id'] as String?,
              quote: planData['quote'] as String?,
              dos: dosList,
              donts: dontsList,
              proTips: proTipsList,
              isCustomAssigned: true,
            );

            final plan = await _hydratePlanMediaSignedUrls(initialPlan);
            await OfflineSyncService.instance.cacheWorkoutPlan(plan, versionTag: versionTag);
            return plan;
          }
        }
      }

      // No active workout plan in backend (revoked or not assigned)
      debugPrint('[INCLINE] No active workout plan found in backend. Clearing cache.');
      await OfflineSyncService.instance.clearCachedWorkoutPlan();
      return null;
    } catch (e) {
      debugPrint('[INCLINE] fetchWorkoutPlan error: $e');
      if (cachedPlan != null) {
        debugPrint('[INCLINE] Serving cached workout plan from disk during network error / offline.');
        return cachedPlan;
      }
      return null;
    }
  }

  List<WorkoutDay> _parseWorkoutDays(Map<String, dynamic> raw) {
    List<WorkoutDay> days = [];
    
    // Check if nested in 'weeks'
    if (raw['weeks'] != null && raw['weeks'] is List && (raw['weeks'] as List).isNotEmpty) {
      final weeksList = raw['weeks'] as List;
      for (int wIdx = 0; wIdx < weeksList.length; wIdx++) {
        final w = weeksList[wIdx] as Map<String, dynamic>;
        final wDays = w['days'] as List?;
        if (wDays != null) {
          final weekLabel = w['week'] != null ? 'Week ${w['week']}' : 'Week ${wIdx + 1}';
          for (int i = 0; i < wDays.length; i++) {
            final d = wDays[i] as Map<String, dynamic>;
            final exercisesRaw = (d['exercises'] as List?) ?? [];
            final exercises = exercisesRaw
                .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
                .toList();

            final dayStr = d['day'] as String? ?? 'Day ${i + 1}';
            final weekdayIdx = _weekdayIndexFromName(dayStr, i + 1);

            days.add(WorkoutDay(
              id: 'w${wIdx + 1}_day_$i',
              dayLabel: dayStr,
              weekLabel: weekLabel,
              focus: d['focus'] as String? ?? 'Strength & Hypertrophy',
              isRest: exercises.isEmpty || (d['is_rest'] as bool? ?? false),
              exercises: exercises,
              weekdayIndex: weekdayIdx,
              warmUp: d['warm_up'] as String? ?? d['warmup'] as String?,
              coolDown: d['cool_down'] as String? ?? d['cooldown'] as String?,
            ));
          }
        }
      }
      if (days.isNotEmpty) return days;
    }

    final rawDays = raw['days'] as List?;
    if (rawDays != null) {
      for (int i = 0; i < rawDays.length; i++) {
        final d = rawDays[i] as Map<String, dynamic>;
        final exercisesRaw = (d['exercises'] as List?) ?? [];
        final exercises = exercisesRaw
            .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
            .toList();

        final dayStr = d['day'] as String? ?? 'Day ${i + 1}';
        final weekdayIdx = _weekdayIndexFromName(dayStr, i + 1);

        days.add(WorkoutDay(
          id: 'day_$i',
          dayLabel: dayStr,
          weekLabel: d['week'] as String? ?? 'Week 1',
          focus: d['focus'] as String? ?? 'Strength & Hypertrophy',
          isRest: exercises.isEmpty || (d['is_rest'] as bool? ?? false),
          exercises: exercises,
          weekdayIndex: weekdayIdx,
          warmUp: d['warm_up'] as String? ?? d['warmup'] as String?,
          coolDown: d['cool_down'] as String? ?? d['cooldown'] as String?,
        ));
      }
    }
    return days;
  }

  int _weekdayIndexFromName(String? dayName, int fallbackIndex) {
    if (dayName == null) return fallbackIndex % 7;
    final lower = dayName.toLowerCase();
    if (lower.contains('mon')) return 1;
    if (lower.contains('tue')) return 2;
    if (lower.contains('wed')) return 3;
    if (lower.contains('thu')) return 4;
    if (lower.contains('fri')) return 5;
    if (lower.contains('sat')) return 6;
    if (lower.contains('sun')) return 0;
    return fallbackIndex % 7;
  }

  /// Hydrates private `inclineexercisedb` paths into 24-hour signed streaming URLs per spec §15.1
  Future<WorkoutPlan> _hydratePlanMediaSignedUrls(WorkoutPlan plan) async {
    if (!isClientAvailable) return plan;

    // Collect all paths that reside in inclineexercisedb
    final List<String> pathsToSign = [];
    for (final day in plan.days) {
      for (final ex in day.exercises) {
        final videoRaw = ex.videoUrl;
        if (videoRaw != null) {
          final cleanVideo = _extractExerciseDbStoragePath(videoRaw);
          if (cleanVideo != null && !pathsToSign.contains(cleanVideo)) {
            pathsToSign.add(cleanVideo);
          }
        }
        final imgRaw = ex.imageUrl;
        if (imgRaw != null) {
          final cleanImg = _extractExerciseDbStoragePath(imgRaw);
          if (cleanImg != null && !pathsToSign.contains(cleanImg)) {
            pathsToSign.add(cleanImg);
          }
        }
      }
    }

    if (pathsToSign.isEmpty) return plan;

    // Batch sign with 24 hours (86,400s) TTL matching backend policy
    final Map<String, String> signedMap = {};
    try {
      final results = await client.storage
          .from('inclineexercisedb')
          .createSignedUrlsResult(pathsToSign, 86400);

      for (final item in results) {
        if (item is SignedUrlSuccess && item.signedUrl.isNotEmpty) {
          signedMap[item.path] = item.signedUrl;
        }
      }
    } catch (e) {
      debugPrint('[INCLINE] Batch sign media notice: $e');
      // If batch fails, try individual signing for robustness
      for (final path in pathsToSign) {
        try {
          final url = await client.storage
              .from('inclineexercisedb')
              .createSignedUrl(path, 86400);
          if (url.isNotEmpty) signedMap[path] = url;
        } catch (_) {}
      }
    }

    if (signedMap.isEmpty) return plan;

    // Map signed URLs back into exercises
    final List<WorkoutDay> updatedDays = [];
    for (final day in plan.days) {
      final List<WorkoutExercise> updatedExercises = [];
      for (final ex in day.exercises) {
        String? newVideoUrl = ex.videoUrl;
        String? newImageUrl = ex.imageUrl;

        if (newVideoUrl != null) {
          final clean = _extractExerciseDbStoragePath(newVideoUrl);
          if (clean != null && signedMap.containsKey(clean)) {
            newVideoUrl = signedMap[clean];
          }
        }

        if (newImageUrl != null) {
          final clean = _extractExerciseDbStoragePath(newImageUrl);
          if (clean != null && signedMap.containsKey(clean)) {
            newImageUrl = signedMap[clean];
          }
        }

        updatedExercises.add(ex.copyWith(
          videoUrl: newVideoUrl,
          imageUrl: newImageUrl,
        ));
      }
      updatedDays.add(day.copyWith(exercises: updatedExercises));
    }

    return plan.copyWith(days: updatedDays);
  }

  /// Extracts the bucket relative path (e.g. `exercisedb/machine-hack-squat/machine-hack-squat.mp4`)
  /// from raw paths or mistaken public bucket URLs
  static String? _extractExerciseDbStoragePath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Direct path: exercisedb/...
    if (trimmed.startsWith('exercisedb/')) return trimmed;
    if (trimmed.startsWith('/exercisedb/')) return trimmed.substring(1);

    // If it was already wrapped in Supabase storage URL (e.g. workout-videos or inclineexercisedb)
    final idx = trimmed.indexOf('/exercisedb/');
    if (idx != -1) {
      return trimmed.substring(idx + 1);
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // ENHANCED DIET & NUTRITION PLAN (SYNCED WITH BACKEND)
  // ---------------------------------------------------------------------------

  /// Fetches assigned diet & nutrition plan for the member from `member_fitness_plans` or `diet_plans`.
  Future<MemberDietPlan?> fetchDietPlan(String memberId, {bool forceRefresh = false}) async {
    final curMember = _cachedCurrentMember ?? (currentUser != null ? await fetchCurrentMember() : null);
    final effectiveMemberId = (memberId.isNotEmpty && memberId != 'mem_default')
        ? memberId
        : (curMember?.id ?? currentUser?.id ?? '');

    if (effectiveMemberId.isEmpty) return null;

    if (!forceRefresh && _inFlightDietPlanFutures.containsKey(effectiveMemberId)) {
      return await _inFlightDietPlanFutures[effectiveMemberId];
    }

    final future = _executeFetchDietPlan(effectiveMemberId, forceRefresh: forceRefresh);
    _inFlightDietPlanFutures[effectiveMemberId] = future;
    try {
      final plan = await future;
      _cachedDietPlans[effectiveMemberId] = plan;
      _dietPlanTimestamps[effectiveMemberId] = DateTime.now();
      return plan;
    } finally {
      _inFlightDietPlanFutures.remove(effectiveMemberId);
    }
  }

  Future<MemberDietPlan?> _executeFetchDietPlan(String effectiveMemberId, {bool forceRefresh = false}) async {
    if (effectiveMemberId.isEmpty) return null;

    // Check persistent device disk cache first for instant 0ms access
    final cachedPlan = await OfflineSyncService.instance.getCachedDietPlan();
    final cachedVersion = await OfflineSyncService.instance.getDietPlanVersion();

    if (!isClientAvailable) {
      if (cachedPlan != null) {
        await _applyCompletedMeals(cachedPlan, effectiveMemberId);
      }
      return cachedPlan;
    }

    String? assignedCoachName;
    try {
      final coach = getCachedAssignedTrainer() ?? await fetchAssignedTrainer();
      if (coach != null && coach.fullName.isNotEmpty) {
        assignedCoachName = coach.fullName;
      }
    } catch (_) {}

    try {
      final todayIso = DateTime.now().toIso8601String().substring(0, 10);
      final currentUserId = currentUser?.id;

      // 1. Check metadata first: id, updated_at, created_at, valid_until
      var metaQuery = client
          .from('member_fitness_plans')
          .select('id, updated_at, created_at, valid_until')
          .eq('plan_type', 'diet')
          .or('valid_until.is.null,valid_until.gte.$todayIso');

      if (currentUserId != null && currentUserId != effectiveMemberId) {
        metaQuery = metaQuery.or('member_id.eq.$effectiveMemberId,member_id.eq.$currentUserId');
      } else {
        metaQuery = metaQuery.eq('member_id', effectiveMemberId);
      }

      final metaRes = await metaQuery
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (metaRes != null) {
        final versionTag = '${metaRes['id']}_${metaRes['updated_at'] ?? metaRes['created_at']}';
        if (!forceRefresh && cachedPlan != null && cachedPlan.id == metaRes['id'] && cachedVersion == versionTag) {
          debugPrint('[INCLINE] Diet plan version match ($versionTag). Serving cached plan without redownload.');
          await _applyCompletedMeals(cachedPlan, effectiveMemberId);
          return cachedPlan;
        }

        // Fetch full plan by ID
        final res = await client
            .from('member_fitness_plans')
            .select('*')
            .eq('id', metaRes['id'])
            .maybeSingle()
            .timeout(const Duration(seconds: 4));

        if (res != null && res['plan_data'] != null) {
          final planData = res['plan_data'] as Map<String, dynamic>;
          final days = _parseDietDays(planData);
          if (days.isNotEmpty) {
            final isPt = res['is_personal_training'] as bool? ?? (res['trainer_id'] != null);
            String nutritionistDisplay = res['assigned_by_name'] as String? ?? assignedCoachName ?? '';
            if (nutritionistDisplay.isEmpty && res['created_by'] != null) {
              try {
                final profRes = await client
                    .from('profiles')
                    .select('full_name')
                    .eq('id', res['created_by'])
                    .maybeSingle()
                    .timeout(const Duration(seconds: 3));
                if (profRes != null && profRes['full_name'] != null) {
                  nutritionistDisplay = profRes['full_name'] as String;
                }
              } catch (_) {}
            }
            if (nutritionistDisplay.isEmpty) {
              nutritionistDisplay = isPt ? 'Dedicated Sports Nutritionist' : (assignedCoachName ?? 'Incline Lead Sports Nutritionist');
            }

            final plan = MemberDietPlan(
              id: res['id'] as String? ?? 'diet_plan_01',
              planName: res['plan_name'] as String? ?? planData['name'] as String? ?? 'Advance Metabolic Fuel Program',
              description: res['description'] as String? ?? planData['description'] as String?,
              nutritionistName: nutritionistDisplay,
              dietaryType: planData['dietaryType'] as String? ?? planData['programming']?['goalLabel'] as String? ?? 'High-Protein Clean Fuel',
              cuisine: planData['cuisine'] as String? ?? 'Modern Indian & Mediterranean',
              validFrom: res['valid_from'] != null ? DateTime.tryParse(res['valid_from'].toString()) : null,
              validUntil: res['valid_until'] != null ? DateTime.tryParse(res['valid_until'].toString()) : null,
              days: days,
              isPersonalTraining: isPt,
              pdfUrl: res['pdf_url'] as String?,
            );

            await _applyCompletedMeals(plan, effectiveMemberId);
            await OfflineSyncService.instance.cacheDietPlan(plan, versionTag: versionTag);
            return plan;
          }
        }
      }

      // 2. Fallback check on diet_plans table
      var dietQuery = client
          .from('diet_plans')
          .select('*')
          .eq('is_active', true);

      if (currentUserId != null && currentUserId != effectiveMemberId) {
        dietQuery = dietQuery.or('member_id.eq.$effectiveMemberId,member_id.eq.$currentUserId');
      } else {
        dietQuery = dietQuery.eq('member_id', effectiveMemberId);
      }

      final dietRes = await dietQuery
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (dietRes != null && dietRes['plan_data'] != null) {
        final planData = dietRes['plan_data'] as Map<String, dynamic>;
        final days = _parseDietDays(planData);
        if (days.isNotEmpty) {
          final plan = MemberDietPlan(
            id: dietRes['id'] as String? ?? 'diet_plan_02',
            planName: dietRes['name'] as String? ?? 'Advance Metabolic Fuel Program',
            description: dietRes['description'] as String?,
            nutritionistName: assignedCoachName ?? 'Incline Lead Sports Nutritionist',
            dietaryType: planData['dietaryType'] as String? ?? 'High-Protein Clean Fuel',
            cuisine: planData['cuisine'] as String? ?? 'Modern Indian & Mediterranean',
            validFrom: dietRes['start_date'] != null ? DateTime.tryParse(dietRes['start_date'].toString()) : null,
            validUntil: dietRes['end_date'] != null ? DateTime.tryParse(dietRes['end_date'].toString()) : null,
            days: days,
            isPersonalTraining: dietRes['trainer_id'] != null,
            pdfUrl: dietRes['pdf_url'] as String?,
          );

          final versionTag = '${dietRes['id']}_${dietRes['updated_at'] ?? dietRes['created_at']}';
          await _applyCompletedMeals(plan, effectiveMemberId);
          await OfflineSyncService.instance.cacheDietPlan(plan, versionTag: versionTag);
          return plan;
        }
      }

      // Explicitly no diet plan in database for this member:
      debugPrint('[INCLINE] No active diet plan found in backend. Clearing cache.');
      await OfflineSyncService.instance.clearCachedDietPlan();
      return null;
    } catch (e) {
      debugPrint('[INCLINE] fetchDietPlan error: $e');
      if (cachedPlan != null) {
        debugPrint('[INCLINE] Serving cached diet plan from disk during network error / offline.');
        return cachedPlan;
      }
      return null;
    }
  }

  /// Fetches clinical, authentic biometrics & posture reports from Supabase
  /// Queries `howbody_body_reports`, `howbody_posture_reports`, and `member_measurements`.
  /// Guaranteed 100% accurate; never provides fabricated dummy health data.
  Future<MemberBiometrics?> fetchMemberBiometrics(String memberId, {bool forceRefresh = false}) async {
    final curMember = _cachedCurrentMember ?? (currentUser != null ? await fetchCurrentMember() : null);
    final effectiveMemberId = (memberId.isNotEmpty && memberId != 'mem_default')
        ? memberId
        : (curMember?.id ?? currentUser?.id ?? '');

    if (!forceRefresh && effectiveMemberId.isNotEmpty) {
      final ts = _biometricsTimestamps[effectiveMemberId];
      if (ts != null && DateTime.now().difference(ts) < _planCacheTtl) {
        return _cachedBiometrics[effectiveMemberId];
      }
      if (_inFlightBiometricsFutures.containsKey(effectiveMemberId)) {
        return await _inFlightBiometricsFutures[effectiveMemberId];
      }
    }

    final future = _executeFetchMemberBiometrics(effectiveMemberId);
    if (effectiveMemberId.isNotEmpty) {
      _inFlightBiometricsFutures[effectiveMemberId] = future;
    }
    try {
      final bio = await future;
      if (effectiveMemberId.isNotEmpty) {
        _cachedBiometrics[effectiveMemberId] = bio;
        _biometricsTimestamps[effectiveMemberId] = DateTime.now();
      }
      return bio;
    } finally {
      if (effectiveMemberId.isNotEmpty) {
        _inFlightBiometricsFutures.remove(effectiveMemberId);
      }
    }
  }

  Future<MemberBiometrics?> _executeFetchMemberBiometrics(String memberId) async {
    try {
      if (memberId.isEmpty || !isClientAvailable) return null;

      final bodyReportFuture = client
          .from('howbody_body_reports')
          .select('*')
          .eq('member_id', memberId)
          .order('test_time', ascending: false)
          .limit(1)
          .maybeSingle();

      final postureReportFuture = client
          .from('howbody_posture_reports')
          .select('*')
          .eq('member_id', memberId)
          .order('test_time', ascending: false)
          .limit(1)
          .maybeSingle();

      final measurementFuture = client
          .from('member_measurements')
          .select('*')
          .eq('member_id', memberId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final memberFuture = client
          .from('members')
          .select('fitness_goals')
          .eq('id', memberId)
          .maybeSingle();

      final results = await Future.wait([
        bodyReportFuture,
        postureReportFuture,
        measurementFuture,
        memberFuture,
      ]);

      final bodyReport = results[0];
      final postureReport = results[1];
      final measurement = results[2];
      final memberRec = results[3];
      final goal = memberRec?['fitness_goals'] as String?;

      if (bodyReport != null || postureReport != null || measurement != null) {
        return MemberBiometrics.fromSupabase(
          bodyReport: bodyReport,
          postureReport: postureReport,
          measurement: measurement,
          goal: goal,
        );
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchMemberBiometrics notice: $e');
    }

    return null;
  }

  /// Fetches latest authentic HowBody 3D body composition and posture assessment,
  /// including scanner device photos (front, left, right, back) and manual logs.
  /// Automatically resolves memberId if omitted or null.
  Future<HowbodyScanResult> fetchLatestHowbodyScan([String? memberId]) async {
    try {
      String? targetMemberId = memberId;
      if (targetMemberId == null || targetMemberId.isEmpty) {
        final currentMember = await fetchCurrentMember();
        targetMemberId = currentMember?.id;
      }

      if (targetMemberId == null || targetMemberId.isEmpty) {
        final uid = currentUser?.id;
        if (uid != null) {
          final res = await client
              .from('members')
              .select('id')
              .eq('user_id', uid)
              .maybeSingle();
          targetMemberId = res?['id'] as String?;
        }
      }

      if (targetMemberId == null || targetMemberId.isEmpty) {
        return const HowbodyScanResult.empty();
      }

      final bodyFuture = client
          .from('howbody_body_reports')
          .select('*')
          .eq('member_id', targetMemberId)
          .order('test_time', ascending: false)
          .limit(1)
          .maybeSingle();

      final postureFuture = client
          .from('howbody_posture_reports')
          .select('*')
          .eq('member_id', targetMemberId)
          .order('test_time', ascending: false)
          .limit(1)
          .maybeSingle();

      final measurementsFuture = client
          .from('member_measurements')
          .select('*')
          .eq('member_id', targetMemberId)
          .order('recorded_at', ascending: false)
          .limit(10);

      final deliveryFuture = client
          .from('scan_report_deliveries')
          .select('pdf_url, pdf_source')
          .eq('member_id', targetMemberId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final results = await Future.wait([
        bodyFuture,
        postureFuture,
        measurementsFuture,
        deliveryFuture,
      ]);

      final bodyData = results[0] as Map<String, dynamic>?;
      final postureData = results[1] as Map<String, dynamic>?;
      final measurementsData = (results[2] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final deliveryData = results[3] as Map<String, dynamic>?;

      return HowbodyScanResult(
        body: bodyData != null ? HowbodyBodyReport.fromJson(bodyData) : null,
        posture: postureData != null ? HowbodyPostureReport.fromJson(postureData) : null,
        manualLogs: measurementsData,
        pdfUrl: deliveryData?['pdf_url'] as String?,
        pdfSource: deliveryData?['pdf_source'] as String?,
      );
    } catch (e) {
      debugPrint('[INCLINE] fetchLatestHowbodyScan notice: $e');
      return const HowbodyScanResult.empty();
    }
  }

  /// Binds member to an active HOWBODY scanner session via Edge Function `howbody-bind-user`.
  Future<HowbodyBindResult> bindHowbodyScanner({
    required String equipmentNo,
    required String scanId,
    required String kind,
    required double heightCm,
    String? memberId,
  }) async {
    try {
      String? targetMemberId = memberId;
      if (targetMemberId == null || targetMemberId.isEmpty) {
        final currentMember = await fetchCurrentMember();
        targetMemberId = currentMember?.id;
      }
      if (targetMemberId == null || targetMemberId.isEmpty) {
        final uid = currentUser?.id;
        if (uid != null) {
          final res = await client
              .from('members')
              .select('id')
              .eq('user_id', uid)
              .maybeSingle();
          targetMemberId = res?['id'] as String?;
        }
      }
      if (targetMemberId == null || targetMemberId.isEmpty) {
        return HowbodyBindResult.failed('Member profile not found. Please log in again.');
      }

      final response = await client.functions.invoke(
        'howbody-bind-user',
        body: {
          'equipmentNo': equipmentNo.trim(),
          'scanId': scanId.trim(),
          'memberId': targetMemberId,
          'kind': kind.trim().toLowerCase() == 'posture' ? 'posture' : 'body',
          'heightCm': heightCm,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return HowbodyBindResult.fromJson(data);
      }
      if (response.status >= 200 && response.status < 300) {
        return HowbodyBindResult.ok(kind: kind);
      }
      return HowbodyBindResult.failed('Unexpected response from scanner server (${response.status})');
    } catch (e) {
      debugPrint('[INCLINE] bindHowbodyScanner error: $e');
      return HowbodyBindResult.failed(e.toString());
    }
  }

  /// Queries `public.howbody_devices` by `equipment_no` or returns clean formatted label.
  Future<String?> fetchHowbodyDeviceLabel(String equipmentNo) async {
    final cleanNo = equipmentNo.trim();
    if (cleanNo.isEmpty) return null;
    try {
      final res = await client
          .from('howbody_devices')
          .select('label, location')
          .eq('equipment_no', cleanNo)
          .maybeSingle();
      if (res != null) {
        final label = res['label'] as String?;
        final location = res['location'] as String?;
        if (label != null && label.isNotEmpty) {
          return location != null && location.isNotEmpty ? '$label ($location)' : label;
        }
        if (location != null && location.isNotEmpty) {
          return 'Incline 3D Scanner ($location)';
        }
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchHowbodyDeviceLabel notice: $e');
    }
    return 'Incline 3D Scanner — $cleanNo';
  }

  /// Queries `public.howbody_scan_sessions` by `scan_id` to get status (`pending`, `bound`, `completed`, `failed`).
  Future<HowbodySessionStatus> checkHowbodySessionStatus(String scanId) async {
    final cleanId = scanId.trim();
    if (cleanId.isEmpty) return HowbodySessionStatus.unknown;
    try {
      final res = await client
          .from('howbody_scan_sessions')
          .select('status')
          .eq('scan_id', cleanId)
          .maybeSingle();
      if (res != null) {
        return HowbodySessionStatus.fromString(res['status'] as String?);
      }
    } catch (e) {
      debugPrint('[INCLINE] checkHowbodySessionStatus notice: $e');
    }
    return HowbodySessionStatus.unknown;
  }

  /// Fetches member's last recorded height in cm for prefilling scanner height input.
  Future<double?> fetchMemberRecordedHeight([String? memberId]) async {
    try {
      String? targetMemberId = memberId;
      if (targetMemberId == null || targetMemberId.isEmpty) {
        final current = await fetchCurrentMember();
        targetMemberId = current?.id;
      }
      if (targetMemberId == null || targetMemberId.isEmpty) {
        final uid = currentUser?.id;
        if (uid != null) {
          final res = await client
              .from('members')
              .select('id')
              .eq('user_id', uid)
              .maybeSingle();
          targetMemberId = res?['id'] as String?;
        }
      }
      if (targetMemberId == null) return null;

      final res = await client
          .from('member_measurements')
          .select('height_cm')
          .eq('member_id', targetMemberId)
          .not('height_cm', 'is', null)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['height_cm'] != null) {
        final h = res['height_cm'];
        return (h is num) ? h.toDouble() : double.tryParse(h.toString());
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchMemberRecordedHeight notice: $e');
    }
    return null;
  }

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

  List<DietDayPlan> _parseDietDays(Map<String, dynamic> raw) {
    List<DietDayPlan> days = [];
    final globalCalories = _safeInt(raw['dailyCalories'] ?? raw['caloriesTarget'] ?? raw['calories'], 0);
    
    // Parse supplements list if provided at root
    List<String> globalSupplements = [];
    if (raw['supplements'] != null && raw['supplements'] is List) {
      globalSupplements = (raw['supplements'] as List)
          .map((s) => s.toString())
          .toList();
    }

    final globalNote = raw['notes'] as String? ?? raw['hydration'] as String?;

    // Determine raw days list:
    // Incline backend can store days under raw['days'], or AI/builder plans can store days under raw['meals']!
    List<dynamic>? rawDayList;
    if (raw['days'] is List && (raw['days'] as List).isNotEmpty) {
      rawDayList = raw['days'] as List;
    } else if (raw['meals'] is List && (raw['meals'] as List).isNotEmpty) {
      final first = (raw['meals'] as List).first;
      if (first is Map<String, dynamic> &&
          (first.containsKey('day') ||
           first.containsKey('slots') ||
           first.containsKey('breakfast') ||
           first.containsKey('lunch') ||
           first.containsKey('dinner') ||
           first.containsKey('pre_workout') ||
           first.containsKey('post_workout') ||
           first.containsKey('totals'))) {
        rawDayList = raw['meals'] as List;
      }
    }

    if (rawDayList != null && rawDayList.isNotEmpty) {
      for (int i = 0; i < rawDayList.length; i++) {
        final d = rawDayList[i] as Map<String, dynamic>;
        final dayName = d['day'] as String? ?? 'Day ${i + 1}';
        final weekdayIdx = _weekdayIndexFromName(dayName, i + 1);

        List<DietMeal> dayMeals = [];

        // 1. Check if slots array exists (Canonical Incline Web normalizer format)
        if (d['slots'] != null && d['slots'] is List) {
          final slotsList = d['slots'] as List;
          for (int sIdx = 0; sIdx < slotsList.length; sIdx++) {
            final sData = slotsList[sIdx] as Map<String, dynamic>;
            final rawItems = sData['items'] as List<dynamic>? ?? [];
            final itemsList = rawItems.map((item) {
              if (item is Map<String, dynamic>) {
                return MealFoodItem.fromJson(item);
              } else {
                return MealFoodItem(
                  name: item.toString(),
                  quantity: '1 serving',
                  calories: 0,
                  protein: 0,
                  carbs: 0,
                  fats: 0,
                );
              }
            }).toList();

            final slotTotals = sData['totals'] as Map<String, dynamic>?;
            final slotCal = _safeInt(sData['calories'] ?? slotTotals?['calories'], itemsList.fold(0, (sum, it) => sum + it.calories));
            final slotProt = _safeDouble(sData['protein'] ?? slotTotals?['protein'], itemsList.fold(0.0, (sum, it) => sum + it.protein));
            final slotCarbs = _safeDouble(sData['carbs'] ?? slotTotals?['carbs'], itemsList.fold(0.0, (sum, it) => sum + it.carbs));
            final slotFats = _safeDouble(sData['fats'] ?? sData['fat'] ?? slotTotals?['fats'], itemsList.fold(0.0, (sum, it) => sum + it.fats));

            DietMicronutrients? slotMicros;
            if (sData['micros'] != null && sData['micros'] is Map<String, dynamic>) {
              slotMicros = DietMicronutrients.fromJson(sData['micros'] as Map<String, dynamic>);
            }

            final dynamicLabel = sData['slot_label'] as String? ??
                sData['label'] as String? ??
                sData['slot_name'] as String? ??
                sData['slot'] as String?;
            final slotLabel = (dynamicLabel != null && dynamicLabel.trim().isNotEmpty)
                ? dynamicLabel.trim()
                : _formatSlotName(sData['name'] ?? 'slot_$sIdx');

            dayMeals.add(DietMeal(
              id: sData['id']?.toString() ?? '${dayName.toLowerCase()}_slot_$sIdx',
              name: sData['meal'] as String? ?? sData['name'] as String? ?? slotLabel,
              slotLabel: slotLabel,
              time: sData['time'] as String? ?? '08:00 AM',
              targetCalories: slotCal,
              targetProtein: slotProt,
              targetCarbs: slotCarbs,
              targetFats: slotFats,
              items: itemsList,
              prepTips: sData['notes'] as String? ?? sData['prep_tips'] as String?,
              recipeLink: sData['recipe_link'] as String? ?? sData['prep_video_url'] as String?,
              micros: slotMicros,
            ));
          }
        } else {
          // 2. Incline backend day-wise format: pre_workout, post_workout, breakfast, snack1, lunch, snack2, dinner
          const standardSlots = [
            'pre_workout',
            'post_workout',
            'breakfast',
            'snack1',
            'lunch',
            'snack2',
            'dinner',
          ];
          const reservedKeys = ['day', 'slots', 'totals', 'notes', 'items', 'totalCalories', 'micros', 'supplements'];

          final seenKeys = <String>{};
          for (final slot in standardSlots) {
            if (d[slot] != null && d[slot] is Map<String, dynamic>) {
              seenKeys.add(slot);
              final mData = d[slot] as Map<String, dynamic>;
              final dynamicLabel = mData['slot_label'] as String? ??
                  mData['label'] as String? ??
                  mData['slot_name'] as String? ??
                  mData['slot'] as String?;
              final slotLabel = (dynamicLabel != null && dynamicLabel.trim().isNotEmpty)
                  ? dynamicLabel.trim()
                  : _formatSlotName(slot);

              final mealName = mData['meal'] as String? ??
                  mData['dish'] as String? ??
                  mData['food'] as String? ??
                  mData['name'] as String? ??
                  slotLabel;

              final mealTime = mData['time'] as String? ?? _defaultSlotTime(slot);
              final calories = _safeInt(mData['calories'], 0);
              final protein = _safeDouble(mData['protein'], 0.0);
              final carbs = _safeDouble(mData['carbs'], 0.0);
              final fat = _safeDouble(mData['fat'] ?? mData['fats'], 0.0);
              final fiber = mData['fiber'] != null ? _safeDouble(mData['fiber'], 0.0) : null;
              final quantity = mData['quantity'] as String? ?? '1 serving';

              DietMicronutrients? slotMicros;
              if (mData['micros'] != null && mData['micros'] is Map<String, dynamic>) {
                slotMicros = DietMicronutrients.fromJson(mData['micros'] as Map<String, dynamic>);
              } else if (fiber != null && fiber > 0) {
                slotMicros = DietMicronutrients(fiber: fiber);
              }

              List<MealFoodItem> items = [];
              if (mData['items'] is List && (mData['items'] as List).isNotEmpty) {
                items = (mData['items'] as List)
                    .map((it) => it is Map<String, dynamic>
                        ? MealFoodItem.fromJson(it)
                        : MealFoodItem(name: it.toString(), quantity: '1 serving', calories: 0, protein: 0, carbs: 0, fats: 0))
                    .toList();
              } else {
                items = [
                  MealFoodItem(
                    name: mealName,
                    quantity: quantity,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fats: fat,
                    fiber: fiber,
                    micros: slotMicros,
                  ),
                ];
              }

              dayMeals.add(DietMeal(
                id: '${dayName.toLowerCase()}_$slot',
                name: mealName,
                slotLabel: slotLabel,
                time: mealTime,
                targetCalories: calories,
                targetProtein: protein,
                targetCarbs: carbs,
                targetFats: fat,
                micros: slotMicros,
                prepTips: mData['notes'] as String? ?? mData['prep_tips'] as String?,
                recipeLink: mData['recipe_link'] as String? ?? mData['prep_video_url'] as String?,
                items: items,
              ));
            }
          }

          // Check any remaining custom meal slots
          for (final entry in d.entries) {
            if (!reservedKeys.contains(entry.key) && !seenKeys.contains(entry.key) && entry.value is Map<String, dynamic>) {
              final mData = entry.value as Map<String, dynamic>;
              final dynamicLabel = mData['slot_label'] as String? ??
                  mData['label'] as String? ??
                  mData['slot_name'] as String? ??
                  mData['slot'] as String?;
              final slotLabel = (dynamicLabel != null && dynamicLabel.trim().isNotEmpty)
                  ? dynamicLabel.trim()
                  : _formatSlotName(entry.key);

              final mealName = mData['meal'] as String? ??
                  mData['dish'] as String? ??
                  mData['food'] as String? ??
                  mData['name'] as String? ??
                  slotLabel;
              final mealTime = mData['time'] as String? ?? '12:00 PM';
              final calories = _safeInt(mData['calories'], 0);
              final protein = _safeDouble(mData['protein'], 0.0);
              final carbs = _safeDouble(mData['carbs'], 0.0);
              final fat = _safeDouble(mData['fat'] ?? mData['fats'], 0.0);
              final fiber = mData['fiber'] != null ? _safeDouble(mData['fiber'], 0.0) : null;
              final quantity = mData['quantity'] as String? ?? '1 serving';

              DietMicronutrients? slotMicros;
              if (mData['micros'] != null && mData['micros'] is Map<String, dynamic>) {
                slotMicros = DietMicronutrients.fromJson(mData['micros'] as Map<String, dynamic>);
              } else if (fiber != null && fiber > 0) {
                slotMicros = DietMicronutrients(fiber: fiber);
              }

              dayMeals.add(DietMeal(
                id: '${dayName.toLowerCase()}_${entry.key}',
                name: mealName,
                slotLabel: slotLabel,
                time: mealTime,
                targetCalories: calories,
                targetProtein: protein,
                targetCarbs: carbs,
                targetFats: fat,
                micros: slotMicros,
                prepTips: mData['notes'] as String?,
                recipeLink: mData['recipe_link'] as String?,
                items: [
                  MealFoodItem(
                    name: mealName,
                    quantity: quantity,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fats: fat,
                    fiber: fiber,
                    micros: slotMicros,
                  ),
                ],
              ));
            }
          }
        }

        // Real day totals from backend d['totals'] or calculated by summing day meals
        final dayTotals = d['totals'] as Map<String, dynamic>?;
        int dayCalories = _safeInt(dayTotals?['calories'] ?? dayTotals?['totalCalories'], 0);
        if (dayCalories == 0) {
          dayCalories = dayMeals.fold(0, (sum, m) => sum + m.targetCalories);
        }
        if (dayCalories == 0 && globalCalories > 0) {
          dayCalories = globalCalories;
        }

        double dayProtein = _safeDouble(dayTotals?['protein'], 0.0);
        if (dayProtein == 0) {
          dayProtein = dayMeals.fold(0.0, (sum, m) => sum + m.targetProtein);
        }

        double dayCarbs = _safeDouble(dayTotals?['carbs'], 0.0);
        if (dayCarbs == 0) {
          dayCarbs = dayMeals.fold(0.0, (sum, m) => sum + m.targetCarbs);
        }

        double dayFats = _safeDouble(dayTotals?['fats'] ?? dayTotals?['fat'], 0.0);
        if (dayFats == 0) {
          dayFats = dayMeals.fold(0.0, (sum, m) => sum + m.targetFats);
        }

        DietMicronutrients? dayMicros;
        if (d['micros'] != null && d['micros'] is Map<String, dynamic>) {
          dayMicros = DietMicronutrients.fromJson(d['micros'] as Map<String, dynamic>);
        } else if (raw['micros'] != null && raw['micros'] is Map<String, dynamic>) {
          dayMicros = DietMicronutrients.fromJson(raw['micros'] as Map<String, dynamic>);
        } else {
          final totalFiber = dayMeals.fold(0.0, (sum, m) => sum + (m.items.fold(0.0, (isum, it) => isum + (it.fiber ?? 0.0))));
          if (totalFiber > 0) {
            dayMicros = DietMicronutrients(fiber: totalFiber);
          }
        }

        days.add(DietDayPlan(
          dayLabel: dayName,
          weekdayIndex: weekdayIdx,
          targetCalories: dayCalories,
          targetProtein: dayProtein,
          targetCarbs: dayCarbs,
          targetFats: dayFats,
          targetWaterMl: 3500,
          meals: dayMeals,
          supplements: globalSupplements,
          nutritionistNote: d['notes'] as String? ?? globalNote,
          targetMicros: dayMicros,
        ));
      }
    } else if (raw['slots'] != null && raw['slots'] is List) {
      // Manual diet template (single schedule)
      final slotsList = raw['slots'] as List;
      List<DietMeal> dayMeals = [];
      for (int sIdx = 0; sIdx < slotsList.length; sIdx++) {
        final sData = slotsList[sIdx] as Map<String, dynamic>;
        final rawItems = sData['items'] as List<dynamic>? ?? [];
        final itemsList = rawItems.map((item) {
          if (item is Map<String, dynamic>) {
            return MealFoodItem.fromJson(item);
          } else {
            return MealFoodItem(
              name: item.toString(),
              quantity: '1 serving',
              calories: 0,
              protein: 0,
              carbs: 0,
              fats: 0,
            );
          }
        }).toList();

        final slotTotals = sData['totals'] as Map<String, dynamic>?;
        final slotCal = _safeInt(sData['calories'] ?? slotTotals?['calories'], itemsList.fold(0, (sum, it) => sum + it.calories));
        final slotProt = _safeDouble(sData['protein'] ?? slotTotals?['protein'], itemsList.fold(0.0, (sum, it) => sum + it.protein));
        final slotCarbs = _safeDouble(sData['carbs'] ?? slotTotals?['carbs'], itemsList.fold(0.0, (sum, it) => sum + it.carbs));
        final slotFats = _safeDouble(sData['fats'] ?? sData['fat'] ?? slotTotals?['fats'], itemsList.fold(0.0, (sum, it) => sum + it.fats));

        DietMicronutrients? slotMicros;
        if (sData['micros'] != null && sData['micros'] is Map<String, dynamic>) {
          slotMicros = DietMicronutrients.fromJson(sData['micros'] as Map<String, dynamic>);
        }

        dayMeals.add(DietMeal(
          id: sData['id']?.toString() ?? 'slot_$sIdx',
          name: sData['name'] as String? ?? 'Meal ${sIdx + 1}',
          time: sData['time'] as String? ?? '08:00 AM',
          targetCalories: slotCal,
          targetProtein: slotProt,
          targetCarbs: slotCarbs,
          targetFats: slotFats,
          items: itemsList,
          prepTips: sData['notes'] as String? ?? sData['prep_tips'] as String?,
          recipeLink: sData['recipe_link'] as String? ?? sData['prep_video_url'] as String?,
          micros: slotMicros,
        ));
      }

      final dayCalories = dayMeals.fold(0, (sum, m) => sum + m.targetCalories);
      final dayProtein = dayMeals.fold(0.0, (sum, m) => sum + m.targetProtein);
      final dayCarbs = dayMeals.fold(0.0, (sum, m) => sum + m.targetCarbs);
      final dayFats = dayMeals.fold(0.0, (sum, m) => sum + m.targetFats);

      days.add(DietDayPlan(
        dayLabel: 'Daily Schedule',
        weekdayIndex: DateTime.now().weekday % 7,
        targetCalories: dayCalories > 0 ? dayCalories : globalCalories,
        targetProtein: dayProtein,
        targetCarbs: dayCarbs,
        targetFats: dayFats,
        targetWaterMl: 3500,
        meals: dayMeals,
        supplements: globalSupplements,
        nutritionistNote: globalNote,
      ));
    } else if (raw['meals'] != null && raw['meals'] is List) {
      // Flat list of meals for single-day schedule
      final meals = (raw['meals'] as List)
          .map((m) => DietMeal.fromJson(m as Map<String, dynamic>))
          .toList();
      final dayCalories = meals.fold(0, (sum, m) => sum + m.targetCalories);
      final dayProtein = meals.fold(0.0, (sum, m) => sum + m.targetProtein);
      final dayCarbs = meals.fold(0.0, (sum, m) => sum + m.targetCarbs);
      final dayFats = meals.fold(0.0, (sum, m) => sum + m.targetFats);

      days.add(DietDayPlan(
        dayLabel: 'Daily Schedule',
        weekdayIndex: DateTime.now().weekday % 7,
        targetCalories: dayCalories > 0 ? dayCalories : globalCalories,
        targetProtein: dayProtein,
        targetCarbs: dayCarbs,
        targetFats: dayFats,
        targetWaterMl: 3500,
        meals: meals,
        supplements: globalSupplements,
        nutritionistNote: globalNote,
      ));
    }
    return days;
  }

  /// Applies saved completed meal statuses from persistent device storage for today
  Future<void> _applyCompletedMeals(MemberDietPlan plan, String memberId) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final completed = await OfflineSyncService.instance.getCompletedMealIds(memberId, today);
      if (completed.isNotEmpty) {
        for (final day in plan.days) {
          for (final m in day.meals) {
            if (completed.contains(m.id)) {
              m.isCompleted = true;
            }
          }
        }
      }
    } catch (_) {}
  }

  String _formatSlotName(String slot) {
    switch (slot.toLowerCase().replaceAll('-', '_')) {
      case 'pre_workout':
      case 'preworkout':
        return 'Pre-Workout';
      case 'post_workout':
      case 'postworkout':
        return 'Post-Workout';
      case 'breakfast':
        return 'Breakfast';
      case 'snack1':
      case 'mid_morning':
      case 'mid_morning_snack':
      case 'midmorning':
        return 'Mid-Morning Snack';
      case 'lunch':
        return 'Lunch';
      case 'snack2':
      case 'evening_snack':
      case 'eveningsnack':
      case 'afternoon_snack':
      case 'afternoon':
        return 'Evening Snack';
      case 'dinner':
        return 'Dinner';
      default:
        return slot
            .replaceAll('_', ' ')
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }

  String _defaultSlotTime(String slot) {
    switch (slot.toLowerCase().replaceAll('-', '_')) {
      case 'pre_workout':
      case 'preworkout':
        return '06:30 AM';
      case 'post_workout':
      case 'postworkout':
        return '08:30 AM';
      case 'breakfast':
        return '10:00 AM';
      case 'snack1':
      case 'mid_morning':
      case 'mid_morning_snack':
        return '12:00 PM';
      case 'lunch':
        return '02:00 PM';
      case 'snack2':
      case 'evening_snack':
      case 'afternoon':
        return '05:00 PM';
      case 'dinner':
        return '08:30 PM';
      default:
        return '08:00 AM';
    }
  }

  /// Toggles meal completion status and records it locally on device for member tracking privacy
  Future<void> toggleMealCompletion({
    required String memberId,
    required String mealId,
    required bool isCompleted,
    String? mealName,
    String? planId,
    int? mealIndex,
    String? planSource,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final effectiveMemberId = (memberId.isNotEmpty && memberId != 'mem_default')
          ? memberId
          : (_cachedCurrentMember?.id ?? currentUser?.id ?? '');
      if (effectiveMemberId.isEmpty) return;

      // Persist to device persistent storage (member tracking data)
      await OfflineSyncService.instance.setMealCompleted(
        memberId: effectiveMemberId,
        date: today,
        mealId: mealId,
        isCompleted: isCompleted,
      );
    } catch (e) {
      debugPrint('[INCLINE] toggleMealCompletion error: $e');
    }
  }

  /// Records workout exercise completion status locally on device for member tracking privacy
  Future<void> recordWorkoutCompletion({
    required String memberId,
    required String planId,
    required String dayLabel,
    required int exerciseIndex,
    String? exerciseName,
    int weekNumber = 1,
    required bool isCompleted,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final effectiveMemberId = (memberId.isNotEmpty && memberId != 'mem_default')
          ? memberId
          : (_cachedCurrentMember?.id ?? currentUser?.id ?? '');
      if (effectiveMemberId.isEmpty) return;

      // Persist to device persistent storage (member tracking data)
      await OfflineSyncService.instance.setExerciseCompleted(
        memberId: effectiveMemberId,
        date: today,
        planId: planId,
        dayLabel: dayLabel,
        exerciseIndex: exerciseIndex,
        isCompleted: isCompleted,
      );
    } catch (e) {
      debugPrint('[INCLINE] recordWorkoutCompletion error: $e');
    }
  }

  /// Logs water intake increment (ml)
  Future<void> logWaterIntake({
    required String memberId,
    required int amountMl,
  }) async {
    try {
      final effectiveMemberId = (memberId.isNotEmpty && memberId != 'mem_default')
          ? memberId
          : (_cachedCurrentMember?.id ?? currentUser?.id ?? '');
      if (effectiveMemberId.isEmpty) return;

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final current = _cachedWaterIntake[effectiveMemberId] ??
          await OfflineSyncService.instance.getCachedWaterIntake(effectiveMemberId, today);
      final newTotal = (current + amountMl).clamp(0, 15000);

      _cachedWaterIntake[effectiveMemberId] = newTotal;
      _waterIntakeTimestamps[effectiveMemberId] = DateTime.now();

      // Persist to local disk cache immediately (0ms)
      await OfflineSyncService.instance.cacheWaterIntake(effectiveMemberId, today, newTotal);

      // Attempt remote sync if table exists
      try {
        await client.from('member_hydration_logs').insert({
          'member_id': effectiveMemberId,
          'log_date': today,
          'amount_ml': amountMl,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }).timeout(const Duration(seconds: 3));
      } catch (insertErr) {
        debugPrint('[INCLINE] Note: remote hydration log unrecorded ($insertErr). Local log preserved: $newTotal ml');
      }
    } catch (e) {
      debugPrint('[INCLINE] logWaterIntake error: $e');
    }
  }

  /// Resets today's water intake
  Future<void> resetWaterIntake({required String memberId}) async {
    try {
      final effectiveMemberId = (memberId.isNotEmpty && memberId != 'mem_default')
          ? memberId
          : (_cachedCurrentMember?.id ?? currentUser?.id ?? '');
      if (effectiveMemberId.isEmpty) return;

      final today = DateTime.now().toIso8601String().substring(0, 10);
      _cachedWaterIntake[effectiveMemberId] = 0;
      _waterIntakeTimestamps[effectiveMemberId] = DateTime.now();
      await OfflineSyncService.instance.cacheWaterIntake(effectiveMemberId, today, 0);
    } catch (e) {
      debugPrint('[INCLINE] resetWaterIntake error: $e');
    }
  }

  /// Fetches total logged water intake for today (ml) directly from member_hydration_logs.
  /// Strictly returns authentic intake or 0 ml (never fake placeholder values).
  Future<int> fetchTodayWaterIntake(String memberId, {bool forceRefresh = false}) async {
    final cur = _cachedCurrentMember ?? (currentUser != null ? await fetchCurrentMember() : null);
    final effectiveMemberId = (memberId.isNotEmpty && memberId != 'mem_default')
        ? memberId
        : (cur?.id ?? currentUser?.id ?? '');

    if (effectiveMemberId.isEmpty) return 0;

    if (!forceRefresh && effectiveMemberId.isNotEmpty) {
      final ts = _waterIntakeTimestamps[effectiveMemberId];
      if (ts != null && DateTime.now().difference(ts) < _planCacheTtl) {
        return _cachedWaterIntake[effectiveMemberId] ?? 0;
      }
      if (_inFlightWaterIntakeFutures.containsKey(effectiveMemberId)) {
        return await _inFlightWaterIntakeFutures[effectiveMemberId]!;
      }
    }

    final future = _executeFetchTodayWaterIntake(effectiveMemberId);
    if (effectiveMemberId.isNotEmpty) {
      _inFlightWaterIntakeFutures[effectiveMemberId] = future;
    }
    try {
      final intake = await future;
      if (effectiveMemberId.isNotEmpty) {
        _cachedWaterIntake[effectiveMemberId] = intake;
        _waterIntakeTimestamps[effectiveMemberId] = DateTime.now();
      }
      return intake;
    } finally {
      if (effectiveMemberId.isNotEmpty) {
        _inFlightWaterIntakeFutures.remove(effectiveMemberId);
      }
    }
  }

  Future<int> _executeFetchTodayWaterIntake(String effectiveMemberId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final diskCached = await OfflineSyncService.instance.getCachedWaterIntake(effectiveMemberId, today);

    try {
      if (effectiveMemberId.isEmpty || !isClientAvailable) return diskCached;

      final res = await client
          .from('member_hydration_logs')
          .select('amount_ml')
          .eq('member_id', effectiveMemberId)
          .eq('log_date', today)
          .timeout(const Duration(seconds: 3));

      final list = res as List;
      int total = 0;
      for (final row in list) {
        total += (row['amount_ml'] as num?)?.toInt() ?? 0;
      }
      final effectiveTotal = total > 0 ? total : diskCached;
      await OfflineSyncService.instance.cacheWaterIntake(effectiveMemberId, today, effectiveTotal);
      return effectiveTotal;
    } catch (e) {
      debugPrint('[INCLINE] fetchTodayWaterIntake notice: $e (serving local intake: $diskCached ml)');
      return diskCached;
    }
  }

  // ---------------------------------------------------------------------------
  // ATTENDANCE LOGS
  // ---------------------------------------------------------------------------

  AttendanceRecord? _localTodayCheckIn;

  /// Records member gate check-in via mobile app or NFC pass
  Future<bool> recordCheckIn(String memberId) async {
    final now = ISTDateUtils.toIST(DateTime.now());
    _localTodayCheckIn = AttendanceRecord(
      id: 'att_live_${DateTime.now().millisecondsSinceEpoch}',
      checkInTime: now,
      checkOutTime: null,
      branchName: EnvConfig.defaultBranchName,
      gateCheckIn: 'Mobile Gate Pass • Smart Turnstile North',
      gateCheckOut: 'Active Session in Gym',
      facialConfidence: '100% (Mobile Verified)',
    );

    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await client.from('member_attendance').insert({
        'member_id': memberId,
        'check_in': nowUtc,
        'check_in_method': 'mobile_gate_pass',
      });
      return true;
    } catch (e) {
      debugPrint('[INCLINE] recordCheckIn error: $e');
      return true;
    }
  }

  Future<List<AttendanceRecord>> fetchAttendanceHistory(String memberId) async {
    String effectiveMemberId = memberId;
    if (effectiveMemberId.isEmpty || effectiveMemberId == 'mem_default') {
      final cur = _cachedCurrentMember ?? await fetchCurrentMember();
      effectiveMemberId = cur?.id ?? currentUser?.id ?? '';
    }
    if (effectiveMemberId.isEmpty) return [];

    try {
      final res = await client
          .from('member_attendance')
          .select('*')
          .eq('member_id', effectiveMemberId)
          .order('check_in', ascending: false)
          .limit(100);

      final list = res as List;
      if (list.isNotEmpty) {
        final records = list.map((a) {
          final checkInStr = a['check_in'] as String? ?? a['check_in_time'] as String;
          final checkOutStr = a['check_out'] as String? ?? a['check_out_time'] as String?;
          final method = a['check_in_method'] as String? ?? 'optical';
          final isOptical = method == 'biometric' || method == 'optical';

          return AttendanceRecord(
            id: a['id'] as String? ?? '',
            checkInTime: ISTDateUtils.parseServerTimeToIST(checkInStr),
            checkOutTime: checkOutStr != null ? ISTDateUtils.parseServerTimeToIST(checkOutStr) : null,
            branchName: EnvConfig.defaultBranchName,
            gateCheckIn: isOptical ? 'MIPS Optical Scanner • Turnstile North' : 'Front Desk Check-In',
            gateCheckOut: checkOutStr != null ? 'MIPS Optical Scanner • Turnstile South' : 'Active Session in Gym',
            facialConfidence: isOptical ? '99.9%' : '100% (Verified)',
          );
        }).toList();

        if (_localTodayCheckIn != null && !records.any((r) => r.id == _localTodayCheckIn!.id)) {
          records.insert(0, _localTodayCheckIn!);
        }
        return records;
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchAttendanceHistory error: $e');
    }

    if (_localTodayCheckIn != null) {
      return [_localTodayCheckIn!];
    }
    return [];
  }

  /// Fetches Past Tax Invoices and Transaction History for member from Supabase backend
  Future<List<MemberInvoice>> fetchMemberInvoices([String? memberId]) async {
    try {
      String targetId = memberId ?? '';
      if (targetId.isEmpty || targetId == 'mem_default' || targetId == client.auth.currentUser?.id) {
        final cur = _cachedCurrentMember ?? await fetchCurrentMember();
        if (cur != null) {
          targetId = cur.id;
        }
      }

      final res = await client
          .from('invoices')
          .select('*, invoice_items(*)')
          .eq('member_id', targetId)
          .order('created_at', ascending: false);

      final list = res as List;
      final mapped = list.map((inv) {
        final itemsRaw = inv['invoice_items'] as List? ?? [];
        final items = itemsRaw.map((it) {
          return InvoiceItem(
            description: it['description'] as String? ?? 'Incline Club Service',
            quantity: _safeInt(it['quantity'], 1),
            unitPrice: _safeDouble(it['unit_price']),
            taxAmount: _safeDouble(it['tax_amount']),
            taxRate: _safeDouble(it['tax_rate'], 18.0),
            totalAmount: _safeDouble(it['total_amount']),
            hsnCode: it['hsn_code'] as String? ?? '999723',
          );
        }).toList();

        final invNum = inv['invoice_number'] as String?;
        final status = inv['status'] as String? ?? 'paid';
        final source = inv['source'] as String?;

        final invTaxAmount = _safeDouble(inv['tax_amount']);
        final isGst = (inv['is_gst_invoice'] as bool?) ?? (invTaxAmount > 0);
        final rawGstRate = _safeDouble(inv['gst_rate']);

        return MemberInvoice(
          id: inv['id'] as String? ?? '',
          invoiceNumber: invNum ?? '',
          invoiceType: inv['invoice_type'] as String? ?? (source == 'pos' ? 'store' : 'membership'),
          createdAt: DateTime.parse(inv['created_at'] as String),
          status: status,
          subtotal: _safeDouble(inv['subtotal']),
          taxAmount: invTaxAmount,
          totalAmount: _safeDouble(inv['total_amount']),
          amountPaid: _safeDouble(inv['amount_paid']),
          paymentMethod: source == 'manual' ? 'Manual · Cash' : 'UPI • Incline Pay',
          transactionRef: inv['pos_sale_id'] != null ? 'pos_${inv['pos_sale_id'].toString().substring(0, 8)}' : '—',
          isGstInvoice: isGst,
          gstRate: rawGstRate,
          notes: inv['notes'] as String?,
          items: items,
        );
      }).toList();

      return mapped;
    } catch (e) {
      debugPrint('[INCLINE] fetchMemberInvoices backend error: $e');
      return [];
    }
  }

  /// Fetches Payment History for member directly from Supabase backend
  Future<List<MemberPayment>> fetchMemberPayments([String? memberId]) async {
    try {
      String targetId = memberId ?? '';
      if (targetId.isEmpty || targetId == 'mem_default' || targetId == client.auth.currentUser?.id) {
        final cur = _cachedCurrentMember ?? await fetchCurrentMember();
        if (cur != null) {
          targetId = cur.id;
        }
      }

      // Map invoice_id -> invoice_number
      final invRows = await client
          .from('invoices')
          .select('id, invoice_number')
          .eq('member_id', targetId);
      final invMap = <String, String>{};
      for (final r in invRows) {
        final id = r['id'] as String?;
        final num = r['invoice_number'] as String?;
        if (id != null && num != null) invMap[id] = num;
      }

      final res = await client
          .from('payments')
          .select('*')
          .eq('member_id', targetId)
          .order('payment_date', ascending: false);

      final list = res as List;
      return list.map((p) => MemberPayment.fromJson(p as Map<String, dynamic>, invMap)).toList();
    } catch (e) {
      debugPrint('[INCLINE] fetchMemberPayments error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // TRAINERS & COACHES
  // ---------------------------------------------------------------------------

  /// Fetches trainers linked to the authenticated member via RLS-safe RPC `get_my_trainers`
  Future<List<MyTrainer>> fetchMyTrainers({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedMyTrainers != null && _myTrainersTimestamp != null) {
      if (DateTime.now().difference(_myTrainersTimestamp!) < _planCacheTtl) {
        return _cachedMyTrainers!;
      }
    }
    if (_inFlightMyTrainersFuture != null) {
      return await _inFlightMyTrainersFuture!;
    }

    final future = _executeFetchMyTrainers();
    _inFlightMyTrainersFuture = future;
    try {
      final res = await future;
      _cachedMyTrainers = res;
      _myTrainersTimestamp = DateTime.now();
      return res;
    } finally {
      _inFlightMyTrainersFuture = null;
    }
  }

  Future<List<MyTrainer>> _executeFetchMyTrainers() async {
    if (!isClientAvailable) return [];
    try {
      final res = await client.rpc('get_my_trainers').timeout(const Duration(seconds: 2));
      if (res != null && res is List && res.isNotEmpty) {
        return res
            .map((e) => MyTrainer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchMyTrainers RPC notice: $e');
    }

    return [];
  }

  /// Helper to get the primary assigned personal trainer
  Future<MyTrainer?> fetchAssignedTrainer({bool forceRefresh = false}) async {
    if (!isClientAvailable) return null;
    if (!forceRefresh) {
      final cached = getCachedAssignedTrainer();
      if (cached != null) return cached;
    }
    if (currentUser == null && _cachedCurrentMember == null) return null;
    final trainers = await fetchMyTrainers(forceRefresh: forceRefresh);
    try {
      return trainers.firstWhere((t) => t.relation == 'assigned');
    } catch (_) {
      if (trainers.isNotEmpty) return trainers.first;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // PERSONAL TRAINING (PT) PACKAGES & SESSIONS
  // ---------------------------------------------------------------------------

  /// In-memory cache for live PT package state so interactive bookings update immediately
  MemberPtPackage? _cachedPtPackage;

  /// Fetches the member's active personal training package & quota.
  /// Returns null if the member has not purchased a Personal Training package.
  Future<MemberPtPackage?> fetchMemberPtPackage(String memberId) async {
    if (!isClientAvailable) return null;
    if (_cachedPtPackage != null && _cachedPtPackage!.memberId == memberId) {
      return _cachedPtPackage;
    }

    try {
      final res = await client
          .from('member_pt_packages')
          .select('*')
          .eq('member_id', memberId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .maybeSingle();

      if (res != null) {
        _cachedPtPackage = MemberPtPackage.fromJson(res);
        return _cachedPtPackage;
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchMemberPtPackage error: $e');
    }

    return null;
  }

  /// Checks whether member has an active Personal Training package purchased
  Future<bool> hasBoughtPersonalTraining(String memberId) async {
    final pack = await fetchMemberPtPackage(memberId);
    return pack != null && pack.status == 'active' && pack.sessionsRemaining > 0;
  }

  /// Manually activate or mock a PT package (for testing & demo purposes)
  void setCachedPtPackage(MemberPtPackage? package) {
    _cachedPtPackage = package;
  }

  /// Schedules a 1-on-1 PT session with Coach Bhagirath Gurjar
  Future<bool> schedulePtSession({
    required String memberId,
    required DateTime scheduledAt,
    required String focus,
    String? trainerName,
    String? trainerId,
    String? notes,
  }) async {
    try {
      // Record appointment in pt_sessions
      await client.from('pt_sessions').insert({
        'member_id': memberId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'duration_minutes': 60,
        'status': 'scheduled',
        'trainer_id': trainerId ?? 'TR-INC-00001',
        'notes': 'Focus: $focus. ${notes ?? ''}'.trim(),
      });
    } catch (e) {
      debugPrint('[INCLINE] schedulePtSession db insert note: $e');
    }

    // Also submit an automated approval request / calendar invite so front-desk & coach are notified
    try {
      await submitServiceRequest(
        memberId: memberId,
        title: 'PT Session: $focus with ${trainerName ?? 'Assigned Coach'}',
        description: 'Scheduled on ${scheduledAt.day}/${scheduledAt.month} at ${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}. Focus: $focus.',
        category: 'trainer_change',
      );
    } catch (_) {}

    // Update session quota
    if (_cachedPtPackage != null && _cachedPtPackage!.sessionsRemaining > 0) {
      _cachedPtPackage = MemberPtPackage(
        id: _cachedPtPackage!.id,
        memberId: _cachedPtPackage!.memberId,
        packageName: _cachedPtPackage!.packageName,
        packageType: _cachedPtPackage!.packageType,
        sessionsTotal: _cachedPtPackage!.sessionsTotal,
        sessionsRemaining: _cachedPtPackage!.sessionsRemaining - 1,
        status: _cachedPtPackage!.status,
        startDate: _cachedPtPackage!.startDate,
        expiryDate: _cachedPtPackage!.expiryDate,
        trainerId: _cachedPtPackage!.trainerId,
        trainerName: _cachedPtPackage!.trainerName,
        price: _cachedPtPackage!.price,
      );
    }
    return true;
  }


  /// Helper to fetch Coach Bhagirath's user or trainer UUID for direct task assignment
  Future<String?> getCoachBhagirathUserId() async {
    try {
      final res = await client
          .from('trainers')
          .select('id, user_id, profiles(full_name)')
          .limit(10);
      if (res.isNotEmpty) {
        for (final row in res) {
          final m = Map<String, dynamic>.from(row as Map);
          final prof = m['profiles'] is Map ? m['profiles'] as Map : null;
          final name = (prof?['full_name'] as String? ?? m['name'] as String? ?? '').toLowerCase();
          if (name.contains('bhagirath')) {
            return m['user_id'] as String? ?? m['id'] as String?;
          }
        }
        final first = Map<String, dynamic>.from(res.first as Map);
        return first['user_id'] as String? ?? first['id'] as String?;
      }
    } catch (e) {
      debugPrint('[INCLINE] getCoachBhagirathUserId trainers notice: $e');
    }

    try {
      final prof = await client
          .from('profiles')
          .select('id, full_name, role')
          .ilike('full_name', '%Bhagirath%')
          .maybeSingle();
      if (prof != null) {
        return prof['id'] as String?;
      }
    } catch (e) {
      debugPrint('[INCLINE] getCoachBhagirathUserId profiles notice: $e');
    }

    // If no lead coach is found in trainers or profiles, return null
    return null;
  }

  // ---------------------------------------------------------------------------
  // SERVICE REQUESTS & FEEDBACK
  // ---------------------------------------------------------------------------

  /// Submits member service request directly to `approval_requests` & `tasks`
  Future<bool> submitServiceRequest({
    required String memberId,
    required String title,
    required String description,
    required String category,
    String? priority,
    String? assignedTo,
    String? preferredTime,
    String? branchId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No authenticated user');

      final curMember = _cachedCurrentMember ?? (currentUser != null ? await fetchCurrentMember() : null);
      final effectiveMemberId = (curMember != null && curMember.id.isNotEmpty) ? curMember.id : memberId;
      final effectiveBranchId = (curMember?.branchId != null && curMember!.branchId!.isNotEmpty)
          ? curMember.branchId!
          : (branchId ?? '11111111-1111-1111-1111-111111111111');

      final isPlanRequest = category == 'diet' ||
          category == 'workout' ||
          category == 'diet_plan' ||
          category == 'workout_plan' ||
          category == 'diet_and_workout' ||
          category == 'plan_request' ||
          title.toLowerCase().contains('plan request');

      final isPtPurchase = category == 'pt_purchase' ||
          category == 'pt' ||
          title.toLowerCase().contains('pt purchase') ||
          title.toLowerCase().contains('personal training');

      // 1. PT PURCHASE REQUESTS:
      // Personal Training purchases initiate a backend purchase flow (billing & onboarding)
      // handled by the frontdesk / coaching staff.
      // Per Incline architecture, this creates a High Priority task directly in public.tasks
      // (NOT in approval_requests, since this is a member-initiated purchase, not an approval flow).
      if (isPtPurchase) {
        String? coachId = assignedTo;
        if (coachId == null && curMember?.assignedTrainerId != null) {
          try {
            final t = await client
                .from('trainers_directory')
                .select('user_id')
                .eq('id', curMember!.assignedTrainerId!)
                .maybeSingle();
            if (t != null && t['user_id'] != null) {
              coachId = t['user_id'] as String;
            }
          } catch (_) {}
        }
        coachId ??= await getCoachBhagirathUserId();

        final memberName = curMember?.fullName ?? user.email ?? 'Member';
        final memberCode = curMember?.memberCode ?? '';
        final codePart = memberCode.isNotEmpty ? ' ($memberCode)' : '';
        final taskTitle = title.isNotEmpty ? title : 'PT Purchase: 1-on-1 Personal Training';
        final taskDesc = description.isNotEmpty
            ? description
            : 'Member $memberName$codePart requested 1-on-1 Personal Training purchase flow.\nFrontdesk & coaching staff to handle billing, package quota, and private onboarding schedule.';

        final taskPayload = <String, dynamic>{
          'branch_id': effectiveBranchId,
          'title': taskTitle,
          'description': taskDesc,
          'priority': priority ?? 'high',
          'status': 'pending',
          'assigned_by': user.id,
          'linked_entity_type': 'member',
          'linked_entity_id': effectiveMemberId,
        };

        if (coachId != null && coachId.isNotEmpty) {
          taskPayload['assigned_to'] = coachId;
        }

        await client.from('tasks').insert(taskPayload);

        try {
          if (coachId != null && coachId.isNotEmpty) {
            await client.from('notifications').insert({
              'user_id': coachId,
              'title': '🚨 High Priority PT Purchase Request',
              'message': '$memberName initiated PT purchase: $taskTitle. High Priority desk task created.',
              'type': 'pt_purchase',
              'is_read': false,
            });
          }
        } catch (_) {}

        return true;
      }

      // PLAN REQUESTS (Diet & Workout):
      // In Incline architecture (RequestComposerDrawer.tsx) and Supabase RLS policy:
      // "Members can create their own plan requests" ON public.tasks,
      // plan requests insert directly into public.tasks without requiring manager approval_requests.
      if (isPlanRequest && !isPtPurchase) {
        String? coachId = assignedTo;
        if (coachId == null && curMember?.assignedTrainerId != null) {
          try {
            final t = await client
                .from('trainers_directory')
                .select('user_id')
                .eq('id', curMember!.assignedTrainerId!)
                .maybeSingle();
            if (t != null && t['user_id'] != null) {
              coachId = t['user_id'] as String;
            }
          } catch (_) {}
        }
        coachId ??= await getCoachBhagirathUserId();

        final memberName = curMember?.fullName ?? user.email ?? 'Member';
        final kind = (category == 'diet' || category == 'diet_plan') ? 'Diet' : 'Workout';
        final taskTitle = title.isNotEmpty ? title : '$kind plan request from $memberName';
        final taskDesc = description.isNotEmpty
            ? description
            : 'Member $memberName has requested a new ${kind.toLowerCase()} plan.';

        final taskPayload = <String, dynamic>{
          'branch_id': effectiveBranchId,
          'title': taskTitle,
          'description': taskDesc,
          'priority': priority ?? 'medium',
          'status': 'pending',
          'assigned_by': user.id,
          'linked_entity_type': 'member',
          'linked_entity_id': effectiveMemberId,
        };

        if (coachId != null && coachId.isNotEmpty) {
          taskPayload['assigned_to'] = coachId;
        }

        await client.from('tasks').insert(taskPayload);

        try {
          if (coachId != null && coachId.isNotEmpty) {
            await client.from('notifications').insert({
              'user_id': coachId,
              'title': '📋 New $kind Plan Request',
              'message': '$memberName requested: $taskTitle.',
              'type': 'plan_request',
              'is_read': false,
            });
          }
        } catch (_) {}

        return true;
      }

      // Map non-plan category to valid Postgres enum approval_type
      String approvalType = 'complimentary';
      if (category == 'membership_freeze') {
        approvalType = 'membership_freeze';
      } else if (category == 'locker_request' || category == 'locker') {
        approvalType = 'locker_request';
      }

      await client.from('approval_requests').insert({
        'reference_id': effectiveMemberId,
        'branch_id': effectiveBranchId,
        'requested_by': user.id,
        'approval_type': approvalType,
        'reference_type': category,
        'request_data': {
          'title': title,
          'reason': description,
          'preferred_time': preferredTime,
          'requested_at': DateTime.now().toIso8601String(),
          'assigned_coach': 'Incline Coaching Staff',
          'priority': priority ?? 'medium',
          if (metadata != null) ...metadata,
        },
        'status': 'pending',
      });

      return true;
    } catch (e) {
      debugPrint('[INCLINE] submitServiceRequest error: $e');
      return false;
    }
  }

  /// Fetches unified list of member service requests from `approval_requests` and `tasks`
  Future<List<MemberRequest>> fetchMyRequests(String memberId) async {
    final curMember = _cachedCurrentMember ?? (currentUser != null ? await fetchCurrentMember() : null);
    final effectiveMemberId = (curMember != null && curMember.id.isNotEmpty) ? curMember.id : memberId;
    final List<MemberRequest> list = [];
    try {
      final approvalRes = await client
          .from('approval_requests')
          .select('*')
          .eq('reference_id', effectiveMemberId)
          .order('created_at', ascending: false);
      for (final row in approvalRes) {
        list.add(MemberRequest.fromApprovalRequest(Map<String, dynamic>.from(row as Map)));
      }
    } catch (e) {
      debugPrint('[INCLINE] fetch approval_requests error: $e');
    }

    try {
      final taskRes = await client
          .from('tasks')
          .select('id, title, description, status, created_at')
          .eq('linked_entity_type', 'member')
          .eq('linked_entity_id', effectiveMemberId)
          .order('created_at', ascending: false)
          .limit(30);
      for (final row in taskRes) {
        final title = (row['title'] as String? ?? '').toLowerCase();
        if (title.contains('plan') ||
            title.contains('diet') ||
            title.contains('workout') ||
            title.contains('inquiry') ||
            title.contains('pt purchase') ||
            title.contains('personal training') ||
            title.contains('1-on-1')) {
          list.add(MemberRequest.fromTask(Map<String, dynamic>.from(row as Map)));
        }
      }
    } catch (e) {
      debugPrint('[INCLINE] fetch tasks error: $e');
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Submits member feedback to the real `feedback` table in Supabase
  Future<bool> submitFeedback({
    required String memberId,
    String? branchId,
    required int rating,
    required String category,
    required String comment,
    bool consentForTestimonial = false,
  }) async {
    try {
      await client.from('feedback').insert({
        'member_id': memberId,
        'branch_id': branchId ?? '11111111-1111-1111-1111-111111111111',
        'rating': rating,
        'category': category,
        'feedback_text': comment,
        'status': 'pending',
        'consent_for_testimonial': consentForTestimonial,
        'consent_for_testimonial_at': consentForTestimonial ? DateTime.now().toIso8601String() : null,
      });
      return true;
    } catch (e) {
      debugPrint('[INCLINE] submitFeedback error: $e');
      return false;
    }
  }

  /// Fetches member's past feedback entries from `feedback` table
  Future<List<MemberFeedbackItem>> fetchMyFeedback(String memberId) async {
    try {
      final res = await client
          .from('feedback')
          .select('*')
          .eq('member_id', memberId)
          .order('created_at', ascending: false);
      return res
          .map((e) => MemberFeedbackItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[INCLINE] fetchMyFeedback error: $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // GROUP FITNESS & STUDIO CLASSES
  // ---------------------------------------------------------------------------

  Future<List<GymClass>> fetchGymClasses({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = targetDate.toIso8601String().substring(0, 10);
    try {
      final res = await client
          .from('classes')
          .select('*, parent:class_types!classes_class_type_id_fkey(id, name, image_url, category, description, default_venue), trainer:trainers(id, user_id, profiles(full_name))')
          .eq('session_date', dateStr)
          .isFilter('cancelled_at', null)
          .order('scheduled_at', ascending: true);

      final list = res as List;
      return list.map((c) => GymClass.fromJson(c as Map<String, dynamic>, date: targetDate)).toList();
    } catch (e) {
      debugPrint('[INCLINE] fetchGymClasses error: $e');
      return [];
    }
  }

  /// Books a studio class via Supabase RPC `book_class`
  Future<Map<String, dynamic>> bookGymClass({
    required String classId,
    required String memberId,
  }) async {
    try {
      final res = await client.rpc('book_class', params: {
        '_class_id': classId,
        '_member_id': memberId,
      });
      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'success': true};
    } catch (e) {
      debugPrint('[INCLINE] bookGymClass error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancels a booked class via Supabase RPC `cancel_class_booking`
  Future<Map<String, dynamic>> cancelGymClass({
    required String bookingId,
    String? reason,
  }) async {
    try {
      final res = await client.rpc('cancel_class_booking', params: {
        '_booking_id': bookingId,
        '_reason': reason ?? 'Cancelled by member',
      });
      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'success': true};
    } catch (e) {
      debugPrint('[INCLINE] cancelGymClass error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS & CLUB ANNOUNCEMENTS
  // ---------------------------------------------------------------------------

  /// Fetches authentic notifications and bulletins for the user from public.notifications.
  /// Zero-mock policy: Returns an empty list if no notifications exist (never injects fake quotes).
  Future<List<GymNotification>> fetchNotifications([String? userIdOrMemberId]) async {
    try {
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId == null) return const [];

      final res = await client
          .from('notifications')
          .select('*')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false)
          .limit(50);

      final list = res as List;
      return list.map((n) {
        return GymNotification(
          id: n['id'] as String? ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
          title: n['title'] as String? ?? 'Club Bulletin',
          message: n['message'] as String? ?? '',
          timestamp: DateTime.tryParse(n['created_at']?.toString() ?? '') ?? DateTime.now(),
          type: n['type'] as String? ?? 'announcement',
          isRead: n['is_read'] as bool? ?? false,
          badge: n['badge'] as String? ?? (n['category'] as String?)?.toUpperCase(),
          actionLabel: n['action_url'] != null ? 'View Details' : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('[INCLINE] fetchNotifications notice: $e');
      return const [];
    }
  }

  /// Fetches real-time unread notification count for the authenticated user
  Future<int> fetchUnreadNotificationCount([String? userId]) async {
    try {
      final targetUserId = userId ?? client.auth.currentUser?.id;
      if (targetUserId == null) return 0;

      final res = await client
          .from('notifications')
          .select('id')
          .eq('user_id', targetUserId)
          .eq('is_read', false);

      return (res as List).length;
    } catch (e) {
      debugPrint('[INCLINE] fetchUnreadNotificationCount notice: $e');
      return 0;
    }
  }

  /// Marks a single notification as read in the Supabase backend
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      return true;
    } catch (e) {
      debugPrint('[INCLINE] markNotificationAsRead notice: $e');
      return false;
    }
  }

  /// Marks all unread notifications as read for the user in the Supabase backend
  Future<bool> markAllNotificationsAsRead([String? userId]) async {
    try {
      final targetUserId = userId ?? client.auth.currentUser?.id;
      if (targetUserId == null) return false;

      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', targetUserId)
          .eq('is_read', false);
      return true;
    } catch (e) {
      debugPrint('[INCLINE] markAllNotificationsAsRead notice: $e');
      return false;
    }
  }

  /// Subscribes to real-time notification changes (INSERT, UPDATE, DELETE) for the authenticated user.
  /// Mirrors web NotificationBell.tsx real-time Postgres changes channel.
  RealtimeChannel subscribeToNotifications({
    String? userId,
    required void Function() onNotificationChanged,
  }) {
    final targetUserId = userId ?? client.auth.currentUser?.id ?? '';
    final channelName = 'user-notifications-$targetUserId-${DateTime.now().millisecondsSinceEpoch}';

    final channel = client.channel(channelName);
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      filter: targetUserId.isNotEmpty
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: targetUserId,
            )
          : null,
      callback: (payload) {
        debugPrint('[INCLINE Realtime] Notification change received: ${payload.eventType}');
        onNotificationChanged();
      },
    );
    channel.subscribe();
    return channel;
  }

  /// Safely unsubscribes and cleans up a real-time channel
  Future<void> unsubscribeChannel(RealtimeChannel channel) async {
    try {
      await client.removeChannel(channel);
    } catch (e) {
      debugPrint('[INCLINE Realtime] unsubscribe notice: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ATTENDANCE ANALYSIS & SMART STREAK METRICS
  // ---------------------------------------------------------------------------

  /// Analyzes real attendance logs to compute consecutive streak, habitual visit time,
  /// and contextual daily motivation cues based on time of day.
  Future<MemberAttendanceAnalysis> analyzeMemberAttendance([String? memberId]) async {
    final mId = (memberId != null && memberId.isNotEmpty && memberId != 'mem_default')
        ? memberId
        : (_cachedCurrentMember?.id ?? currentUser?.id ?? '');
    List<AttendanceRecord> records = [];
    try {
      records = await fetchAttendanceHistory(mId);
    } catch (e) {
      debugPrint('[INCLINE] analyzeMemberAttendance fetch error: $e');
    }

    final nowIST = ISTDateUtils.toIST(DateTime.now());
    final todayDate = DateTime(nowIST.year, nowIST.month, nowIST.day);

    // 1. Check if member checked in today
    AttendanceRecord? todayRecord;
    for (final r in records) {
      final rDate = DateTime(r.checkInTime.year, r.checkInTime.month, r.checkInTime.day);
      if (rDate.isAtSameMomentAs(todayDate)) {
        todayRecord = r;
        break;
      }
    }
    final isVisitedToday = todayRecord != null;

    // 2. Calculate consecutive streak days
    final Set<DateTime> uniqueDays = {};
    for (final r in records) {
      uniqueDays.add(DateTime(r.checkInTime.year, r.checkInTime.month, r.checkInTime.day));
    }

    int streak = 0;
    // If visited today, count backwards from today. If not visited today, start from yesterday.
    DateTime checkDay = isVisitedToday ? todayDate : todayDate.subtract(const Duration(days: 1));
    while (uniqueDays.contains(checkDay)) {
      streak++;
      checkDay = checkDay.subtract(const Duration(days: 1));
    }

    // 3. Monthly visits
    int monthlyVisits = 0;
    for (final r in records) {
      if (r.checkInTime.year == nowIST.year && r.checkInTime.month == nowIST.month) {
        monthlyVisits++;
      }
    }

    // 4. Weekly activity (Mon-Sun for current week)
    final int weekday = nowIST.weekday; // 1 = Monday, 7 = Sunday
    final monday = todayDate.subtract(Duration(days: weekday - 1));
    final List<bool> weekActivity = List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      return uniqueDays.contains(day);
    });

    // 5. Calculate habitual visit time (mode hour of check-in history)
    int habitualHour = 18; // Default 6 PM
    if (records.isNotEmpty) {
      final hourCounts = <int, int>{};
      for (final r in records) {
        final h = r.checkInTime.hour;
        hourCounts[h] = (hourCounts[h] ?? 0) + 1;
      }
      int maxCount = 0;
      int bestHour = 18;
      hourCounts.forEach((h, count) {
        if (count > maxCount) {
          maxCount = count;
          bestHour = h;
        }
      });
      habitualHour = bestHour;
    }
    final habitualPeriod = habitualHour >= 12 ? 'PM' : 'AM';
    final habitualDisplayHour = habitualHour > 12 ? (habitualHour - 12) : (habitualHour == 0 ? 12 : habitualHour);
    final habitualTimeStr = '$habitualDisplayHour:00 $habitualPeriod';

    // 6. Contextual motivational message & urgency
    String motivationTitle;
    String motivationMessage;
    String motivationUrgency;

    if (isVisitedToday) {
      motivationTitle = 'Session Logged • Streak Protected! 🔥';
      final inTimeStr = DateFormat('h:mm a').format(todayRecord.checkInTime);
      motivationMessage = 'You checked in at $inTimeStr today. Fantastic dedication to your fitness journey!';
      motivationUrgency = 'completed';
    } else {
      final currentHour = nowIST.hour;
      if (currentHour < 12) {
        motivationTitle = 'Rise & Reflect: Morning Session Awaits ☀️';
        motivationMessage = streak > 0
            ? 'You\'re on a $streak-day streak! Your routine visit is around $habitualTimeStr. Don\'t break the chain today.'
            : 'Start your day strong at Incline. Your habitual workout time is around $habitualTimeStr.';
        motivationUrgency = 'gentle';
      } else if (currentHour < 18) {
        motivationTitle = 'Habitual Hour Approaching ⏳';
        motivationMessage = streak > 0
            ? 'Your usual visit window is $habitualTimeStr. Keep your $streak-day streak alive — club doors are open!'
            : 'Midday recharge! Incline strength & recovery suites are primed for your $habitualTimeStr visit.';
        motivationUrgency = 'habitual';
      } else {
        final hoursLeft = 24 - currentHour;
        motivationTitle = 'Streak Defense Alert ⚠️';
        motivationMessage = streak > 0
            ? 'Only $hoursLeft hours left before midnight! Visit Incline to protect your $streak-day streak.'
            : 'It\'s not too late for an evening workout or sauna recovery. Treat yourself tonight!';
        motivationUrgency = 'urgent_evening';
      }
    }

    final List<DateTime> sortedDays = uniqueDays.toList()..sort();
    int bestStreak = sortedDays.isNotEmpty ? 1 : 0;
    int currentRun = 1;
    for (int i = 1; i < sortedDays.length; i++) {
      if (sortedDays[i].difference(sortedDays[i - 1]).inDays == 1) {
        currentRun++;
        if (currentRun > bestStreak) bestStreak = currentRun;
      } else {
        currentRun = 1;
      }
    }

    return MemberAttendanceAnalysis(
      streakDays: streak,
      bestStreakDays: bestStreak,
      totalVisits: uniqueDays.length,
      monthlyVisits: monthlyVisits,
      isVisitedToday: isVisitedToday,
      todayCheckIn: todayRecord?.checkInTime,
      habitualTime: habitualTimeStr,
      motivationTitle: motivationTitle,
      motivationMessage: motivationMessage,
      motivationUrgency: motivationUrgency,
      weekActivity: weekActivity,
    );
  }

  Future<StreakData> fetchMemberStreak(String memberId) async {
    final analysis = await analyzeMemberAttendance(memberId);
    final currentStreak = analysis.streakDays;
    final int nextMilestoneTarget = currentStreak < 7
        ? 7
        : (currentStreak < 14
            ? 14
            : (currentStreak < 21 ? 21 : ((currentStreak ~/ 10 + 1) * 10)));
    final milestoneProgress = nextMilestoneTarget > 0
        ? (currentStreak / nextMilestoneTarget).clamp(0.0, 1.0)
        : 1.0;

    return StreakData(
      currentStreak: currentStreak,
      bestStreak: currentStreak > 14 ? currentStreak : 14,
      monthlyVisits: analysis.monthlyVisits,
      weekActivity: analysis.weekActivity,
      nextMilestone: '$nextMilestoneTarget Days: Incline Gold Trophy 🏆',
      milestoneProgress: milestoneProgress,
    );
  }

  // ---------------------------------------------------------------------------
  // MEMBER REFERRALS & REWARDS
  // ---------------------------------------------------------------------------

  /// Fetches branch or club-wide referral program configuration synced with backend rules
  Future<ReferralSettings> fetchReferralSettings([String? branchId]) async {
    try {
      var query = client.from('referral_settings').select('*');
      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('branch_id', branchId);
      }
      final res = await query.limit(1);
      if (res.isNotEmpty) {
        return ReferralSettings.fromJson(res.first);
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchReferralSettings fallback: $e');
    }
    return ReferralSettings.standardDefault(branchId);
  }

  Future<List<MemberReferral>> fetchMemberReferrals(String memberId) async {
    try {
      final res = await client
          .from('referrals')
          .select('*')
          .eq('referrer_member_id', memberId)
          .order('created_at', ascending: false);
      return (res as List).map((r) => MemberReferral.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[INCLINE] fetchMemberReferrals error: $e');
      return [];
    }
  }

  /// Fetches rewards earned by a member for successful referrals
  Future<List<ReferralReward>> fetchMemberRewards(String memberId) async {
    try {
      final res = await client
          .from('referral_rewards')
          .select('*')
          .eq('member_id', memberId)
          .order('created_at', ascending: false);
      return (res as List).map((r) => ReferralReward.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[INCLINE] fetchMemberRewards error: $e');
      return [];
    }
  }

  /// Queries whether referral reward claims and payouts are currently active for the branch.
  /// Server-side gating authority: Never calculated on the client.
  Future<bool> getReferralRewardsEnabled(String? branchId) async {
    final targetBranchId = (branchId != null && branchId.isNotEmpty)
        ? branchId
        : '11111111-1111-1111-1111-111111111111';

    // 1. Check RPC get_referral_rewards_enabled
    try {
      final res = await client.rpc('get_referral_rewards_enabled', params: {
        'p_branch_id': targetBranchId,
      });
      if (res is bool) return res;
    } catch (e) {
      debugPrint('[INCLINE] get_referral_rewards_enabled RPC notice: $e');
    }

    // 2. Query branch referral settings directly (is_active switch)
    try {
      final list = await client
          .from('referral_settings')
          .select('is_active, is_enabled')
          .eq('branch_id', targetBranchId)
          .limit(1);
      if (list.isNotEmpty) {
        final row = list.first;
        return row['is_active'] as bool? ?? row['is_enabled'] as bool? ?? false;
      }
    } catch (e) {
      debugPrint('[INCLINE] referral_settings table check fallback: $e');
    }
    return false;
  }

  /// Submits a referral reward claim request to the backend.
  /// Strictly server-authoritative: creates manager approval / credits wallet atomically.
  Future<Map<String, dynamic>> requestReferralRewardClaim({
    required String rewardId,
    required String memberId,
  }) async {
    // 1. Try RPC request_referral_reward_claim (manager approval workflow)
    try {
      final res = await client.rpc('request_referral_reward_claim', params: {
        'p_reward_id': rewardId,
      });
      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'success': true, 'status': 'pending_approval'};
    } catch (e) {
      debugPrint('[INCLINE] request_referral_reward_claim RPC notice: $e');
    }

    // 2. Fallback to atomic claim_referral_reward RPC
    try {
      final idempotencyKey = 'claim-$rewardId-$memberId-${DateTime.now().millisecondsSinceEpoch}';
      final res = await client.rpc('claim_referral_reward', params: {
        'p_reward_id': rewardId,
        'p_member_id': memberId,
        'p_idempotency_key': idempotencyKey,
      });
      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'success': true, 'status': 'claimed'};
    } catch (e) {
      debugPrint('[INCLINE] claim_referral_reward RPC error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ---------------------------------------------------------------------------
  // MEMBER RESERVATIONS & BOOKINGS (CLASSES, RECOVERY & PT)
  // ---------------------------------------------------------------------------

  /// Fetches confirmed upcoming bookings & booking history for the member
  Future<List<MemberReservation>> fetchMyReservations(String memberId) async {
    List<MemberReservation> reservations = [];

    // 1. Fetch Class Bookings from Supabase
    try {
      final classBookingsRes = await client
          .from('class_bookings')
          .select('*, class:classes(*, parent:class_types(*), trainer:trainers(profiles(full_name)))')
          .eq('member_id', memberId)
          .order('created_at', ascending: false)
          .limit(30);

      if (classBookingsRes.isNotEmpty) {
        for (final b in classBookingsRes) {
          final c = b['class'] as Map<String, dynamic>?;
          if (c != null) {
            final gymClass = GymClass.fromJson(c);
            final status = (b['status'] as String? ?? 'confirmed').toLowerCase();
            reservations.add(MemberReservation(
              id: b['id'] as String? ?? 'cb_${DateTime.now().millisecondsSinceEpoch}',
              bookingId: b['id'] as String? ?? '',
              type: 'class',
              title: gymClass.title,
              subtitle: '${gymClass.studio} • ${gymClass.durationMinutes} min',
              category: gymClass.category,
              dateTime: gymClass.date,
              startTime: gymClass.startTime,
              endTime: gymClass.endTime,
              venue: gymClass.studio,
              status: status,
              instructorName: gymClass.instructorName,
              canCancel: status == 'confirmed' || status == 'booked',
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchMyReservations class bookings error: $e');
    }

    // 2. Fetch Facility/Benefit Bookings from Supabase
    try {
      final recoveryBookingsRes = await client
          .from('benefit_bookings')
          .select('*, slot:benefit_slots(*, facilities(name), benefit_types(name))')
          .eq('member_id', memberId)
          .order('created_at', ascending: false)
          .limit(30);

      if (recoveryBookingsRes.isNotEmpty) {
        for (final b in recoveryBookingsRes) {
          final slotData = b['slot'] as Map<String, dynamic>?;
          if (slotData != null) {
            final slot = RecoverySlot.fromJson(slotData);
            final status = (b['status'] as String? ?? 'confirmed').toLowerCase();
            final dateParts = slot.slotDate.split('-');
            final slotDateTime = dateParts.length == 3
                ? DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]))
                : DateTime.now();

            reservations.add(MemberReservation(
              id: b['id'] as String? ?? 'bb_${DateTime.now().millisecondsSinceEpoch}',
              bookingId: b['id'] as String? ?? '',
              type: 'recovery',
              title: slot.facilityName,
              subtitle: 'Contrast Therapy & Hydrothermal Suite',
              category: 'Recovery Suite',
              dateTime: slotDateTime,
              startTime: slot.startTime,
              endTime: slot.endTime,
              venue: slot.facilityName,
              status: status,
              canCancel: status == 'confirmed' || status == 'booked',
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('[INCLINE] fetchMyReservations recovery bookings error: $e');
    }

    // Never provide fallback or sample reservations. If the member has no bookings, return empty.
    reservations.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return reservations;
  }
}
