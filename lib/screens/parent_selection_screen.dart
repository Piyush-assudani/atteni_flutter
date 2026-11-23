import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'parent_portal_screen.dart';

class ParentSelectionScreen extends StatefulWidget {
  const ParentSelectionScreen({super.key});

  @override
  State<ParentSelectionScreen> createState() => _ParentSelectionScreenState();
}

class _ParentSelectionScreenState extends State<ParentSelectionScreen> {
  String _currentLang = 'en';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLang = prefs.getString('APP_LANG') ?? 'en';
    });
  }

  String _t(String key) {
    if (_currentLang == 'hi') {
      switch (key) {
        case 'Parent Portal': return 'अभिभावक पोर्टल (Parent Portal)';
        case 'Select a module to view your child\'s records': return 'अपने बच्चे के रिकॉर्ड देखने के लिए एक मॉड्यूल चुनें';
        case 'Daily Attendance': return 'दैनिक उपस्थिति';
        case 'Monitor student arrival and departure logs': return 'छात्र के आने-जाने का रिकॉर्ड देखें';
        case 'Daily Topic Taught': return 'दैनिक पढ़ाए गए विषय';
        case 'Track curriculum progress and daily topics': return 'पाठ्यक्रम की प्रगति और दैनिक विषय ट्रैक करें';
        case 'About': return 'हमारे बारे में (About)';
      }
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Fixed Top Pill Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Logout Button
                        InkWell(
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('SELECTED_SCHOOL');
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
                            }
                          },
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        
                        // Logo
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'logo.webp',
                            height: 26,
                            width: 26,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported, size: 26, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // ATTENI Text
                        Flexible(
                          child: Text(
                            'ATTENI',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        
                        // Version Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'v1.0.4',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // About Button
                        InkWell(
                          onTap: () => Navigator.pushNamed(context, '/developer_profile'),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 4),
                                Text(
                                  _t('About'),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        // Main Titles
                        Text(
                          _t('Parent Portal'),
                          style: GoogleFonts.outfit(
                            fontSize: MediaQuery.of(context).size.width < 360 ? 32 : 40,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -1.2,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t('Select a module to view your child\'s records'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 48),
                        
                        // Options
                        _buildPremiumOptionCard(
                          context: context,
                          title: _t('Daily Attendance'),
                          subtitle: _t('Monitor student arrival and departure logs'),
                          icon: Icons.fingerprint_rounded,
                          gradientColors: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                          shadowColor: const Color(0xFF3B82F6),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ParentPortalScreen(),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        _buildPremiumOptionCard(
                          context: context,
                          title: _t('Daily Topic Taught'),
                          subtitle: _t('Track curriculum progress and daily topics'),
                          icon: Icons.menu_book_rounded,
                          gradientColors: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
                          shadowColor: const Color(0xFF8B5CF6),
                          onTap: () {
                            Navigator.pushNamed(context, '/parent_daily_topics');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildPremiumOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Container with Gradient
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.last.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
