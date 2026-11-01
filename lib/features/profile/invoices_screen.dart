import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/services/invoice_pdf_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';
import '../../core/widgets/dumbbell_loader.dart';

/// Material 3 Invoices & Transaction History Screen with itemized GST Tax receipts
class InvoicesScreen extends StatefulWidget {
  final Member? member;
  final Branch? branch;
  final List<MemberInvoice>? initialInvoices;
  final List<MemberPayment>? initialPayments;

  const InvoicesScreen({
    super.key,
    this.member,
    this.branch,
    this.initialInvoices,
    this.initialPayments,
  });

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<MemberInvoice> _invoices = [];
  List<MemberPayment> _payments = [];
  Branch? _branch;
  bool _isLoading = true;
  String? _errorMessage;
  int _viewMode = 0; // 0: All Invoices, 1: Payment History
  String _activeFilter = 'all'; // 'all', 'membership', 'addon', 'store'

  @override
  void initState() {
    super.initState();
    _branch = widget.branch;
    if (widget.initialInvoices != null) {
      _invoices = widget.initialInvoices!;
      _payments = widget.initialPayments ?? [];
      _isLoading = false;
    } else {
      _loadInvoices();
    }
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final memberId = widget.member?.id ?? SupabaseService.instance.cachedMember?.id ?? SupabaseService.instance.currentUser?.id ?? '';
    try {
      final results = await Future.wait([
        SupabaseService.instance.fetchMemberInvoices(memberId),
        widget.branch != null
            ? Future.value(widget.branch)
            : SupabaseService.instance.fetchBranch(null),
        SupabaseService.instance.fetchMemberPayments(memberId),
      ]);
      if (mounted) {
        setState(() {
          _invoices = results[0] as List<MemberInvoice>;
          _branch = results[1] as Branch?;
          _payments = results[2] as List<MemberPayment>;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('[InvoicesScreen] fetch notice: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load verified invoices. Please check your network connection.';
        });
      }
    }
  }

  List<MemberInvoice> get _filteredInvoices {
    if (_activeFilter == 'all') return _invoices;
    return _invoices.where((inv) => inv.invoiceType.toLowerCase() == _activeFilter).toList();
  }

  double get _totalSpend {
    return _invoices
        .where((inv) => inv.isPaid)
        .fold(0.0, (acc, inv) => acc + inv.amountPaid);
  }

  void _showTaxInvoiceDialog(MemberInvoice inv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.hasGst ? 'TAX INVOICE' : 'INVOICE',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: context.brandAccent,
                  ),
                ),
                Text(
                  inv.invoiceNumber.isNotEmpty ? inv.invoiceNumber : DateFormat('dd MMM yyyy').format(inv.createdAt),
                  style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (inv.status.toLowerCase() == 'cancelled' ? AppTheme.rose : AppTheme.emerald).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                inv.status.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: inv.status.toLowerCase() == 'cancelled' ? AppTheme.rose : AppTheme.emerald,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(color: context.borderCol),
                const SizedBox(height: 8),

                // Company & Brand Header (Auto-populated from backend)
                Text(
                  'Incline - Rise.Reflect.Repeat',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.brandAccent,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _branch?.address ?? 'Plot No. 44 to 47 & 52 to 55, Near Kheda Circle, Sector 14, Hiran Magri, Udaipur, Rajasthan 313001',
                  style: GoogleFonts.outfit(fontSize: 10.5, color: context.textMuted),
                ),
                if (inv.hasGst) ...[
                  const SizedBox(height: 2),
                  Text(
                    'GSTIN: ${_branch?.gstin ?? inv.gstin} • HSN/SAC: 999723',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                  ),
                ],
                const SizedBox(height: 12),

                // Billed To
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.borderCol),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, size: 16, color: context.brandAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Billed To: ${widget.member?.fullName ?? 'Incline Member'} (${widget.member?.memberCode ?? 'INC-MEMBER'})',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Itemized Breakdown
                Text(
                  'ITEMIZED SUMMARY',
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: context.textMuted),
                ),
                const SizedBox(height: 6),
                ...inv.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.description,
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary),
                              ),
                              Text(
                                inv.hasGst && item.hsnCode.isNotEmpty
                                    ? 'Qty: ${item.quantity} • HSN ${item.hsnCode}'
                                    : 'Qty: ${item.quantity}',
                                style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${item.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),
                Divider(color: context.borderCol),

                // Tax calculations & totals
                if (inv.hasGst) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Taxable Subtotal:', style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted)),
                      Text('₹${inv.subtotal.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CGST (${inv.cgstRateFormatted}) + SGST (${inv.sgstRateFormatted}):',
                        style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
                      ),
                      Text('₹${inv.taxAmount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  if (inv.subtotal != inv.totalAmount) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal:', style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted)),
                        Text('₹${inv.subtotal.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount Paid:',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: context.brandAccent),
                    ),
                    Text(
                      '₹${inv.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: context.brandAccent),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Payment verification
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.borderCol),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 16, color: AppTheme.emerald),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${inv.paymentMethod}\nTxn Ref: ${inv.transactionRef}',
                          style: GoogleFonts.outfit(fontSize: 11, color: context.textSecondary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        actions: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      InvoicePdfService.instance.shareInvoice(inv, member: widget.member, branch: _branch);
                    },
                    icon: Icon(Icons.share_rounded, size: 18, color: context.brandAccent),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Share PDF via WhatsApp/Apps',
                  ),
                  IconButton(
                    onPressed: () {
                      InvoicePdfService.instance.printOrPreview(inv, member: widget.member, branch: _branch);
                    },
                    icon: Icon(Icons.print_rounded, size: 18, color: context.textSecondary),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Print / System PDF Preview',
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: context.textSecondary,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleDownloadPdf(inv);
                    },
                    icon: const Icon(Icons.download_rounded, size: 15),
                    label: const Text('Save PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.brandAccent,
                      foregroundColor: context.onBrandAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Real PDF generation and storage write
  Future<void> _handleDownloadPdf(MemberInvoice inv) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: context.cardElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderCol),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: context.brandAccent),
              const SizedBox(height: 16),
              Text(
                'Generating GST Tax Invoice...',
                style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Writing verified PDF to device storage',
                style: GoogleFonts.outfit(color: context.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final file = await InvoicePdfService.instance.saveInvoiceToDevice(
        inv,
        member: widget.member,
        branch: _branch,
      );
      if (mounted) {
        rootNav.pop();
        _showDownloadCompleteSheet(inv, file);
      }
    } catch (e) {
      if (mounted) {
        rootNav.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.rose,
            content: Text(
              'PDF generation error: $e',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  /// Bottom sheet showing verified file storage details with immediate Open and Share CTAs
  void _showDownloadCompleteSheet(MemberInvoice inv, File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderCol,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoice PDF Stored',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
                        ),
                        Text(
                          'Official GST Tax Receipt generated & saved on device',
                          style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description_outlined, size: 16, color: context.brandAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            file.path.split('/').last,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Storage Location: ${file.path}',
                      style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Size: ${(file.lengthSync() / 1024).toStringAsFixed(1)} KB • Verified Incline Athletic Club GST Receipt',
                      style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        InvoicePdfService.instance.shareInvoice(inv, member: widget.member, branch: _branch);
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.brandAccent,
                        side: BorderSide(color: context.brandAccent.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        InvoicePdfService.instance.openFile(file);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.brandAccent,
                        foregroundColor: context.onBrandAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoices & Payments',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              'Past invoices, tax receipts & transaction history',
              style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.brandAccent),
            onPressed: _loadInvoices,
            tooltip: 'Refresh invoices',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: DumbbellLoader(
                  text: 'Loading tax invoices...',
                  size: DumbbellLoaderSize.md,
                ),
              )
            : (_errorMessage != null && _invoices.isEmpty && _payments.isEmpty)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded, color: context.brandAccent, size: 48),
                          const SizedBox(height: 14),
                          Text(
                            'Could Not Retrieve Invoices',
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
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _loadInvoices,
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
                : RefreshIndicator(
                    onRefresh: _loadInvoices,
                    color: context.brandAccent,
                    backgroundColor: context.cardElevated,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      children: [
                        // Summary Bento Card
                        BentoCard(
                          padding: const EdgeInsets.all(18),
                          backgroundColor: context.cardElevated,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TOTAL INVESTMENT IN WELLNESS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: context.textMuted,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'CLEARED',
                                      style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.emerald),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₹${_totalSpend.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: context.brandAccent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_invoices.length} Invoices • ${_payments.length} Payments Recorded',
                                style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),

                    const SizedBox(height: 16),

                    // Section View Mode Switcher: All Invoices vs Payment History
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.cardElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.borderCol),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _viewMode = 0),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: _viewMode == 0 ? context.brandAccent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      size: 15,
                                      color: _viewMode == 0 ? context.onBrandAccent : context.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'All Invoices (${_invoices.length})',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _viewMode == 0 ? context.onBrandAccent : context.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _viewMode = 1),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: _viewMode == 1 ? context.brandAccent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.payment_rounded,
                                      size: 15,
                                      color: _viewMode == 1 ? context.onBrandAccent : context.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Payment History (${_payments.length})',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _viewMode == 1 ? context.onBrandAccent : context.textMuted,
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

                    const SizedBox(height: 16),

                    if (_viewMode == 0) ...[
                      // Filter Chips Rail
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip('all', 'All (${_invoices.length})'),
                            const SizedBox(width: 8),
                            _filterChip('membership', 'Memberships'),
                            const SizedBox(width: 8),
                            _filterChip('addon', 'Add-ons & Spa'),
                            const SizedBox(width: 8),
                            _filterChip('store', 'Store & Fuel'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Invoices List
                      if (_filteredInvoices.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Text(
                            'No invoices found for this category.',
                            style: GoogleFonts.outfit(color: context.textSecondary),
                          ),
                        )
                      else
                        ..._filteredInvoices.map((inv) => _buildInvoiceCard(inv)),
                    ] else ...[
                      // Payment History View
                      if (_payments.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Text(
                            'No payment records found.',
                            style: GoogleFonts.outfit(color: context.textSecondary),
                          ),
                        )
                      else
                        ..._payments.map((p) => _buildPaymentHistoryCard(p)),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.brandAccent : context.cardElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? context.brandAccent : context.borderCol,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? context.onBrandAccent : context.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(MemberInvoice inv) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(inv.createdAt);
    final isCancelled = inv.status.toLowerCase() == 'cancelled';
    final statusColor = isCancelled ? AppTheme.rose : AppTheme.emerald;

    IconData typeIcon = Icons.receipt_long_rounded;
    Color typeColor = context.brandAccent;
    if (inv.invoiceType == 'addon') {
      typeIcon = Icons.hot_tub_rounded;
      typeColor = AppTheme.cyan;
    } else if (inv.invoiceType == 'store') {
      typeIcon = Icons.storefront_rounded;
      typeColor = AppTheme.amber;
    }

    final hasInvNum = inv.invoiceNumber.isNotEmpty;
    final primaryTitle = hasInvNum ? inv.invoiceNumber : DateFormat('dd MMM yyyy').format(inv.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: context.cardElevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type, Number, Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    inv.status.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Item description
            if (inv.items.isNotEmpty)
              Text(
                inv.items.first.description,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              )
            else if (inv.notes != null && inv.notes!.isNotEmpty)
              Text(
                inv.notes!,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),

            const SizedBox(height: 4),
            Text(
              '${inv.paymentMethod} • Status: ${inv.status}',
              style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
            ),

            const SizedBox(height: 14),

            // Bottom Row: Price & Action
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount: ₹${inv.totalAmount.toStringAsFixed(0)} • Paid: ₹${inv.amountPaid.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                    Text(
                      '₹${inv.totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isCancelled ? context.textMuted : context.brandAccent,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _handleDownloadPdf(inv),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      color: context.brandAccent,
                      tooltip: 'Save PDF to Device',
                    ),
                    const SizedBox(width: 2),
                    OutlinedButton.icon(
                      onPressed: () => _showTaxInvoiceDialog(inv),
                      icon: const Icon(Icons.receipt_outlined, size: 14),
                      label: Text(inv.hasGst ? 'View Tax Receipt' : 'View Receipt'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.brandAccent,
                        side: BorderSide(color: context.brandAccent.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistoryCard(MemberPayment p) {
    final dateStr = DateFormat('dd MMM yyyy').format(p.paymentDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: context.cardElevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${p.amount.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.brandAccent,
                          ),
                        ),
                        Text(
                          'Paid on $dateStr',
                          style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'COMPLETED',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppTheme.emerald,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderCol),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Invoice #:', style: GoogleFonts.outfit(fontSize: 11.5, color: context.textMuted)),
                      Text(
                        p.invoiceNumber,
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Channel:', style: GoogleFonts.outfit(fontSize: 11.5, color: context.textMuted)),
                      Text(
                        p.channel,
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reference:', style: GoogleFonts.outfit(fontSize: 11.5, color: context.textMuted)),
                      Text(
                        p.reference,
                        style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
                      ),
                    ],
                  ),
                  if (p.notes != null && p.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Note:', style: GoogleFonts.outfit(fontSize: 11.5, color: context.textMuted)),
                        Flexible(
                          child: Text(
                            p.notes!,
                            style: GoogleFonts.outfit(fontSize: 11, fontStyle: FontStyle.italic, color: context.brandAccent),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
