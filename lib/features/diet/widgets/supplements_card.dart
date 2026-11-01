import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/bento_card.dart';

/// Interactive Daily Supplements & Recovery Micronutrients Bento Card
class SupplementsCard extends StatefulWidget {
  final List<String> supplements;

  const SupplementsCard({
    super.key,
    required this.supplements,
  });

  @override
  State<SupplementsCard> createState() => _SupplementsCardState();
}

class _SupplementsCardState extends State<SupplementsCard> {
  final Set<int> _checkedIndices = {0, 1}; // Default first 2 taken

  @override
  Widget build(BuildContext context) {
    if (widget.supplements.isEmpty) return const SizedBox.shrink();

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.medication_liquid_rounded, size: 16, color: AppTheme.amber),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'DAILY SUPPLEMENT PROTOCOL',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: context.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_checkedIndices.length}/${widget.supplements.length} TAKEN',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _checkedIndices.length == widget.supplements.length
                      ? AppTheme.emerald
                      : AppTheme.gold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ...widget.supplements.asMap().entries.map((entry) {
            final idx = entry.key;
            final text = entry.value;
            final isTaken = _checkedIndices.contains(idx);

            return InkWell(
              onTap: () {
                setState(() {
                  if (isTaken) {
                    _checkedIndices.remove(idx);
                  } else {
                    _checkedIndices.add(idx);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isTaken
                      ? context.cardBg.withValues(alpha: 0.5)
                      : context.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isTaken
                        ? AppTheme.emerald.withValues(alpha: 0.3)
                        : context.borderCol,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isTaken ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: isTaken ? AppTheme.emerald : context.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isTaken ? context.textMuted : context.textPrimary,
                          decoration: isTaken ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
