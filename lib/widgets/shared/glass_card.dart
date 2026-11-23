import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double sigmaX;
  final double sigmaY;
  final Color backgroundColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
    this.borderRadius = 24.0,
    this.sigmaX = 12.0,
    this.sigmaY = 12.0,
    this.backgroundColor = const Color(0xE6FFFFFF), // white with ~90% opacity
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: kIsWeb 
          ? Container(
              color: backgroundColor.withOpacity(0.95), // Fallback less transparent
              padding: padding,
              child: child,
            )
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
      ),
    );
  }
}
