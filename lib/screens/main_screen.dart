import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';

import 'parent_portal_screen.dart';
import 'changelog_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';



class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  bool _isOffline = false; // Mock state
  String _currentLang = 'en';

  @override
  void initState() {
    super.initState();
    _checkLastOpened();
    _loadLanguage();
    // Simulate showing dev popup on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDevPopup();
    });
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLang = prefs.getString('APP_LANG') ?? 'en';
    });
  }

  Future<void> _checkLastOpened() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpened = prefs.getString('LAST_OPENED');
    final taskId = prefs.getString('TASK_MANAGER_ID');
    final staffAuth = prefs.getString('userRole');

    if (lastOpened == 'task_manager' && taskId != null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/task_manager');
    } else if (lastOpened == 'staff' && staffAuth != null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/staff');
    }
  }

  void _showDevPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 120,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo, Colors.purple, Colors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'logo.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.indigo.shade100,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.indigo,
                                    size: 32,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          'Welcome to Atteni',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.blueGrey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.grey[600],
                              height: 1.5,
                              fontSize: 14,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Idea and Inspiration of ',
                              ),
                              TextSpan(
                                text: 'Kalpesh Kumar Bhoi Sir',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade600,
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildPopupButton(
                          icon: Icons.notifications_active,
                          label: 'View Latest Updates',
                          color: Colors.indigo,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangelogScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildPopupButton(
                          icon: Icons.person,
                          label: 'View Developer Profile',
                          color: Colors.purple,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/developer_profile');
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 5,
                          ),
                          child: Text(
                            'Continue to App',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          border: Border.all(color: color.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showStaffAccessModal() {
    Navigator.pushNamed(context, '/staff_login');
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.support_agent_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text('Emergency Support', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Technical Support:', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Text('Atteni Helpdesk', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email_rounded, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text('support@atteni.online', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_rounded, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text('+91-9413879444', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.language_rounded, color: Colors.teal),
            const SizedBox(width: 10),
            Text('Select Language', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
              title: Text('English', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              trailing: _currentLang == 'en' ? const Icon(Icons.check_circle, color: Colors.teal) : null,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('APP_LANG', 'en');
                setState(() => _currentLang = 'en');
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Language set to English')));
                }
              },
            ),
            ListTile(
              leading: const Text('अ', style: TextStyle(fontSize: 24, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              title: Text('हिंदी (Hindi)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              trailing: _currentLang == 'hi' ? const Icon(Icons.check_circle, color: Colors.teal) : null,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('APP_LANG', 'hi');
                setState(() => _currentLang = 'hi');
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('भाषा हिंदी में सेट की गई')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showParentLanguageSelection() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 24,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.language_rounded, size: 44, color: Colors.pink.shade400),
              ),
              const SizedBox(height: 24),
              Text(
                'Choose Language',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'अपनी भाषा चुनें',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Hindi Button
              Material(
                color: Colors.pink.shade500,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('APP_LANG', 'hi');
                    setState(() => _currentLang = 'hi');
                    if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/parent_login');
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('अ', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(
                          'हिंदी (Hindi)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // English Button
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('APP_LANG', 'en');
                    setState(() => _currentLang = 'en');
                    if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/parent_login');
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueGrey.shade200, width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'A',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'English',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: color.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
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
      backgroundColor: const Color(0xFFF8FAFC), // bg-slate-100
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(color: Colors.blueGrey.shade100, width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset('logo.webp', fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'ATTENI',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: -0.5,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'v32.0.0',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildTopButton(
                        context: context,
                        icon: Icons.help_outline_rounded,
                        label: 'FAQ',
                        color: Colors.indigo,
                        onTap: () => Navigator.pushNamed(context, '/faq'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Top Left Light Blue Circle Decoration
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE0F2FE),
              ),
            ),
          ),
          // Middle Left Light Purple Circle
          Positioned(
            top: 350,
            left: -150,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF3E8FF),
              ),
            ),
          ),
          // Bottom Right Pink Circle
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFCE7F3),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Welcome',
                              style: GoogleFonts.greatVibes(
                                fontSize: 84,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select your portal to continue',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          bool isWide = constraints.maxWidth > 800;
                          bool isTablet = constraints.maxWidth > 500;
                          
                          double cardWidth;
                          if (isWide) {
                            cardWidth = (constraints.maxWidth / 3) - 16;
                          } else if (isTablet) {
                            cardWidth = (constraints.maxWidth / 2) - 12;
                          } else {
                            cardWidth = double.infinity;
                          }

                          return Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 24,
                            runSpacing: 24,
                            children: [
                              _buildPortalCard(
                                title: 'Parent',
                                subtitle: 'Monitor Attendance',
                                icon: Icons.group,
                                color: Colors.blue,
                                onTap: _showParentLanguageSelection,
                                width: cardWidth,
                              ),
                              _buildPortalCard(
                                title: 'Staff',
                                subtitle: 'Manage Classes',
                                icon: Icons.co_present,
                                color: Colors.blueGrey,
                                onTap: _showStaffAccessModal,
                                width: cardWidth,
                              ),
                              _buildPortalCard(
                                title: 'Admin',
                                subtitle: 'System Settings',
                                icon: Icons.admin_panel_settings_rounded,
                                color: Colors.deepOrange,
                                onTap: () {
                                  Navigator.pushNamed(context, '/admin_login');
                                },
                                width: cardWidth,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        children: [
                          InkWell(
                            onTap: () {},
                            child: Text('Terms of Service', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade600)),
                          ),
                          InkWell(
                            onTap: () {},
                            child: Text('Privacy Policy', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade600)),
                          ),
                          InkWell(
                            onTap: () {},
                            child: Text('atteni.online', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ),
                        ]
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '© 2026 Atteni System. All rights reserved.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade400,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/developer_profile');
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            'Owned & Developed by Piyush Assudani — Founder, Assudani Group',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.blueGrey.shade400,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isOffline) _buildOfflineOverlay(),
        ],
      ),
    );
  }

  Widget _buildPortalCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
    required double width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.shade50,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 36, color: color.shade600),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineOverlay() {
    return Positioned.fill(
      child: ClipRRect(
        child: kIsWeb 
          ? Container(
              color: Colors.white.withValues(alpha: 0.95),
              alignment: Alignment.center,
              child: _buildOfflineOverlayContent(),
            )
          : BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
                color: Colors.white.withValues(alpha: 0.95),
                alignment: Alignment.center,
                child: _buildOfflineOverlayContent(),
              ),
            ),
      ),
    );
  }

  Widget _buildOfflineOverlayContent() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Offline Mode',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are disconnected. Please check your connection.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: Colors.blueGrey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}



