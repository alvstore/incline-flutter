import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incline_app/core/models/models.dart';
import 'package:incline_app/core/services/invoice_pdf_service.dart';
import 'package:incline_app/features/profile/invoices_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMember = Member(
    id: 'f07d801c-6892-475c-a08f-b7e70ec5a394',
    memberCode: 'INC-26-0025',
    status: 'active',
    fitnessGoals: 'Strength & Longevity',
    profile: const Profile(
      id: 'prof_01',
      fullName: 'Mohit Gurjar',
      email: 'mohitgurjarawanaa@gmail.com',
      phone: '+91 82098 87831',
    ),
  );

  final testInvoice = MemberInvoice(
    id: 'inv_test_01',
    invoiceNumber: 'INV-2026-0089',
    invoiceType: 'membership',
    createdAt: DateTime(2026, 10, 20, 14, 30),
    status: 'paid',
    subtotal: 42372.03,
    taxAmount: 7626.97,
    totalAmount: 49999.00,
    amountPaid: 49999.00,
    paymentMethod: 'UPI • Razorpay / HDFC',
    transactionRef: 'pay_test_94829104',
    isGstInvoice: true,
    gstin: '08AABCI9821Q1ZZ',
    notes: 'Annual Membership Renewal',
    items: const [
      InvoiceItem(
        description: 'Annual Elite Gold Membership Pass (365-Day Unlimited Club Access)',
        quantity: 1,
        unitPrice: 42372.03,
        taxAmount: 7626.97,
        taxRate: 18.0,
        totalAmount: 49999.00,
        hsnCode: '999723',
      ),
    ],
  );

  test('InvoicePdfService generates valid PDF bytes with Incline branding and GST fields', () async {
    final Uint8List pdfBytes = await InvoicePdfService.instance.generateInvoicePdfBytes(
      testInvoice,
      member: testMember,
    );

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(1024)); // Real document > 1 KB

    // PDF Magic bytes header: %PDF-
    final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
    expect(header, equals('%PDF-'));
  });

  testWidgets('InvoicesScreen renders invoices list, tax receipt dialog, and zero sanctuary text', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InvoicesScreen(
          member: testMember,
          initialInvoices: [testInvoice],
        ),
      ),
    );

    // Initial pump & advance for data load
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Title & Subtitle
    expect(find.text('Invoices & Payments'), findsOneWidget);
    expect(find.text('Past invoices, tax receipts & transaction history'), findsOneWidget);

    // Verify Invariant: ZERO mentions of "sanctuary" on invoices screen
    expect(find.textContaining('sanctuary', findRichText: true), findsNothing);
    expect(find.textContaining('Sanctuary', findRichText: true), findsNothing);

    // Verify invoice list contains item and tax buttons
    expect(find.text('View Tax Receipt'), findsWidgets);
    expect(find.byIcon(Icons.download_rounded), findsWidgets);

    // Tap View Tax Receipt to open tax invoice dialog
    await tester.tap(find.text('View Tax Receipt').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Tax Invoice Dialog
    expect(find.text('TAX INVOICE'), findsOneWidget);
    expect(find.text('Incline - Rise.Reflect.Repeat'), findsWidgets);
    expect(find.text('The Incline Life Pvt Ltd'), findsNothing);
    expect(find.textContaining('08AABCI9821Q1ZZ'), findsOneWidget);
    expect(find.text('Save PDF'), findsOneWidget);
    expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    expect(find.byIcon(Icons.print_rounded), findsOneWidget);

    // Close Dialog
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('InvoicesScreen correctly renders non-GST receipt without CGST or SGST', (WidgetTester tester) async {
    final nonGstInvoice = MemberInvoice(
      id: 'inv_nongst_01',
      invoiceNumber: 'INV-2026-0099',
      invoiceType: 'membership',
      createdAt: DateTime(2026, 10, 21, 10, 00),
      status: 'paid',
      subtotal: 20000.00,
      taxAmount: 0.0,
      totalAmount: 20000.00,
      amountPaid: 20000.00,
      paymentMethod: 'Manual · Cash',
      transactionRef: 'pos_cash_101',
      isGstInvoice: false,
      gstin: '',
      notes: 'Direct Cash Payment',
      items: const [
        InvoiceItem(
          description: "Essential Annual - Founder's Pass - 365 days",
          quantity: 1,
          unitPrice: 20000.00,
          taxAmount: 0.0,
          taxRate: 0.0,
          totalAmount: 20000.00,
          hsnCode: '',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: InvoicesScreen(
          member: testMember,
          initialInvoices: [nonGstInvoice],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify non-GST button label is 'View Receipt'
    expect(find.text('View Receipt'), findsOneWidget);
    expect(find.text('View Tax Receipt'), findsNothing);

    // Open receipt dialog
    await tester.tap(find.text('View Receipt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Title is INVOICE (not TAX INVOICE)
    expect(find.text('INVOICE'), findsOneWidget);
    expect(find.text('TAX INVOICE'), findsNothing);

    // Verify company branding
    expect(find.text('Incline - Rise.Reflect.Repeat'), findsWidgets);
    expect(find.text('The Incline Life Pvt Ltd'), findsNothing);

    // Verify NO CGST or SGST is displayed
    expect(find.textContaining('CGST'), findsNothing);
    expect(find.textContaining('SGST'), findsNothing);
    expect(find.text('₹0.00'), findsNothing);

    // Total Amount Paid should be ₹20000.00
    expect(find.text('₹20000.00'), findsWidgets);

    // Close Dialog
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  test('Membership model calculates 278 days remaining from Supabase JSON', () {
    final supabaseJson = {
      'id': 'd83c913f-9bd0-4389-a877-0918cb28c6d7',
      'member_id': 'f07d801c-6892-475c-a08f-b7e70ec5a394',
      'status': 'active',
      'start_date': '2026-07-28',
      'end_date': '2027-07-27',
      'membership_plans': {
        'id': '29598a81-7311-44cc-b25c-4bac1d07517a',
        'name': "Essential Annual - Founder's Pass",
      },
    };

    final membership = Membership.fromJson(supabaseJson);
    expect(membership.planName, equals("Essential Annual - Founder's Pass"));
    expect(membership.status, equals('active'));
    final end = DateTime.parse('2027-07-27');
    final now = DateTime.now();
    final expectedDays = DateTime(end.year, end.month, end.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    expect(membership.daysRemaining, equals(expectedDays));
  });

  test('MemberPayment model parses Supabase JSON correctly', () {
    final invMap = {'7eb3060b-07eb-4a9c-979a-4a227f0cd3d5': 'INV-INC-26-0039'};
    final pmtJson1 = {
      'id': 'c29447dc-5826-4392-9964-e87f8ed34e0e',
      'invoice_id': '7eb3060b-07eb-4a9c-979a-4a227f0cd3d5',
      'member_id': 'f07d801c-6892-475c-a08f-b7e70ec5a394',
      'amount': 19000.0,
      'payment_method': 'cash',
      'payment_source': 'manual',
      'status': 'completed',
      'payment_date': '2026-07-30T22:39:02.663354+05:30',
      'notes': 'PAID TO RAJAT LEKHARI QR',
    };
    final p1 = MemberPayment.fromJson(pmtJson1, invMap);
    expect(p1.amount, equals(19000.0));
    expect(p1.invoiceNumber, equals('INV-INC-26-0039'));
    expect(p1.channel, equals('Manual · Cash'));
    expect(p1.notes, equals('PAID TO RAJAT LEKHARI QR'));
  });
}
