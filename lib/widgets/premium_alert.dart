import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumAlert {
  static void show(
    BuildContext context, {
    required String title,
    required String text,
    bool isError = false,
    String confirmText = 'OK',
    VoidCallback? onConfirm,
  }) {
    if (!context.mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return _PremiumAlertWidget(
          title: title,
          text: text,
          isError: isError,
          confirmText: confirmText,
          onConfirm: onConfirm,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10 * anim1.value,
            sigmaY: 10 * anim1.value,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  static void showSuccess(
    BuildContext context, {
    required String title,
    required String text,
    String confirmText = 'Great!',
    VoidCallback? onConfirm,
  }) {
    show(
      context,
      title: title,
      text: text,
      isError: false,
      confirmText: confirmText,
      onConfirm: onConfirm,
    );
  }

  static void showError(
    BuildContext context, {
    required String title,
    required String text,
    String confirmText = 'Dismiss',
    VoidCallback? onConfirm,
  }) {
    show(
      context,
      title: title,
      text: text,
      isError: true,
      confirmText: confirmText,
      onConfirm: onConfirm,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String title,
    required String text,
    String confirmText = 'Got It',
    VoidCallback? onConfirm,
  }) {
    show(
      context,
      title: title,
      text: text,
      isError: false,
      confirmText: confirmText,
      onConfirm: onConfirm,
    );
  }
}

class _PremiumAlertWidget extends StatelessWidget {
  final String title;
  final String text;
  final bool isError;
  final String confirmText;
  final VoidCallback? onConfirm;

  const _PremiumAlertWidget({
    required this.title,
    required this.text,
    required this.isError,
    required this.confirmText,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          width: MediaQuery.of(context).size.width * 0.88,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Icon placeholder
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isError ? Colors.red.shade50 : Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isError ? Icons.close_rounded : Icons.check_rounded,
                    color: isError ? Colors.red : Colors.green,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (onConfirm != null) onConfirm!();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isError ? Colors.red : Colors.indigo,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  confirmText,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
