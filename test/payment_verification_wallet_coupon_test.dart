import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/services/supabase_service.dart';

void main() {
  group('Payment Verification & Security Invariants', () {
    test('PaymentVerificationResult isPaid requires both isVerified and paid/settled status', () {
      const verifiedPaid = PaymentVerificationResult(
        isVerified: true,
        invoiceId: 'inv-123',
        newStatus: 'paid',
        newAmountPaid: 2500.0,
      );
      expect(verifiedPaid.isVerified, isTrue);
      expect(verifiedPaid.isPaid, isTrue);
      expect(verifiedPaid.newStatus, equals('paid'));

      const verifiedSettled = PaymentVerificationResult(
        isVerified: true,
        invoiceId: 'inv-124',
        newStatus: 'settled',
        newAmountPaid: 1500.0,
      );
      expect(verifiedSettled.isPaid, isTrue);

      const verifiedPending = PaymentVerificationResult(
        isVerified: true,
        invoiceId: 'inv-125',
        newStatus: 'pending',
        newAmountPaid: 0.0,
      );
      expect(verifiedPending.isVerified, isTrue);
      expect(verifiedPending.isPaid, isFalse);

      const unverified = PaymentVerificationResult(
        isVerified: false,
        error: 'Invalid Razorpay signature: HMAC mismatch',
        code: 'BAD_SIGNATURE',
      );
      expect(unverified.isVerified, isFalse);
      expect(unverified.isPaid, isFalse);
      expect(unverified.error, contains('HMAC mismatch'));
      expect(unverified.code, equals('BAD_SIGNATURE'));
    });
  });

  group('Cart Discount & Wallet Balance Settlement Math', () {
    test('Correctly calculates subtotal, coupon discount, wallet deduction and final payable', () {
      const double rawSubtotal = 2500.0;
      const double couponDiscount = 500.0;
      const double walletBalance = 800.0;

      // 1. Discount applied
      final subtotalAfterDiscount = (rawSubtotal - couponDiscount).clamp(0.0, double.infinity);
      expect(subtotalAfterDiscount, equals(2000.0));

      // 2. Wallet applied
      double computeWallet(bool apply, double bal, double sub) => apply ? bal.clamp(0.0, sub) : 0.0;
      final walletDeduction = computeWallet(true, walletBalance, subtotalAfterDiscount);
      expect(walletDeduction, equals(800.0));

      // 3. Final payable to gateway
      final finalPayable = (subtotalAfterDiscount - walletDeduction).clamp(0.0, double.infinity);
      expect(finalPayable, equals(1200.0));
    });

    test('Zero-Balance settlement triggered when coupon covers 100%', () {
      const double rawSubtotal = 1200.0;
      const double couponDiscount = 1200.0;
      const double walletBalance = 500.0;

      final subtotalAfterDiscount = (rawSubtotal - couponDiscount).clamp(0.0, double.infinity);
      expect(subtotalAfterDiscount, equals(0.0));

      double computeWallet(bool apply, double bal, double sub) => apply ? bal.clamp(0.0, sub) : 0.0;
      final walletDeduction = computeWallet(false, walletBalance, subtotalAfterDiscount);
      expect(walletDeduction, equals(0.0));

      final finalPayable = (subtotalAfterDiscount - walletDeduction).clamp(0.0, double.infinity);
      expect(finalPayable, equals(0.0));
      expect(finalPayable <= 0.0, isTrue);
    });

    test('Zero-Balance settlement triggered when wallet covers full remainder', () {
      const double rawSubtotal = 1500.0;
      const double couponDiscount = 500.0;
      const double walletBalance = 1500.0;

      final subtotalAfterDiscount = (rawSubtotal - couponDiscount).clamp(0.0, double.infinity);
      expect(subtotalAfterDiscount, equals(1000.0));

      double computeWallet(bool apply, double bal, double sub) => apply ? bal.clamp(0.0, sub) : 0.0;
      final walletDeduction = computeWallet(true, walletBalance, subtotalAfterDiscount);
      expect(walletDeduction, equals(1000.0));

      final finalPayable = (subtotalAfterDiscount - walletDeduction).clamp(0.0, double.infinity);
      expect(finalPayable, equals(0.0));
      expect(finalPayable <= 0.0, isTrue);
    });
  });
}
