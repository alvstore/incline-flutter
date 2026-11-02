import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/config/env_config.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';
import '../../core/widgets/dumbbell_loader.dart';
import '../notifications/notifications_screen.dart';

const _bookingDateFormat = 'EEE, dd MMM yyyy';

/// Material 3 Bookings Screen for Studio Classes & Contrast Therapy Suites
/// Members can book Reformer Pilates, Spin, HIIT, Sound Bath, Steam (FREE), Sauna & Cold Plunge.
class BookingsScreen extends StatefulWidget {
  final Member? member;
  final int initialSection;
  final String? initialRecoveryFilter;

  const BookingsScreen({
    super.key,
    this.member,
    this.initialSection = 0,
    this.initialRecoveryFilter,
  });

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  // 0 = Studio Classes, 1 = Contrast Therapy Suites, 2 = My Bookings
  int _selectedSection = 0;

  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  String _activeClassFilter = 'all';
  String _activeRecoveryFilter = 'all';
  String _selectedTimePeriod = 'all'; // 'all', 'morning', 'afternoon', 'evening'

  TimeOfDay? _parseTime(String timeStr) {
    if (timeStr.isEmpty) return null;
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPM = clean.contains('PM');
      final isAM = clean.contains('AM');
      final noAmPm = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = noAmPm.split(':');
      int h = int.parse(parts[0]);
      int m = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPM && h != 12) h += 12;
      if (isAM && h == 12) h = 0;
      return TimeOfDay(hour: h, minute: m);
    } catch (_) {
      return null;
    }
  }

  bool _isSlotInPast(RecoverySlot slot) {
    final now = DateTime.now();
    DateTime slotDay;
    try {
      slotDay = DateTime.parse(slot.slotDate);
    } catch (_) {
      slotDay = _selectedDate;
    }
    final dateOnlySlot = DateTime(slotDay.year, slotDay.month, slotDay.day);
    final dateOnlyToday = DateTime(now.year, now.month, now.day);
    if (dateOnlySlot.isBefore(dateOnlyToday)) {
      return true;
    }
    if (dateOnlySlot.isAtSameMomentAs(dateOnlyToday)) {
      final t = _parseTime(slot.endTime.isNotEmpty ? slot.endTime : slot.startTime);
      if (t != null) {
        final slotEndDateTime = DateTime(now.year, now.month, now.day, t.hour, t.minute);
        return slotEndDateTime.isBefore(now);
      }
    }
    return false;
  }

  bool _isClassInPast(GymClass c) {
    final now = DateTime.now();
    final dateOnlyClass = DateTime(c.date.year, c.date.month, c.date.day);
    final dateOnlyToday = DateTime(now.year, now.month, now.day);
    if (dateOnlyClass.isBefore(dateOnlyToday)) {
      return true;
    }
    if (dateOnlyClass.isAtSameMomentAs(dateOnlyToday)) {
      final classEndTime = c.date.add(Duration(minutes: c.durationMinutes));
      return classEndTime.isBefore(now);
    }
    return false;
  }

  int? _extractHour(String timeStr) {
    if (timeStr.isEmpty) return null;
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPM = clean.contains('PM');
      final isAM = clean.contains('AM');
      final noAmPm = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = noAmPm.split(':');
      int h = int.parse(parts[0]);
      if (isPM && h != 12) h += 12;
      if (isAM && h == 12) h = 0;
      return h;
    } catch (_) {
      return null;
    }
  }

  bool _matchesTimePeriod(RecoverySlot slot, String period) {
    if (period == 'all') return true;
    final h = _extractHour(slot.startTime);
    if (h == null) return true;
    if (period == 'morning') return h >= 5 && h < 12;
    if (period == 'afternoon') return h >= 12 && h < 17;
    if (period == 'evening') return h >= 17 && h <= 23;
    return true;
  }

  // Razorpay Gateway State
  late Razorpay _razorpay;
  String? _pendingAddOnInvoiceId;
  int _pendingAddOnSessions = 1;
  String _pendingAddOnBenefitType = '';
  VoidCallback? _pendingAddOnCallback;
  BuildContext? _verificationDialogContext;

  List<GymClass> _classes = [];
  List<RecoverySlot> _recoverySlots = [];
  List<BenefitCredit> _benefitCredits = [];
  List<BenefitPackage> _benefitPackages = [];
  List<MemberReservation> _myReservations = [];
  Membership? _membership;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isBookingInFlight = false;

  int _getCreditsForSlot(RecoverySlot slot) {
    final type = slot.benefitType.toLowerCase();
    final name = slot.facilityName.toLowerCase();
    for (final cred in _benefitCredits) {
      final credType = cred.benefitType.toLowerCase();
      if ((type.contains('sauna') || name.contains('sauna')) && credType.contains('sauna')) {
        return cred.creditsRemaining;
      }
      if ((type.contains('ice') || type.contains('cold') || name.contains('ice') || name.contains('plunge')) &&
          (credType.contains('ice') || credType.contains('cold') || credType.contains('plunge'))) {
        return cred.creditsRemaining;
      }
      if ((type.contains('steam') || name.contains('steam')) && credType.contains('steam')) {
        return cred.creditsRemaining;
      }
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    if (widget.initialRecoveryFilter != null && widget.initialRecoveryFilter!.isNotEmpty) {
      _activeRecoveryFilter = widget.initialRecoveryFilter!;
    }
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleRazorpayExternalWallet);
    _loadBookingsData();
  }

  @override
  void didUpdateWidget(covariant BookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() => _selectedSection = widget.initialSection);
    }
    if (widget.initialRecoveryFilter != null &&
        widget.initialRecoveryFilter != oldWidget.initialRecoveryFilter) {
      setState(() => _activeRecoveryFilter = widget.initialRecoveryFilter!);
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _showVerifyingPaymentDialog(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _verificationDialogContext = ctx;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: context.cardElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: context.brandAccent.withValues(alpha: 0.5)),
            ),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DumbbellLoader(size: DumbbellLoaderSize.md),
                  const SizedBox(height: 20),
                  Text(
                    'Verifying with Incline Vault',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: context.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cryptographically authenticating payment ID: $paymentId',
                    style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _dismissVerificationDialog() {
    if (_verificationDialogContext != null) {
      Navigator.of(_verificationDialogContext!).pop();
      _verificationDialogContext = null;
    }
  }

  void _handleRazorpaySuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? 'pay_${DateTime.now().millisecondsSinceEpoch}';
    final orderId = response.orderId ?? '';
    final signature = response.signature ?? '';

    if (_pendingAddOnInvoiceId == null) {
      debugPrint('[INCLINE] Warning: _pendingAddOnInvoiceId is null in BookingsScreen._handleRazorpaySuccess');
      return;
    }

    _showVerifyingPaymentDialog(paymentId);

    final verifyResult = await SupabaseService.instance.verifyRazorpayPayment(
      invoiceId: _pendingAddOnInvoiceId!,
      razorpayPaymentId: paymentId,
      razorpayOrderId: orderId,
      razorpaySignature: signature,
      branchId: widget.member?.branchId,
    );

    _dismissVerificationDialog();

    if (verifyResult.isVerified) {
      await SupabaseService.instance.settleStoreOrder(
        invoiceId: _pendingAddOnInvoiceId,
        orderNumber: null,
        paymentReference: paymentId,
      );

      final memberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
      final updatedCredits = await SupabaseService.instance.fetchBenefitCredits(memberId);
      if (mounted) {
        setState(() {
          _benefitCredits = updatedCredits;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.cardElevated,
            content: Text(
              'Payment verified via Razorpay! Pass for $_pendingAddOnSessions session(s) ($_pendingAddOnBenefitType) activated.',
              style: GoogleFonts.outfit(color: AppTheme.emerald, fontWeight: FontWeight.w700),
            ),
          ),
        );

        if (_pendingAddOnCallback != null) {
          _pendingAddOnCallback!();
          _pendingAddOnCallback = null;
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFriendlyErrorMapper.toGeneralErrorMessage(verifyResult.error, action: 'payment verification')),
            backgroundColor: InclineColors.thermalRed,
          ),
        );
      }
    }
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    debugPrint('[INCLINE] Razorpay payment failed or cancelled: code=${response.code}, message=${response.message}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Payment cancelled or dismissed'),
          backgroundColor: InclineColors.thermalRed,
        ),
      );
    }
  }

  void _handleRazorpayExternalWallet(ExternalWalletResponse response) {
    debugPrint('[INCLINE] Razorpay external wallet selected: ${response.walletName}');
  }

  Future<void> _payAddOnWithRazorpay({
    required String serviceName,
    required int selectedSessions,
    required int totalPayable,
    VoidCallback? onPurchased,
  }) async {
    final cleanName = serviceName.toLowerCase();
    final isPlunge = cleanName.contains('ice') || cleanName.contains('cold') || cleanName.contains('plunge');
    final benefitType = isPlunge ? 'ice_bath' : 'sauna_therapy';

    // Dynamically match active package from backend benefit packages
    String? packageId;
    for (final p in _benefitPackages) {
      if (p.benefitType.toLowerCase() == benefitType || p.name.toLowerCase().contains(benefitType)) {
        packageId = p.id;
        break;
      }
    }
    if (packageId == null && _benefitPackages.isNotEmpty) {
      packageId = _benefitPackages.first.id;
    }

    if (packageId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recovery add-on packages are currently not available at this club branch.'),
            backgroundColor: InclineColors.thermalRed,
          ),
        );
      }
      return;
    }

    final effectiveMemberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
    final effectiveMembershipId = _membership?.id;

    if (effectiveMembershipId == null || effectiveMembershipId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An active membership is required to purchase recovery add-on packages.'),
            backgroundColor: InclineColors.thermalRed,
          ),
        );
      }
      return;
    }

    // 1. Create deferred authoritative draft invoice via RPC
    final purchaseRes = await SupabaseService.instance.purchaseBenefitCredits(
      memberId: effectiveMemberId,
      membershipId: effectiveMembershipId,
      packageId: packageId,
      branchId: widget.member?.branchId,
      paymentMethod: 'card',
      deferSettlement: true,
    );

    final invoiceId = purchaseRes['invoice_id'] as String?;
    if (invoiceId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFriendlyErrorMapper.toGeneralErrorMessage(purchaseRes['error'], action: 'pass purchase')),
            backgroundColor: InclineColors.thermalRed,
          ),
        );
      }
      return;
    }

    _pendingAddOnInvoiceId = invoiceId;
    _pendingAddOnSessions = selectedSessions;
    _pendingAddOnBenefitType = benefitType;
    _pendingAddOnCallback = onPurchased;

    // 2. Request trusted payment order from backend edge function
    final paymentOrder = await SupabaseService.instance.createPaymentOrder(
      invoiceId: invoiceId,
      branchId: widget.member?.branchId,
      gateway: 'razorpay',
    );

    if (paymentOrder == null || paymentOrder['gatewayOrderId'] == null) {
      final errorMsg = paymentOrder?['error']?.toString() ?? 'Backend did not produce a payment order';
      debugPrint('[Bookings] Payment order request failed: $errorMsg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not start this payment. Please try again or contact Club Concierge.'),
            backgroundColor: InclineColors.thermalRed,
          ),
        );
      }
      return;
    }

    final key = paymentOrder['razorpayKey'] as String? ?? EnvConfig.razorpayKeyId;
    final gatewayOrderId = paymentOrder['gatewayOrderId'] as String;
    final serverAmount = (paymentOrder['amount'] is num)
        ? (paymentOrder['amount'] as num).toDouble()
        : totalPayable.toDouble();

    // 3. Launch native Razorpay checkout
    final memberName = widget.member?.fullName ?? 'Incline Member';
    final memberEmail = widget.member?.profile?.email ?? 'member@incline.fit';
    final memberPhone = widget.member?.profile?.phone ?? SupabaseService.instance.currentUser?.phone ?? '';

    final options = {
      'key': key,
      'amount': (serverAmount * 100).toInt(),
      'name': 'INCLINE',
      'description': '$serviceName Pass ($selectedSessions Sessions)',
      'order_id': gatewayOrderId,
      'prefill': {
        'contact': memberPhone,
        'email': memberEmail,
        'name': memberName,
      },
      'theme': {
        'color': '#F0441C',
      },
      'modal': {
        'confirm_close': true,
      },
      'external': {
        'wallets': ['paytm', 'phonepe'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('[INCLINE] Native Razorpay exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment gateway is currently unreachable on this device. Please retry.'),
            backgroundColor: InclineColors.thermalRed,
          ),
        );
      }
    }
  }

  Future<void> _loadBookingsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final memberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';

    try {
      final results = await Future.wait([
        SupabaseService.instance.fetchGymClasses(date: _selectedDate),
        SupabaseService.instance.fetchRecoverySlots(date: _selectedDate),
        SupabaseService.instance.fetchBenefitCredits(memberId),
        SupabaseService.instance.fetchActiveMembership(memberId),
        SupabaseService.instance.fetchMyReservations(memberId),
        SupabaseService.instance.fetchBenefitPackages(),
      ]);

      if (mounted) {
        setState(() {
          _classes = results[0] as List<GymClass>;
          _recoverySlots = results[1] as List<RecoverySlot>;
          _benefitCredits = results[2] as List<BenefitCredit>;
          _membership = results[3] as Membership?;
          _myReservations = results[4] as List<MemberReservation>;
          _benefitPackages = results[5] as List<BenefitPackage>;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('[INCLINE] Bookings load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load club schedule. Please check your network connection.';
        });
      }
    }
  }

  void _onBookClass(GymClass gymClass) {
    if (gymClass.isFull || _isBookingInFlight) return;

    showDialog(
      context: context,
      barrierDismissible: !_isBookingInFlight,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.cardElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.fitness_center_rounded, color: context.brandAccent, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirm Class Booking',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gymClass.title,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.brandAccent),
              ),
              const SizedBox(height: 4),
              Text(
                'Instructor: ${gymClass.instructorName}\nStudio: ${gymClass.studio}\nTime: ${gymClass.startTime} - ${gymClass.endTime} (${gymClass.durationMinutes} min)',
                style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppTheme.emerald, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Complimentary with Incline Membership • ${gymClass.spotsRemaining} spots left',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                      ),
                    ),
                  ],
                ),
              ),
              if (gymClass.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  gymClass.description,
                  style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted, height: 1.4),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isBookingInFlight ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isBookingInFlight
                  ? null
                  : () async {
                      if (_isBookingInFlight) return;
                      setState(() => _isBookingInFlight = true);
                      setDialogState(() {});

                      final sm = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);
                      final brandAccent = context.brandAccent;
                      final cardElevated = context.cardElevated;

                      try {
                        final res = await SupabaseService.instance.bookGymClass(
                          classId: gymClass.id,
                          memberId: widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '',
                        );
                        if (mounted) {
                          nav.pop();
                          if (res['success'] == true) {
                            sm.showSnackBar(
                              SnackBar(
                                backgroundColor: cardElevated,
                                content: Text(
                                  'Reserved spot in ${gymClass.title}!',
                                  style: GoogleFonts.outfit(color: brandAccent, fontWeight: FontWeight.w700),
                                ),
                              ),
                            );
                            _loadBookingsData();
                          } else {
                            final errMsg = res['error'] as String? ?? 'Unable to book class.';
                            sm.showSnackBar(
                              SnackBar(
                                backgroundColor: cardElevated,
                                content: Text(
                                  UserFriendlyErrorMapper.toGeneralErrorMessage(errMsg, action: 'class booking'),
                                  style: GoogleFonts.outfit(color: AppTheme.rose),
                                ),
                              ),
                            );
                          }
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isBookingInFlight = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandAccent,
                foregroundColor: Colors.white,
              ),
              child: _isBookingInFlight
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Confirm Booking', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _onBookRecoverySlot(RecoverySlot slot) {
    if (slot.isFull || _isBookingInFlight) return;

    final isFree = slot.isFreeWithPlan;
    final credits = _getCreditsForSlot(slot);

    // If customer has no credits for paid suite, require add-on purchase first
    if (!isFree && credits <= 0) {
      _showAddOnPurchaseDialog(
        slot.facilityName,
        slot.addOnPrice?.toInt() ?? 1500,
        onPurchased: () => _onBookRecoverySlot(slot),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: !_isBookingInFlight,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.cardElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                slot.isFreeWithPlan ? Icons.check_circle_rounded : Icons.confirmation_number_rounded,
                color: slot.isFreeWithPlan ? AppTheme.emerald : context.brandAccent,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirm Suite Reservation',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot.facilityName,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.brandAccent),
              ),
              const SizedBox(height: 6),
              Text(
                'Date: ${DateFormat(_bookingDateFormat).format(_selectedDate)}\nTime: ${slot.startTime} - ${slot.endTime} • ${slot.spotsRemaining} spots left',
                style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: slot.isFreeWithPlan
                      ? AppTheme.emerald.withValues(alpha: 0.12)
                      : context.brandAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: slot.isFreeWithPlan
                        ? AppTheme.emerald.withValues(alpha: 0.3)
                        : context.brandAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      slot.isFreeWithPlan ? Icons.verified_rounded : Icons.star_rounded,
                      color: slot.isFreeWithPlan ? AppTheme.emerald : context.brandAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        slot.isFreeWithPlan
                            ? 'Included in Incline Membership • FREE'
                            : 'Deducts 1 session pass ($credits pass${credits > 1 ? 'es' : ''} available)',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: slot.isFreeWithPlan ? AppTheme.emerald : context.brandAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isBookingInFlight ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isBookingInFlight
                  ? null
                  : () async {
                      if (_isBookingInFlight) return;
                      setState(() => _isBookingInFlight = true);
                      setDialogState(() {});

                      final sm = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);
                      final brandAccent = context.brandAccent;
                      final cardElevated = context.cardElevated;

                      try {
                        final membershipId = _membership?.id;
                        if (membershipId == null || membershipId.isEmpty) {
                          nav.pop();
                          sm.showSnackBar(
                            const SnackBar(
                              content: Text('An active club membership is required to book recovery amenities.'),
                              backgroundColor: InclineColors.thermalRed,
                            ),
                          );
                          return;
                        }

                        final res = await SupabaseService.instance.bookFacilitySlot(
                          slotId: slot.id,
                          memberId: widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '',
                          membershipId: membershipId,
                        );
                        if (mounted) {
                          nav.pop();
                          if (res['success'] == true) {
                            if (!isFree) {
                              // Deduct 1 credit locally
                              final type = slot.benefitType.toLowerCase();
                              final name = slot.facilityName.toLowerCase();
                              for (int i = 0; i < _benefitCredits.length; i++) {
                                final c = _benefitCredits[i];
                                final cType = c.benefitType.toLowerCase();
                                if (((type.contains('sauna') || name.contains('sauna')) && cType.contains('sauna')) ||
                                    ((type.contains('ice') || type.contains('cold') || name.contains('ice') || name.contains('plunge')) &&
                                        (cType.contains('ice') || cType.contains('cold') || cType.contains('plunge')))) {
                                  if (c.creditsRemaining > 0) {
                                    _benefitCredits[i] = BenefitCredit(
                                      id: c.id,
                                      benefitType: c.benefitType,
                                      creditsTotal: c.creditsTotal,
                                      creditsRemaining: c.creditsRemaining - 1,
                                      expiresAt: c.expiresAt,
                                      isAddOn: c.isAddOn,
                                    );
                                    break;
                                  }
                                }
                              }
                            }
                            sm.showSnackBar(
                              SnackBar(
                                backgroundColor: cardElevated,
                                content: Text(
                                  'Successfully reserved ${slot.facilityName}!',
                                  style: GoogleFonts.outfit(color: brandAccent, fontWeight: FontWeight.w700),
                                ),
                              ),
                            );
                            _loadBookingsData();
                          } else {
                            final errMsg = res['error'] as String? ?? 'Unable to complete booking.';
                            if (errMsg.contains('Purchase an add-on') || errMsg.contains('No sessions remaining')) {
                              _showAddOnPurchaseDialog(
                                slot.facilityName,
                                slot.addOnPrice?.toInt() ?? 1500,
                                onPurchased: () => _onBookRecoverySlot(slot),
                              );
                            } else {
                              sm.showSnackBar(
                                SnackBar(
                                  backgroundColor: cardElevated,
                                  content: Text(
                                    UserFriendlyErrorMapper.toGeneralErrorMessage(errMsg, action: 'recovery booking'),
                                    style: GoogleFonts.outfit(color: AppTheme.rose),
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isBookingInFlight = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: slot.isFreeWithPlan ? AppTheme.emerald : context.brandAccent,
                foregroundColor: Colors.white,
              ),
              child: _isBookingInFlight
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      slot.isFreeWithPlan ? 'Confirm (Free)' : 'Confirm with Pass',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _onCancelReservation(MemberReservation res) {
    if (!res.canCancel || _isBookingInFlight) return;

    showDialog(
      context: context,
      barrierDismissible: !_isBookingInFlight,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.cardElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                Icons.event_busy_rounded,
                color: AppTheme.rose,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cancel Reservation?',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                res.title,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.brandAccent),
              ),
              const SizedBox(height: 4),
              Text(
                'Scheduled: ${DateFormat(_bookingDateFormat).format(res.dateTime)} at ${res.startTime} (${res.venue})',
                style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.rose.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.rose.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'Are you sure you want to cancel this booking? If cancelled before the deadline, your session will be restored to your balance. This action cannot be undone.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isBookingInFlight ? null : () => Navigator.pop(ctx),
              child: const Text('Keep Reservation'),
            ),
            ElevatedButton(
              onPressed: _isBookingInFlight
                  ? null
                  : () async {
                      if (_isBookingInFlight) return;
                      setState(() => _isBookingInFlight = true);
                      setDialogState(() {});

                      final sm = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);
                      final brandAccent = context.brandAccent;
                      final cardElevated = context.cardElevated;

                      try {
                        Map<String, dynamic> cancelRes;
                        if (res.type == 'class') {
                          cancelRes = await SupabaseService.instance.cancelGymClass(
                            bookingId: res.bookingId,
                            reason: 'Cancelled by member',
                          );
                        } else {
                          cancelRes = await SupabaseService.instance.cancelFacilitySlot(
                            bookingId: res.bookingId,
                            reason: 'Cancelled by member',
                          );
                        }

                        if (mounted) {
                          nav.pop();
                          if (cancelRes['success'] == true) {
                            sm.showSnackBar(
                              SnackBar(
                                backgroundColor: cardElevated,
                                content: Text(
                                  'Reservation for ${res.title} has been cancelled. Your session has been returned to your balance.',
                                  style: GoogleFonts.outfit(color: brandAccent, fontWeight: FontWeight.w700),
                                ),
                              ),
                            );
                            _loadBookingsData();
                          } else {
                            final err = cancelRes['error'] as String? ?? 'Unable to cancel reservation.';
                            sm.showSnackBar(
                              SnackBar(
                                backgroundColor: cardElevated,
                                content: Text(UserFriendlyErrorMapper.toGeneralErrorMessage(err, action: 'reservation cancellation'), style: GoogleFonts.outfit(color: AppTheme.rose)),
                              ),
                            );
                          }
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isBookingInFlight = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.rose,
                foregroundColor: Colors.white,
              ),
              child: _isBookingInFlight
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Yes, Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOnPurchaseDialog(String serviceName, int price, {VoidCallback? onPurchased}) {
    int selectedSessions = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          final isSingle = selectedSessions == 1;
          final basePrice = isSingle ? 1500 : 6500;
          final convenienceFee = isSingle ? 45 : 95;
          final totalPayable = basePrice + convenienceFee;

          return AlertDialog(
            backgroundColor: context.cardElevated,
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: context.borderCol),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: context.brandAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.stars_rounded, color: context.brandAccent, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add-On Recovery Pass',
                    style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private $serviceName Session',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: context.brandAccent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Infrared Sauna & Sub-Zero Cold Plunge are premium contrast therapies requiring dedicated suite sanitation and session add-on credits.',
                    style: GoogleFonts.outfit(fontSize: 11.5, color: context.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 12),

                  // Pack Options Selector
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => selectedSessions = 1),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSingle ? context.brandAccent.withValues(alpha: 0.15) : context.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSingle ? context.brandAccent : context.borderCol,
                                width: isSingle ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '1 SESSION',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isSingle ? context.brandAccent : context.textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '₹1,500',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => selectedSessions = 5),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            decoration: BoxDecoration(
                              color: !isSingle ? AppTheme.emerald.withValues(alpha: 0.15) : context.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: !isSingle ? AppTheme.emerald : context.borderCol,
                                width: !isSingle ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '5 SESSIONS (SAVE 15%)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: !isSingle ? AppTheme.emerald : context.textMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '₹6,500',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fee Itemization Breakdown
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PAYMENT BREAKDOWN',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: context.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isSingle ? '1 Session Pass (incl. 5% GST)' : '5 Session Pack (incl. 5% GST)',
                              style: GoogleFonts.outfit(fontSize: 11.5, color: context.textSecondary),
                            ),
                            Text(
                              '₹$basePrice',
                              style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Online Gateway & Convenience Fee',
                              style: GoogleFonts.outfit(fontSize: 11.5, color: context.textSecondary),
                            ),
                            Text(
                              '₹$convenienceFee',
                              style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                            ),
                          ],
                        ),
                        Divider(height: 12, color: context.borderCol),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount Payable',
                              style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.textPrimary),
                            ),
                            Text(
                              '₹$totalPayable',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: isSingle ? context.brandAccent : AppTheme.emerald,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Gateway Note
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 13, color: AppTheme.emerald),
                      const SizedBox(width: 6),
                      Text(
                        'Secured via Razorpay Payment Gateway (UPI / Cards)',
                        style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.outfit(color: context.textMuted, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _payAddOnWithRazorpay(
                    serviceName: serviceName,
                    selectedSessions: selectedSessions,
                    totalPayable: totalPayable,
                    onPurchased: onPurchased,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSingle ? context.brandAccent : AppTheme.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(
                  'Pay ₹$totalPayable via Razorpay',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateRailStart = DateUtils.dateOnly(DateTime.now());

    // Filter classes (past classes on today or earlier dates are hidden from active booking)
    final filteredClasses = _classes.where((c) {
      if (_isClassInPast(c)) return false;
      if (_activeClassFilter == 'all') return true;
      if (_activeClassFilter == 'pilates') {
        return c.title.toLowerCase().contains('pilates') || c.category.toLowerCase().contains('pilates');
      }
      if (_activeClassFilter == 'yoga') {
        return c.title.toLowerCase().contains('yoga') || c.category.toLowerCase().contains('yoga') || c.category.toLowerCase().contains('mind');
      }
      return true;
    }).toList();

    // Filter recovery slots with time period support (past slots for today or earlier dates are hidden)
    final baseRecoverySlots = _recoverySlots.where((s) {
      if (_isSlotInPast(s)) return false;
      if (_activeRecoveryFilter == 'all') return true;
      if (_activeRecoveryFilter == 'steam') return s.benefitType.contains('steam');
      if (_activeRecoveryFilter == 'sauna') return s.benefitType.contains('sauna');
      if (_activeRecoveryFilter == 'ice') {
        return s.benefitType.contains('ice') ||
            s.benefitType.contains('cold') ||
            s.facilityName.toLowerCase().contains('cold') ||
            s.facilityName.toLowerCase().contains('plunge');
      }
      if (_activeRecoveryFilter == 'redlight') {
        return s.benefitType.contains('red') || s.benefitType.contains('light') || s.facilityName.toLowerCase().contains('spectrum');
      }
      return true;
    }).toList();

    final morningCount = baseRecoverySlots.where((s) => _matchesTimePeriod(s, 'morning')).length;
    final afternoonCount = baseRecoverySlots.where((s) => _matchesTimePeriod(s, 'afternoon')).length;
    final eveningCount = baseRecoverySlots.where((s) => _matchesTimePeriod(s, 'evening')).length;

    final filteredRecoverySlots = baseRecoverySlots.where((s) => _matchesTimePeriod(s, _selectedTimePeriod)).toList();

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Club Reservations',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary),
            ),
            Text(
              'Studio classes, private steam & contrast suites',
              style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            icon: Icon(Icons.notifications_outlined, color: context.brandAccent),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Section Switcher (Classes vs Contrast Therapy vs My Bookings)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.cardElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderCol),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selectedSection = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedSection == 0 ? context.brandAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fitness_center_rounded,
                                size: 15,
                                color: _selectedSection == 0 ? context.onBrandAccent : context.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Classes',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedSection == 0 ? context.onBrandAccent : context.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selectedSection = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedSection == 1 ? context.brandAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.hot_tub_rounded,
                                size: 15,
                                color: _selectedSection == 1 ? context.onBrandAccent : context.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Suites',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedSection == 1 ? context.onBrandAccent : context.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selectedSection = 2),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedSection == 2 ? context.brandAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 15,
                                color: _selectedSection == 2 ? context.onBrandAccent : context.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _myReservations.where((r) => r.isUpcoming).isNotEmpty
                                      ? 'My Bookings (${_myReservations.where((r) => r.isUpcoming).length})'
                                      : 'My Bookings',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedSection == 2 ? context.onBrandAccent : context.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_selectedSection != 2) ...[
              // Date Selector Rail (Next 7 days)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 60,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final date = dateRailStart.add(Duration(days: idx));
                      final isSelected = DateUtils.isSameDay(date, _selectedDate);

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedDate = date);
                          _loadBookingsData();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          decoration: BoxDecoration(
                            color: isSelected ? context.brandAccent : context.cardElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? context.brandAccent : context.borderCol,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('EEE').format(date).toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? context.onBrandAccent : context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd').format(date),
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? context.onBrandAccent : context.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Category Filter Pills
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: _selectedSection == 0
                      ? Row(
                          children: [
                            _classFilterChip('all', 'All Classes', Icons.grid_view_rounded),
                            const SizedBox(width: 8),
                            _classFilterChip('pilates', 'Reformer Pilates', Icons.self_improvement_rounded),
                            const SizedBox(width: 8),
                            _classFilterChip('yoga', 'Yoga & Mobility', Icons.spa_rounded),
                            const SizedBox(width: 12),
                          ],
                        )
                      : Row(
                          children: [
                            _recoveryFilterChip('all', 'All Suites', Icons.grid_view_rounded),
                            const SizedBox(width: 8),
                            _recoveryFilterChip('steam', 'Steam', Icons.hot_tub_rounded, isHighlight: true),
                            const SizedBox(width: 8),
                            _recoveryFilterChip('sauna', 'Infrared Sauna', Icons.wb_sunny_rounded),
                            const SizedBox(width: 8),
                            _recoveryFilterChip('ice', 'Cold Plunge', Icons.ac_unit_rounded),
                            const SizedBox(width: 8),
                            _recoveryFilterChip('redlight', 'Red-Light / Spectrum', Icons.light_mode_rounded),
                            const SizedBox(width: 12),
                          ],
                        ),
                ),
              ),

              // Time Period Filter for Contrast Suites (Morning, Afternoon, Evening)
              if (_selectedSection == 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: context.cardElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderCol),
                    ),
                    child: Row(
                      children: [
                        _timePeriodChip('all', 'All Day', baseRecoverySlots.length, Icons.view_day_rounded),
                        _timePeriodChip('morning', 'Morning', morningCount, Icons.wb_twilight_rounded),
                        _timePeriodChip('afternoon', 'Afternoon', afternoonCount, Icons.wb_sunny_rounded),
                        _timePeriodChip('evening', 'Evening', eveningCount, Icons.nights_stay_rounded),
                      ],
                    ),
                  ),
                ),
            ],

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: DumbbellLoader(text: 'Loading club schedule...', size: DumbbellLoaderSize.md))
                  : (_errorMessage != null && _classes.isEmpty && _recoverySlots.isEmpty && _myReservations.isEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_off_rounded, color: context.brandAccent, size: 48),
                                const SizedBox(height: 14),
                                Text(
                                  'Could Not Load Schedule',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary),
                                ),
                                const SizedBox(height: 18),
                                ElevatedButton.icon(
                                  onPressed: _loadBookingsData,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Retry Connection'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.brandAccent,
                                    foregroundColor: context.onBrandAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _selectedSection == 0
                          ? _buildClassesList(filteredClasses)
                          : (_selectedSection == 1
                              ? _buildRecoveryList(filteredRecoverySlots)
                              : _buildMyReservationsList()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassesList(List<GymClass> classes) {
    if (classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_rounded, color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              'No studio classes scheduled for this date.',
              style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: classes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, idx) {
        final item = classes[idx];
        return _buildClassCard(item);
      },
    );
  }

  Widget _buildClassCard(GymClass item) {
    final banner = (item.bannerUrl != null && item.bannerUrl!.isNotEmpty)
        ? item.bannerUrl!
        : (item.title.toLowerCase().contains('pilates')
            ? 'https://images.unsplash.com/photo-1518611012118-696072aa579a?auto=format&fit=crop&w=800&q=80'
            : (item.title.toLowerCase().contains('yoga')
                ? 'https://images.unsplash.com/photo-1545205597-3d9d02c29597?auto=format&fit=crop&w=800&q=80'
                : 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80'));

    return BentoCard(
      padding: EdgeInsets.zero,
      backgroundColor: context.cardElevated,
      border: Border.all(color: context.borderCol),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image with Overlays
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Image.network(
                    banner,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 140,
                      color: AppTheme.surfaceHighlight,
                      child: Center(
                        child: Icon(Icons.fitness_center_rounded, color: context.brandAccent, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
              // Gradient Scrim
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
              // Category & Plan Badges on top
              Positioned(
                top: 12,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'INCLUDED',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Duration & Venue overlay at bottom of banner
              Positioned(
                bottom: 10,
                left: 14,
                right: 14,
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${item.durationMinutes} MIN',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.studio,
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Content body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.brandAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.brandAccent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        item.startTime,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: context.brandAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Instructor & Intensity Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_pin_rounded, size: 16, color: context.brandAccent),
                          const SizedBox(width: 6),
                          Text(
                            item.instructorName,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, size: 16, color: AppTheme.amber),
                          const SizedBox(width: 4),
                          Text(
                            '~${item.burnKcal} kcal',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.amber),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Occupancy & Reserve Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.isFull ? 'Class Full' : '${item.spotsRemaining} spots available (${item.bookedCount}/${item.capacity})',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: item.isFull ? AppTheme.rose : context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: item.occupancyRate,
                              minHeight: 4,
                              backgroundColor: context.borderCol,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                item.isFull ? AppTheme.rose : context.brandAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: item.isFull || _isBookingInFlight ? null : () => _onBookClass(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.brandAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        item.isFull ? 'Full' : 'Reserve Spot',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryList(List<RecoverySlot> slots) {
    if (slots.isEmpty) {
      if (_activeRecoveryFilter == 'sauna' || _activeRecoveryFilter == 'ice') {
        final isSauna = _activeRecoveryFilter == 'sauna';
        return Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: BentoCard(
              padding: const EdgeInsets.all(22),
              backgroundColor: context.cardElevated,
              border: Border.all(color: context.brandAccent.withValues(alpha: 0.3)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.brandAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSauna ? Icons.wb_sunny_rounded : Icons.ac_unit_rounded,
                      color: context.brandAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isSauna ? 'Infrared Cedar Sauna' : 'Sub-Zero Cold Plunge',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final now = DateTime.now();
                      int daysUntilSat = (DateTime.saturday - now.weekday) % 7;
                      if (daysUntilSat <= 0) daysUntilSat += 7;
                      final nextSat = now.add(Duration(days: daysUntilSat));
                      final nextSatFormatted = DateFormat(_bookingDateFormat).format(nextSat);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Contrast therapy operates on weekend schedules with dedicated private suites.\n\nNext available sessions: $nextSatFormatted',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: context.textSecondary,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: InclineScaleButton(
                              onTap: () {
                                setState(() => _selectedDate = nextSat);
                                _loadBookingsData();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: context.brandAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, size: 18, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      'View ${DateFormat('EEEE').format(nextSat)} Slots',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: InclineScaleButton(
                      onTap: () => _showAddOnPurchaseDialog(
                        isSauna ? 'Infrared Cedar Sauna' : 'Sub-Zero Cold Plunge',
                        1500,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: context.brandAccent.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Purchase Add-On Credit (₹1,500)',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.brandAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy_rounded, color: context.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(
                _selectedTimePeriod != 'all'
                    ? 'No recovery slots available for ${_selectedTimePeriod.toUpperCase()} period.'
                    : 'No recovery slots available for selected date.',
                style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount: slots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final slot = slots[idx];
              return _buildRecoveryCard(slot);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecoveryCard(RecoverySlot slot) {
    final isFree = slot.isFreeWithPlan;
    final credits = _getCreditsForSlot(slot);
    final hasCredits = credits > 0;

    return BentoCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: context.cardElevated,
      border: Border.all(
        color: (isFree || hasCredits)
            ? AppTheme.emerald.withValues(alpha: 0.35)
            : context.borderCol,
        width: (isFree || hasCredits) ? 1.5 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isFree || hasCredits)
                            ? AppTheme.emerald.withValues(alpha: 0.15)
                            : context.brandAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        slot.benefitType.contains('steam')
                            ? Icons.hot_tub_rounded
                            : (slot.benefitType.contains('sauna')
                                ? Icons.wb_sunny_rounded
                                : (slot.benefitType.contains('ice')
                                    ? Icons.ac_unit_rounded
                                    : Icons.light_mode_rounded)),
                        color: (isFree || hasCredits) ? AppTheme.emerald : context.brandAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.facilityName,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${slot.startTime} - ${slot.endTime} • 30 mins session',
                            style: GoogleFonts.outfit(fontSize: 11, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Pricing or Free Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFree
                      ? AppTheme.emerald.withValues(alpha: 0.18)
                      : (hasCredits
                          ? AppTheme.emerald.withValues(alpha: 0.18)
                          : context.brandAccent.withValues(alpha: 0.18)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFree
                      ? 'INCLUDED • FREE'
                      : (hasCredits
                          ? '$credits PASS${credits > 1 ? 'ES' : ''} REMAINING'
                          : 'ADD-ON REQUIRED • ₹${slot.addOnPrice?.toInt() ?? 1500}'),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: (isFree || hasCredits) ? AppTheme.emerald : context.brandAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 16,
                    color: slot.isFull ? AppTheme.rose : context.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    slot.isFull
                        ? 'Fully Booked'
                        : '${slot.spotsRemaining} of ${slot.capacity} spots open',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: slot.isFull ? AppTheme.rose : context.textSecondary,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: slot.isFull || _isBookingInFlight
                    ? null
                    : (isFree || hasCredits
                        ? () => _onBookRecoverySlot(slot)
                        : () => _showAddOnPurchaseDialog(
                              slot.facilityName,
                              slot.addOnPrice?.toInt() ?? 1500,
                              onPurchased: () => _onBookRecoverySlot(slot),
                            )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isFree || hasCredits) ? AppTheme.emerald : context.brandAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  isFree
                      ? 'Book Free'
                      : (hasCredits ? 'Book with Pass' : 'Buy Add-On & Book'),
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyReservationsList() {
    final upcoming = _myReservations.where((r) => r.isUpcoming).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final past = _myReservations.where((r) => !r.isUpcoming).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      children: [
        // Upcoming reservations are the first and most visible content.
        Row(
          children: [
            Icon(Icons.upcoming_rounded, color: context.brandAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              'Upcoming Reservations (${upcoming.length})',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (upcoming.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'No upcoming class or suite reservations scheduled.',
                style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary),
              ),
            ),
          )
        else
          ...upcoming.map((res) => _buildReservationCard(res, isUpcoming: true)),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.cardElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderCol),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: context.brandAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Club Booking & Cancellation Policy',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Cancel before the class or facility deadline to restore your balance. Deadlines vary by booking.',
                      style: GoogleFonts.outfit(fontSize: 11, color: context.textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Past booking history
        Row(
          children: [
            Icon(Icons.history_rounded, color: context.textMuted, size: 18),
            const SizedBox(width: 8),
            Text(
              'Past Booking History',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (past.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'No past bookings recorded.',
                style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary),
              ),
            ),
          )
        else
          ...past.map((res) => _buildReservationCard(res, isUpcoming: false)),
      ],
    );
  }

  Widget _buildReservationCard(MemberReservation res, {required bool isUpcoming}) {
    final isClass = res.type == 'class';
    final isConfirmed = res.status == 'confirmed';
    final isCompleted = res.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUpcoming ? context.brandAccent.withValues(alpha: 0.3) : context.borderCol,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.brandAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isClass ? res.category.toUpperCase() : 'RECOVERY SUITE',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: context.brandAccent,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isConfirmed
                      ? AppTheme.emerald.withValues(alpha: 0.15)
                      : (isCompleted
                          ? Colors.blueGrey.withValues(alpha: 0.2)
                          : AppTheme.rose.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConfirmed
                          ? Icons.check_circle_rounded
                          : (isCompleted ? Icons.verified_rounded : Icons.cancel_rounded),
                      size: 12,
                      color: isConfirmed
                          ? AppTheme.emerald
                          : (isCompleted ? Colors.blueGrey : AppTheme.rose),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      res.status.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isConfirmed
                            ? AppTheme.emerald
                            : (isCompleted ? Colors.blueGrey : AppTheme.rose),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            res.title,
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat(_bookingDateFormat).format(res.dateTime)} • ${res.startTime} - ${res.endTime}',
            style: GoogleFonts.outfit(fontSize: 12, color: context.brandAccent, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: context.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  res.venue + (res.instructorName != null ? ' • Coach ${res.instructorName}' : ''),
                  style: GoogleFonts.outfit(fontSize: 11, color: context.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isUpcoming && res.canCancel) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _isBookingInFlight ? null : () => _onCancelReservation(res),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: Text('Cancel Reservation', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.rose,
                  side: BorderSide(color: AppTheme.rose.withValues(alpha: 0.5)),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _classFilterChip(String id, String label, IconData icon) {
    final isSelected = _activeClassFilter == id;

    return FilterChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _activeClassFilter = id),
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : context.brandAccent,
      ),
      label: Text(label),
      labelStyle: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : context.textPrimary,
      ),
      backgroundColor: context.cardElevated,
      selectedColor: context.brandAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.borderCol),
      ),
      showCheckmark: false,
    );
  }

  Widget _recoveryFilterChip(String id, String label, IconData icon, {bool isHighlight = false}) {
    final isSelected = _activeRecoveryFilter == id;

    return FilterChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _activeRecoveryFilter = id),
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? Colors.white
            : (isHighlight ? AppTheme.emerald : context.brandAccent),
      ),
      label: Text(label),
      labelStyle: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : context.textPrimary,
      ),
      backgroundColor: context.cardElevated,
      selectedColor: isHighlight ? AppTheme.emerald : context.brandAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHighlight
              ? AppTheme.emerald.withValues(alpha: 0.4)
              : context.borderCol,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _timePeriodChip(String id, String label, int count, IconData icon) {
    final isSelected = _selectedTimePeriod == id;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedTimePeriod = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? context.brandAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : context.brandAccent,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : context.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$count slots',
                style: GoogleFonts.outfit(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white.withValues(alpha: 0.8) : context.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
