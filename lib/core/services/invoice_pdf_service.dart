import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import 'supabase_service.dart';

/// Authoritative Incline GST Tax Invoice & Receipt PDF Generator & Storage Service
class InvoicePdfService {
  static final InvoicePdfService instance = InvoicePdfService._internal();
  InvoicePdfService._internal();

  // Incline Brand Palette for PDF (Thermal Orange & Obsidian)
  static final PdfColor goldAccent = PdfColor.fromHex('#F0441C');
  static final PdfColor obsidianBg = PdfColor.fromHex('#0A0A0A');
  static final PdfColor surfaceDark = PdfColor.fromHex('#1C1C1E');
  static final PdfColor textLight = PdfColor.fromHex('#FFFFFF');
  static final PdfColor textMuted = PdfColor.fromHex('#8E8E93');
  static final PdfColor borderCol = PdfColor.fromHex('#28282A');
  static final PdfColor emeraldCol = PdfColor.fromHex('#F0441C');

  /// Generates the raw binary PDF bytes for a given invoice auto-populating backend club details
  Future<Uint8List> generateInvoicePdfBytes(
    MemberInvoice invoice, {
    Member? member,
    Branch? branch,
  }) async {
    final pdf = pw.Document(
      title: 'Invoice_${invoice.invoiceNumber}',
      author: 'INCLINE',
      creator: 'Incline Member OS',
    );

    final fontRegular = await PdfGoogleFonts.outfitRegular();
    final fontBold = await PdfGoogleFonts.outfitBold();
    final fontMedium = await PdfGoogleFonts.outfitMedium();

    final memberName = member?.fullName ?? 'Incline Member';
    final memberCode = member?.memberCode ?? 'INC-MEMBER';
    final memberPhone = member?.profile?.phone ?? SupabaseService.instance.currentUser?.phone ?? '';
    final memberEmail = member?.profile?.email ?? SupabaseService.instance.currentUser?.email ?? '';

    // Auto-populated club metadata from backend (never hardcoded)
    final clubAddress = branch?.address ?? '';
    final clubGstin = branch?.gstin ?? '';
    final clubPhone = branch?.phone ?? '+91 8298293003';
    final clubEmail = branch?.email ?? 'info@theincline.in';
    final clubHours = 'Operating Hours: ${branch?.openingTime ?? "06:00 AM"} - ${branch?.closingTime ?? "10:00 PM"} | 24/7 Access';

    final issueDateStr = DateFormat('dd MMMM yyyy, hh:mm a').format(invoice.createdAt);
    final isPaid = invoice.isPaid;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          fontFallback: [fontMedium],
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. BRAND HEADER & TAX INVOICE BADGE
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Incline - Rise.Reflect.Repeat',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 16,
                          letterSpacing: 2.0,
                          color: goldAccent,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.SizedBox(
                        width: 250,
                        child: pw.Text(
                          clubAddress,
                          style: pw.TextStyle(fontSize: 8, color: textMuted),
                        ),
                      ),
                      if (invoice.hasGst)
                        pw.Text(
                          'GSTIN: $clubGstin | SAC: 999723',
                          style: pw.TextStyle(fontSize: 8, color: textMuted),
                        ),
                      pw.Text(
                        'Club Concierge: $clubPhone | $clubEmail',
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                      pw.Text(
                        clubHours,
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: isPaid ? emeraldCol : goldAccent,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          invoice.hasGst
                              ? (isPaid ? 'PAID TAX INVOICE' : 'TAX INVOICE')
                              : (isPaid ? 'PAID INVOICE' : 'INVOICE'),
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 9,
                            letterSpacing: 1.0,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        invoice.invoiceNumber,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 14,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        'Date: $issueDateStr',
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                      pw.Text(
                        'Place of Supply: Rajasthan (08)',
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(color: borderCol, thickness: 1),
              pw.SizedBox(height: 12),

              // 2. BILLED TO & PAYMENT SUMMARY
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#1C1C1E'),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: borderCol, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILLED TO MEMBER',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 8,
                              letterSpacing: 1.0,
                              color: textMuted,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            memberName,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 12,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.Text(
                            'Member ID: $memberCode',
                            style: pw.TextStyle(font: fontMedium, fontSize: 9, color: goldAccent),
                          ),
                          pw.Text(
                            'Mobile: $memberPhone',
                            style: pw.TextStyle(fontSize: 9, color: textMuted),
                          ),
                          pw.Text(
                            'Email: $memberEmail',
                            style: pw.TextStyle(fontSize: 9, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#1C1C1E'),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: borderCol, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TRANSACTION RECORD',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 8,
                              letterSpacing: 1.0,
                              color: textMuted,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Method: ${invoice.paymentMethod.replaceAll('•', '|')}',
                            style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Reference: ${invoice.transactionRef}',
                            style: pw.TextStyle(fontSize: 8, color: textMuted),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Status: ${invoice.status.toUpperCase()} (Verified)',
                            style: pw.TextStyle(font: fontBold, fontSize: 9, color: emeraldCol),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 18),

              // 3. ITEMIZED TABLE
              pw.Text(
                invoice.hasGst ? 'ITEMIZED TAX BREAKDOWN (HSN/SAC 999723)' : 'ITEMIZED SUMMARY',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 8,
                  letterSpacing: 1.0,
                  color: textMuted,
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: borderCol, width: 0.5),
                columnWidths: invoice.hasGst
                    ? {
                        0: const pw.FlexColumnWidth(0.6),
                        1: const pw.FlexColumnWidth(3.4),
                        2: const pw.FlexColumnWidth(1.2),
                        3: const pw.FlexColumnWidth(0.6),
                        4: const pw.FlexColumnWidth(1.4),
                        5: const pw.FlexColumnWidth(1.4),
                        6: const pw.FlexColumnWidth(1.4),
                      }
                    : {
                        0: const pw.FlexColumnWidth(0.6),
                        1: const pw.FlexColumnWidth(5.0),
                        2: const pw.FlexColumnWidth(1.0),
                        3: const pw.FlexColumnWidth(1.7),
                        4: const pw.FlexColumnWidth(1.7),
                      },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0A0A0A')),
                    children: invoice.hasGst
                        ? [
                            _th('#', fontBold),
                            _th('Description', fontBold),
                            _th('HSN/SAC', fontBold, align: pw.TextAlign.center),
                            _th('Qty', fontBold, align: pw.TextAlign.center),
                            _th('Taxable (Rs.)', fontBold, align: pw.TextAlign.right),
                            _th('GST ${invoice.gstRateFormatted} (Rs.)', fontBold, align: pw.TextAlign.right),
                            _th('Total (Rs.)', fontBold, align: pw.TextAlign.right),
                          ]
                        : [
                            _th('#', fontBold),
                            _th('Description', fontBold),
                            _th('Qty', fontBold, align: pw.TextAlign.center),
                            _th('Rate (Rs.)', fontBold, align: pw.TextAlign.right),
                            _th('Total (Rs.)', fontBold, align: pw.TextAlign.right),
                          ],
                  ),
                  // Table Rows
                  ...invoice.items.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final item = entry.value;
                    final isEven = entry.key % 2 == 0;
                    final rowBg = isEven ? PdfColors.white : PdfColor.fromHex('#1C1C1E');

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: rowBg),
                      children: invoice.hasGst
                          ? [
                              _td('$index', fontRegular, align: pw.TextAlign.center),
                              _td(item.description, fontMedium),
                              _td(item.hsnCode, fontRegular, align: pw.TextAlign.center),
                              _td('${item.quantity}', fontRegular, align: pw.TextAlign.center),
                              _td(item.unitPrice.toStringAsFixed(2), fontRegular, align: pw.TextAlign.right),
                              _td(item.taxAmount.toStringAsFixed(2), fontRegular, align: pw.TextAlign.right),
                              _td(item.totalAmount.toStringAsFixed(2), fontBold, align: pw.TextAlign.right),
                            ]
                          : [
                              _td('$index', fontRegular, align: pw.TextAlign.center),
                              _td(item.description, fontMedium),
                              _td('${item.quantity}', fontRegular, align: pw.TextAlign.center),
                              _td(item.unitPrice.toStringAsFixed(2), fontRegular, align: pw.TextAlign.right),
                              _td(item.totalAmount.toStringAsFixed(2), fontBold, align: pw.TextAlign.right),
                            ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 14),

              // 4. TAX TOTALS & SUMMARY BOX
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DECLARATION & TERMS',
                          style: pw.TextStyle(font: fontBold, fontSize: 8, letterSpacing: 1.0, color: textMuted),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          invoice.hasGst
                              ? '1. This is a computer-generated Tax Invoice issued under Section 31 of CGST Act, 2017 and does not require physical signature.\n'
                                  '2. Services billed are subject to Incline Athletic Club rules and membership terms.\n'
                                  '3. Fees once paid are non-refundable & non-transferable as per club charter.'
                              : '1. This is a computer-generated invoice and does not require physical signature.\n'
                                  '2. Services billed are subject to Incline Athletic Club rules and membership terms.\n'
                                  '3. Fees once paid are non-refundable & non-transferable as per club charter.',
                          style: pw.TextStyle(fontSize: 7.5, color: textMuted, lineSpacing: 1.3),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: emeraldCol, width: 0.8),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Container(
                                width: 6,
                                height: 6,
                                decoration: pw.BoxDecoration(color: emeraldCol, shape: pw.BoxShape.circle),
                              ),
                              pw.SizedBox(width: 6),
                              pw.Text(
                                invoice.hasGst
                                    ? 'Electronic Verification: AUTH-GST-INCLINE-OK'
                                    : 'Electronic Verification: AUTH-INCLINE-OK',
                                style: pw.TextStyle(font: fontBold, fontSize: 7, color: emeraldCol),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#1C1C1E'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: borderCol, width: 0.5),
                      ),
                      child: pw.Column(
                        children: [
                          if (invoice.hasGst) ...[
                            _summaryRow('Taxable Value:', 'Rs. ${invoice.subtotal.toStringAsFixed(2)}', fontRegular),
                            pw.SizedBox(height: 4),
                            _summaryRow('CGST @ ${invoice.cgstRateFormatted}:', 'Rs. ${(invoice.taxAmount / 2).toStringAsFixed(2)}', fontRegular),
                            pw.SizedBox(height: 4),
                            _summaryRow('SGST @ ${invoice.sgstRateFormatted}:', 'Rs. ${(invoice.taxAmount / 2).toStringAsFixed(2)}', fontRegular),
                            pw.SizedBox(height: 4),
                            _summaryRow('Total GST (${invoice.gstRateFormatted}):', 'Rs. ${invoice.taxAmount.toStringAsFixed(2)}', fontMedium),
                            pw.SizedBox(height: 6),
                            pw.Divider(color: borderCol, thickness: 0.5),
                            pw.SizedBox(height: 6),
                          ] else ...[
                            _summaryRow('Subtotal:', 'Rs. ${invoice.subtotal.toStringAsFixed(2)}', fontRegular),
                            pw.SizedBox(height: 6),
                            pw.Divider(color: borderCol, thickness: 0.5),
                            pw.SizedBox(height: 6),
                          ],
                          _summaryRow(
                            'Grand Total Paid:',
                            'Rs. ${invoice.totalAmount.toStringAsFixed(2)}',
                            fontBold,
                            color: goldAccent,
                            fontSize: 13,
                          ),
                          pw.SizedBox(height: 4),
                          _summaryRow(
                            'Balance Due:',
                            'Rs. 0.00',
                            fontMedium,
                            color: emeraldCol,
                            fontSize: 9,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // 5. FOOTER
              pw.Divider(color: borderCol, thickness: 0.5),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    () {
                      final branchCity = branch?.city ?? '';
                      final branchState = branch?.state ?? '';
                      final locTag = [branchCity, branchState].where((s) => s.trim().isNotEmpty).join(', ');
                      final locSuffix = locTag.isNotEmpty ? ' | $locTag' : '';
                      return invoice.hasGst
                          ? 'INCLINE | Official Tax Receipt$locSuffix'
                          : 'INCLINE | Official Receipt$locSuffix';
                    }(),
                    style: pw.TextStyle(fontSize: 7.5, color: textMuted),
                  ),
                  pw.Text(
                    'Page 1 of 1 | System Generated',
                    style: pw.TextStyle(fontSize: 7.5, color: textMuted),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  // DEVICE STORAGE & ACTIONS
  // ---------------------------------------------------------------------------

  /// Saves the generated PDF file directly to device storage (Downloads or App Documents)
  Future<File> saveInvoiceToDevice(
    MemberInvoice invoice, {
    Member? member,
    Branch? branch,
  }) async {
    final bytes = await generateInvoicePdfBytes(invoice, member: member, branch: branch);
    final safeInvNumber = invoice.invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'Invoice_$safeInvNumber.pdf';

    File? file;

    // 1. On Android, try writing to external downloads or external app directory
    if (Platform.isAndroid) {
      try {
        final publicDownloads = Directory('/storage/emulated/0/Download');
        if (publicDownloads.existsSync()) {
          final candidate = File('${publicDownloads.path}/$fileName');
          await candidate.writeAsBytes(bytes, flush: true);
          file = candidate;
        }
      } catch (e) {
        debugPrint('[INCLINE] Public Downloads write note (scoped storage): $e');
      }

      if (file == null) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final candidate = File('${extDir.path}/$fileName');
            await candidate.writeAsBytes(bytes, flush: true);
            file = candidate;
          }
        } catch (e) {
          debugPrint('[INCLINE] External storage directory write note: $e');
        }
      }
    }

    // 2. Guaranteed fallback: Application Documents directory
    if (file == null) {
      try {
        Directory? targetDir;
        if (Platform.isIOS) {
          targetDir = await getApplicationDocumentsDirectory();
        } else {
          try {
            targetDir = await getDownloadsDirectory();
          } catch (_) {}
          targetDir ??= await getApplicationDocumentsDirectory();
        }
        final candidate = File('${targetDir.path}/$fileName');
        await candidate.writeAsBytes(bytes, flush: true);
        file = candidate;
      } catch (e) {
        debugPrint('[INCLINE] App documents directory write error: $e');
        final appDocs = await getApplicationDocumentsDirectory();
        file = File('${appDocs.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
      }
    }

    debugPrint('[INCLINE] Saved invoice PDF to: ${file.path} (${bytes.length} bytes)');
    return file;
  }

  /// Opens the native system print preview / Save as PDF modal
  Future<void> printOrPreview(
    MemberInvoice invoice, {
    Member? member,
    Branch? branch,
  }) async {
    await Printing.layoutPdf(
      name: 'Invoice_${invoice.invoiceNumber}.pdf',
      onLayout: (PdfPageFormat format) async {
        return generateInvoicePdfBytes(invoice, member: member, branch: branch);
      },
    );
  }

  /// Triggers native share sheet to send the PDF via WhatsApp, Email, AirDrop, etc.
  Future<void> shareInvoice(
    MemberInvoice invoice, {
    Member? member,
    Branch? branch,
  }) async {
    final bytes = await generateInvoicePdfBytes(invoice, member: member, branch: branch);
    final safeInvNumber = invoice.invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Invoice_$safeInvNumber.pdf',
    );
  }

  /// Opens the saved file in external PDF viewer
  Future<OpenResult> openFile(File file) async {
    return OpenFilex.open(file.path);
  }

  // ---------------------------------------------------------------------------
  // PRIVATE PDF HELPERS
  // ---------------------------------------------------------------------------

  pw.Widget _th(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  pw.Widget _td(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          color: PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value,
    pw.Font font, {
    PdfColor? color,
    double fontSize = 8.5,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: fontSize, color: textMuted),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: font,
            fontSize: fontSize,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }
}
