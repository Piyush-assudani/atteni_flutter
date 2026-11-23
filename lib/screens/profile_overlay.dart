import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileOverlay extends StatelessWidget {
  const ProfileOverlay({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => const ProfileOverlay(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $urlString');
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController passController = TextEditingController();
    bool isLoading = false;
    bool obscurePass = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.lock_reset, color: Colors.indigo.shade700, size: 28),
                const SizedBox(width: 12),
                const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter your new password below. You will use this to login next time.', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                TextField(
                  controller: passController,
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    filled: true,
                    fillColor: Colors.blueGrey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.indigo.shade400, width: 2)),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.blueGrey),
                      onPressed: () => setState(() => obscurePass = !obscurePass),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  final newPass = passController.text.trim();
                  if (newPass.isEmpty) return;
                  
                  setState(() => isLoading = true);
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final school = prefs.getString('SELECTED_SCHOOL');
                    final staffKey = prefs.getString('STAFF_AUTH_KEY');
                    
                    if (school != null && staffKey != null) {
                      await FirebaseDatabase.instance
                          .ref('artifacts/student-system-v2/public/data/$school/staff/$staffKey/pass')
                          .set(newPass);
                      
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password changed successfully!')),
                        );
                      }
                    } else {
                      throw Exception('Session info missing');
                    }
                  } catch (e) {
                    setState(() => isLoading = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to change password: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Password'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.95),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 24),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black12,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // App Logo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.1)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                      ),
                      child: Image.network('https://cdn-icons-png.flaticon.com/512/3135/3135715.png', width: 60, height: 60, errorBuilder: (c,e,s) => const Icon(Icons.person, size: 60)),
                    ),
                    const SizedBox(height: 24),
                    Text('ATTENI', style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text('PREMIUM EDITION v32.0.0', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 1.0)),
                    
                    const SizedBox(height: 48),
                    
                    // Account Settings Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('ACCOUNT SETTINGS', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1.0)),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _showChangePasswordDialog(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.lock_reset, color: Color(0xFF1D4ED8)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Change Password', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Update your login passcode', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Developer Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('DEVELOPER', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1.0)),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/developer_profile'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.badge, color: Color(0xFF475569)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Piyush Assudani', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Lead Developer', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Legal Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('LEGAL & SUPPORT', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 1.0)),
                    ),
                    const SizedBox(height: 12),
                    _buildLegalItem(
                      icon: Icons.shield,
                      iconColor: const Color(0xFF15803D),
                      iconBg: const Color(0xFFDCFCE7),
                      title: 'Privacy Policy',
                      subtitle: 'Read our privacy terms',
                      onTap: () => _launchURL('https://atteni-otp.piyushassudani.in/Atteni_privacypolicies/index.html'),
                    ),
                    const SizedBox(height: 12),
                    _buildLegalItem(
                      icon: Icons.description,
                      iconColor: const Color(0xFF0369A1),
                      iconBg: const Color(0xFFE0F2FE),
                      title: 'Terms & Conditions',
                      subtitle: 'Usage guidelines',
                      onTap: () => _launchURL('https://atteni-otp.piyushassudani.in/Atteni_privacypolicies/index.html'),
                    ),
                    
                    const SizedBox(height: 64),
                    Text('© 2025 Atteni Systems. All rights reserved.', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Made with ', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12)),
                        const Icon(Icons.favorite, color: Colors.red, size: 14),
                        Text(' by Piyush.', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalItem({required IconData icon, required Color iconColor, required Color iconBg, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Color(0xFF94A3B8), size: 18),
          ],
        ),
      ),
    );
  }
}
