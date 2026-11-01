import 'package:flutter/material.dart';

/// STRICT DESIGN SYSTEM: MONOCHROME CARBON & THERMAL ORANGE
/// Provides both Pitch Black Obsidian (Dark) and Crisp White Canvas (Light) palettes,
/// unified by a single signature Thermal Vermilion Orange (`#F0441C`) brand accent.
class InclineColors {
  // =========================================================================
  // 1. DARK MODE: Monochrome Carbon & Pitch Black Obsidian
  // =========================================================================
  static const Color bgPrimary = Color(0xFF0A0A0A);        // True pitch black canvas
  static const Color heroSpotlight = Color(0xFF3A3A3C);    // Soft grey radial glow behind hero silhouettes
  static const Color cardSurface = Color(0xFF1C1C1E);      // Matte dark charcoal bento cards
  static const Color cardRecessed = Color(0xFF28282A);     // Inner slider tracks & inactive nav buttons
  static const Color cardBorder = Color(0x14FFFFFF);       // 8% white subtle surface border

  // Smoked Floating Glass (Dark)
  static const Color glassFill = Color(0x1AFFFFFF);        // 10% white translucent fill
  static const Color glassBorderHighlight = Color(0x38FFFFFF); // 22% white top-left specular border
  static const Color glassBorderSubtle = Color(0x0DFFFFFF);    // 5% white bottom-right border

  // Typography & Icons (Dark)
  static const Color textPrimary = Color(0xFFFFFFFF);      // Pure white for headlines & metric numbers
  static const Color textSecondary = Color(0xFF8E8E93);    // Muted warm grey for unit labels & subtitles
  static const Color textMuted = Color(0xFF52525B);        // Scale ticks & disabled states

  // =========================================================================
  // 2. LIGHT MODE: Crisp White Canvas & High-Contrast Carbon Elements
  // =========================================================================
  static const Color lightBgPrimary = Color(0xFFF8F9FA);        // Clean crisp off-white canvas
  static const Color lightHeroSpotlight = Color(0xFFE9ECEF);    // Soft subtle radial spotlight
  static const Color lightCardSurface = Color(0xFFFFFFFF);      // Pure white bento cards
  static const Color lightCardRecessed = Color(0xFFF1F3F5);     // Recessed tracks & inactive nav buttons
  static const Color lightCardBorder = Color(0x14000000);       // 8% black subtle surface border

  // Smoked Floating Glass (Light)
  static const Color lightGlassFill = Color(0x0A000000);        // 4% black translucent fill
  static const Color lightGlassBorderHighlight = Color(0x1A000000); // 10% black border highlight
  static const Color lightGlassBorderSubtle = Color(0x08000000);    // 3% black subtle border

  // Typography & Icons (Light)
  static const Color lightTextPrimary = Color(0xFF0A0A0A);      // High-contrast pitch black for headlines & metrics
  static const Color lightTextSecondary = Color(0xFF52525B);    // Charcoal grey for unit labels & subtitles
  static const Color lightTextMuted = Color(0xFF8E8E93);        // Muted grey for scale ticks & disabled states

  // =========================================================================
  // 3. BRAND & THERMAL ACCENTS (IDENTICAL ACROSS BOTH LIGHT & DARK THEMES)
  // =========================================================================
  static const Color accentOrange = Color(0xFFF0441C);     // Primary CTA, active nav circle, gauge needle, notification dot
  static const Color thermalRed = Color(0xFFB91C1C);       // Deep muscle/thermal glow
  static const Color thermalAmber = Color(0xFFD97706);     // Core heat highlight
}
