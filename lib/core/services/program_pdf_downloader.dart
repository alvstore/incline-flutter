import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Service to fetch or generate official Incline program PDFs,
/// save them directly to the device storage (Downloads / App Documents),
/// and open them natively with zero website redirects.
class ProgramPdfDownloader {
  ProgramPdfDownloader._();
  static final ProgramPdfDownloader instance = ProgramPdfDownloader._();

  /// Downloads or synthesizes the official program PDF and saves it to device storage.
  static Future<File?> downloadAndSaveProgramPdf(
    BuildContext context, {
    required String title,
    String? url,
    String? docId,
    WorkoutPlan? workoutPlan,
    MemberDietPlan? dietPlan,
  }) async {
    // Show download progress toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: context.cardElevated,
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(context.brandAccent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Fetching official program document...',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Uint8List? pdfBytes;

    // 1. Attempt to fetch remote PDF if URL is provided
    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
        final request = await client.getUrl(uri);
        final response = await request.close();

        if (response.statusCode == 200) {
          final fetchedBytes = await consolidateHttpClientResponseBytes(response);
          // Verify PDF magic header (%PDF-)
          if (fetchedBytes.length > 4 &&
              fetchedBytes[0] == 0x25 && // %
              fetchedBytes[1] == 0x50 && // P
              fetchedBytes[2] == 0x44 && // D
              fetchedBytes[3] == 0x46) {  // F
            pdfBytes = fetchedBytes;
            debugPrint('[INCLINE] Successfully fetched remote PDF (${pdfBytes.length} bytes)');
          } else {
            debugPrint('[INCLINE] Remote URL returned non-PDF content (likely 404 HTML). Falling back to synthesis.');
          }
        } else {
          debugPrint('[INCLINE] Remote PDF returned HTTP ${response.statusCode}. Falling back to synthesis.');
        }
      } catch (e) {
        debugPrint('[INCLINE] Remote PDF fetch note: $e. Falling back to local synthesis.');
      }
    }

    // 2. Synthesize authoritative official Incline PDF if remote is unavailable or 404
    if (pdfBytes == null) {
      debugPrint('[INCLINE] Synthesizing official Incline program document PDF locally...');
      pdfBytes = await generateAuthoritativePdf(
        title: title,
        docId: docId,
        workoutPlan: workoutPlan,
        dietPlan: dietPlan,
      );
    }

    // 3. Save to device storage
    final safeName = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'Incline_$safeName.pdf';
    File? savedFile;

    if (Platform.isAndroid) {
      try {
        final publicDownloads = Directory('/storage/emulated/0/Download');
        if (publicDownloads.existsSync()) {
          final candidate = File('${publicDownloads.path}/$fileName');
          await candidate.writeAsBytes(pdfBytes, flush: true);
          savedFile = candidate;
        }
      } catch (e) {
        debugPrint('[INCLINE] Public Downloads write error: $e');
      }

      if (savedFile == null) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final candidate = File('${extDir.path}/$fileName');
            await candidate.writeAsBytes(pdfBytes, flush: true);
            savedFile = candidate;
          }
        } catch (e) {
          debugPrint('[INCLINE] External storage write note: $e');
        }
      }
    }

    if (savedFile == null) {
      final appDocs = await getApplicationDocumentsDirectory();
      savedFile = File('${appDocs.path}/$fileName');
      await savedFile.writeAsBytes(pdfBytes, flush: true);
    }

    debugPrint('[INCLINE] Official program PDF saved to: ${savedFile.path} (${pdfBytes.length} bytes)');

    if (!context.mounted) return savedFile;

    // 4. Show success snackbar with action to open directly
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: context.cardElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.4)),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Program Downloaded',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    'Saved to Downloads / $fileName',
                    style: GoogleFonts.outfit(fontSize: 11, color: context.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'OPEN PDF',
          textColor: AppTheme.emerald,
          onPressed: () async {
            try {
              final res = await OpenFilex.open(savedFile!.path);
              debugPrint('[INCLINE] OpenFilex result: ${res.message}');
            } catch (e) {
              debugPrint('[INCLINE] OpenFilex error: $e');
            }
          },
        ),
      ),
    );

    return savedFile;
  }

  /// Synthesizes an authoritative multi-page PDF document representing the official program
  static Future<Uint8List> generateAuthoritativePdf({
    required String title,
    String? docId,
    WorkoutPlan? workoutPlan,
    MemberDietPlan? dietPlan,
  }) async {
    final pdf = pw.Document();

    final darkGreen = PdfColor.fromHex('#1C1C1E');
    final goldAccent = PdfColor.fromHex('#F0441C');
    final emeraldGreen = PdfColor.fromHex('#F0441C');
    final charcoal = PdfColor.fromHex('#0A0A0A');
    final lightGrey = PdfColor.fromHex('#28282A');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context ctx) {
          return [
            // Header: Incline Luxury Branding
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INCLINE CLUB',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: darkGreen,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'OFFICIAL PRESCRIBED PROTOCOL DOCUMENT',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: goldAccent,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (docId != null)
                        pw.Text(
                          'DOC REF: $docId',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: charcoal),
                        ),
                      pw.Text(
                        'DATE: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'HEAD COACH: BHAGIRATH GURJAR',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkGreen),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 18),

            // Program Title Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          title.toUpperCase(),
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: charcoal),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          workoutPlan?.description ?? dietPlan?.description ?? 'Structured progressive athletic protocol designed for Incline members.',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: emeraldGreen,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'VERIFIED INCLINE VAULT',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 18),

            // 7-Day Protocol Breakdown Table
            if (workoutPlan != null && workoutPlan.days.isNotEmpty) ...[
              pw.Text(
                'WEEKLY EXECUTION SCHEDULE',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkGreen, letterSpacing: 1),
              ),
              pw.SizedBox(height: 8),

              ...workoutPlan.days.map((day) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${day.dayLabel.toUpperCase()} — ${(day.focus ?? 'TRAINING').toUpperCase()}',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkGreen),
                          ),
                          pw.Text(
                            day.isRest ? 'ACTIVE RECOVERY / STEAM' : '${day.exercises.length} EXERCISES • ~${day.estimatedMinutes} MIN',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: day.isRest ? emeraldGreen : goldAccent,
                            ),
                          ),
                        ],
                      ),
                      if (day.warmUp != null && day.warmUp!.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Warm-Up: ${day.warmUp}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                      ],
                      if (!day.isRest && day.exercises.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        ...day.exercises.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final ex = entry.value;
                          return pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: 20,
                                  child: pw.Text('${idx + 1}.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                ),
                                pw.Expanded(
                                  flex: 4,
                                  child: pw.Text(
                                    ex.name,
                                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: charcoal),
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 3,
                                  child: pw.Text(
                                    ex.machineName ?? 'Standard Barbell / DB',
                                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                                  ),
                                ),
                                pw.SizedBox(
                                  width: 80,
                                  child: pw.Text(
                                    '${ex.sets} Sets x ${ex.reps}',
                                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkGreen),
                                  ),
                                ),
                                pw.SizedBox(
                                  width: 50,
                                  child: pw.Text(
                                    ex.rest ?? '90s rest',
                                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              }),
            ],

            // 7-Day Diet & Nutrition Protocol Breakdown Table
            if (dietPlan != null && dietPlan.days.isNotEmpty) ...[
              pw.Text(
                'NUTRITION & MACRONUTRIENT PROTOCOL',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkGreen, letterSpacing: 1),
              ),
              pw.SizedBox(height: 8),

              ...dietPlan.days.map((day) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            day.dayLabel.toUpperCase(),
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkGreen),
                          ),
                          pw.Text(
                            '${day.targetCalories} KCAL • P: ${day.targetProtein.toInt()}g • C: ${day.targetCarbs.toInt()}g • F: ${day.targetFats.toInt()}g',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: emeraldGreen),
                          ),
                        ],
                      ),
                      if (day.nutritionistNote != null && day.nutritionistNote!.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Coach Note: ${day.nutritionistNote}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                      ],
                      if (day.meals.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        ...day.meals.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final meal = entry.value;
                          final itemsDesc = meal.items.map((i) => '${i.quantity} ${i.name}').join(', ');
                          return pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: 20,
                                  child: pw.Text('${idx + 1}.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                ),
                                pw.Expanded(
                                  flex: 3,
                                  child: pw.Text(
                                    '${meal.name} (${meal.time})',
                                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: charcoal),
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 4,
                                  child: pw.Text(
                                    itemsDesc,
                                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                                  ),
                                ),
                                pw.SizedBox(
                                  width: 70,
                                  child: pw.Text(
                                    '${meal.targetCalories} kcal',
                                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkGreen),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              }),
            ],

            // Official Program Wisdom & Guidelines
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'OFFICIAL GUIDELINES FROM HEAD COACH BHAGIRATH GURJAR',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkGreen),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    '• Progressive Overload: Aim to increase load or clean reps each week without compromising tempo.\n'
                    '• Recovery Integration: Utilize the complimentary steam chambers post-workout and cold plunge sessions for CNS restoration.\n'
                    '• Form Integrity: Controlled 3-second eccentrics yield maximum tendon and muscle fiber adaptation.\n'
                    '• Hydration & Nutrition: Minimum 3.5L fluid daily with essential electrolytes for peak output.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800, lineSpacing: 3),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Incline Health & Fitness Pvt. Ltd. • All Rights Reserved',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'CONFIDENTIAL MEMBER COPY',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: goldAccent),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
