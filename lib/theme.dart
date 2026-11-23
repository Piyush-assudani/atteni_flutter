import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AtteniTheme {
  // Main Colors
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color secondary = Color(0xFF64748B);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  
  // Status Colors
  static const Color success = Color(0xFF15803D);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFF854D0E);
  static const Color warningBg = Color(0xFFFEF9C3);
  static const Color neutral = Color(0xFF94A3B8);
  static const Color neutralBg = Color(0xFFF1F5F9);
  
  static const Color textColor = Color(0xFF1E293B);

  // Background Gradient (replicates the radial gradients in CSS)
  static BoxDecoration get mainBackground => const BoxDecoration(
    color: bgColor,
    gradient: RadialGradient(
      center: Alignment(-1.0, -1.0),
      radius: 1.5,
      colors: [
        Color(0x12000000), // hsla(253, 16%, 7%, 0) approximation
        Colors.transparent,
      ],
      stops: [0.0, 0.5],
    ),
  );
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool hasShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = 24.0, // 1.5rem
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: kIsWeb ? Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95), // less transparent on web
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: padding,
            child: child,
          ) : BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
