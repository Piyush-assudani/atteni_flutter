import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  int _step = 1; // 1: School Code, 2: Credentials
  bool _isLoading = false;
  String _errorText = '';
  
  // Step 1
  final TextEditingController _codeController = TextEditingController();
  
  // Step 2
  bool _obscureText = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  String _connectedSchool = '';

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifySchoolCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorText = 'Please enter the school security code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = '';
    });

    try {
      String schoolId;
      if (code == 'DPS@ATTENI') {
        schoolId = 'DPS';
      } else {
        final db = FirebaseDatabase.instance.ref();
        final schoolSnap = await db.child('artifacts/student-system-v2/public/data/system_auth/schools/$code').get().timeout(const Duration(seconds: 8));
        if (schoolSnap.exists) {
          schoolId = schoolSnap.value.toString();
        } else {
          throw Exception('Invalid Access Code');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('SELECTED_SCHOOL', schoolId);

      if (mounted) {
        setState(() {
          _connectedSchool = schoolId;
          _step = 2;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Invalid Security Access Code';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performLogin() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Please enter both Username and Password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = '';
    });

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final staffSnap = await FirebaseService().getBaseRef(_connectedSchool).child('staff').get().timeout(const Duration(seconds: 10));

      if (!staffSnap.exists || staffSnap.value is! Map) {
        throw Exception('No administrative staff records found.');
      }

      final staffData = staffSnap.value as Map<dynamic, dynamic>;
      String? matchedKey;
      Map<dynamic, dynamic>? matchedData;

      if (staffData[email] != null) {
        matchedKey = email;
        matchedData = staffData[email] as Map<dynamic, dynamic>;
      } else {
        for (var entry in staffData.entries) {
          if (entry.value is! Map) continue;
          var d = entry.value as Map<dynamic, dynamic>;
          if ((d['email'] != null && d['email'].toString().toLowerCase() == email) ||
              (d['mobile'] != null && d['mobile'].toString() == email)) {
            matchedKey = entry.key.toString();
            matchedData = d;
            break;
          }
        }
      }

      if (matchedKey == null || matchedData == null) {
        throw Exception('Invalid Admin ID or Username.');
      }

      final role = (matchedData['role'] ?? '').toString().toLowerCase();
      if (role != 'admin' && role != 'master') {
        throw Exception('Access denied. Administrator privileges required.');
      }

      if (matchedData['pass'] != password) {
        throw Exception('Incorrect Passcode.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ADMIN_AUTH_KEY', matchedKey);
      await prefs.setString('userRole', 'admin');
      await prefs.setString('SELECTED_SCHOOL', _connectedSchool);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/admin_portal');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100, width: 1.5)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ADMIN LOGIN',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.5,
                          color: const Color(0xFF0F172A),
                        ),
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
          // Background Circles
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFF7ED)),
            ),
          ),
          Positioned(
            top: 350,
            left: -150,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFEDD5)),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFE4E6)),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 40, offset: const Offset(0, 20)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: Colors.deepOrange.shade50, shape: BoxShape.circle),
                            child: Icon(Icons.admin_panel_settings, color: Colors.deepOrange.shade600),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Admin Login', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                                Text(_step == 1 ? 'Step 1: Verification' : 'Step 2: Credentials', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      if (_errorText.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade100)),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_errorText, style: TextStyle(color: Colors.red.shade700, fontSize: 14, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ),

                      if (_step == 1) ...[
                        Text('SCHOOL SECURITY CODE', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          keyboardType: TextInputType.visiblePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B), letterSpacing: 2),
                          decoration: InputDecoration(
                            hintText: 'Enter Security Code',
                            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.blueGrey.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.deepOrange.shade400, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _verifySchoolCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 4,
                          ),
                          child: _isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Verify Code', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                      ] else if (_step == 2) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 32),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.deepOrange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.deepOrange.shade100)),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.deepOrange.shade100, shape: BoxShape.circle), child: Icon(Icons.school, color: Colors.deepOrange.shade600, size: 24)),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CONNECTED TO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade400, letterSpacing: 1)),
                                  Text(_connectedSchool, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade900)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text('ADMIN USERNAME', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.visiblePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Enter Username or Email',
                            filled: true,
                            fillColor: Colors.blueGrey.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.deepOrange.shade400, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('PASSCODE', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscureText,
                          keyboardType: TextInputType.visiblePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            filled: true,
                            fillColor: Colors.blueGrey.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.deepOrange.shade400, width: 2)),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: IconButton(
                                icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off, color: Colors.grey.shade400),
                                onPressed: () => setState(() => _obscureText = !_obscureText),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _performLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange.shade600,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 4,
                          ),
                          child: _isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Secure Login', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
