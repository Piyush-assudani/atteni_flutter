import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../services/firebase_service.dart';

class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  int _step = 1; // 1: School Code, 2: Credentials
  bool _isLoading = false;
  String _errorText = '';
  
  // Step 1
  final TextEditingController _codeController = TextEditingController();
  
  String _currentLang = 'en';
  String _connectedSchool = '';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLang = prefs.getString('APP_LANG') ?? 'en';
      final savedCode = prefs.getString('SELECTED_SCHOOL_CODE');
      if (savedCode != null && savedCode.isNotEmpty) {
        _codeController.text = savedCode;
      }
    });
  }

  String _t(String key) {
    if (_currentLang == 'hi') {
      switch (key) {
        case 'Secure Parent Login': return 'सुरक्षित अभिभावक लॉगिन';
        case 'Connect to School': return 'स्कूल से कनेक्ट करें';
        case 'Enter the security code provided by your school': return 'अपने स्कूल द्वारा दिया गया सुरक्षा कोड दर्ज करें';
        case 'School Security Code': return 'स्कूल सुरक्षा कोड';
        case 'Enter Security Code': return 'सुरक्षा कोड दर्ज करें';
        case 'Verify Code': return 'कोड सत्यापित करें';
        case 'Login to ': return 'लॉगिन करें: ';
        case 'Enter your registered mobile number and password': return 'अपना पंजीकृत मोबाइल नंबर और पासवर्ड दर्ज करें';
        case 'Mobile Number': return 'मोबाइल नंबर';
        case 'Enter mobile number': return 'मोबाइल नंबर दर्ज करें';
        case 'Password': return 'पासवर्ड';
        case 'Enter password': return 'पासवर्ड दर्ज करें';
        case 'Change School': return 'स्कूल बदलें';
        case 'Secure Login': return 'सुरक्षित लॉगिन';
      }
    }
    return key;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifySchoolCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorText = "Please enter the school security code.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = "";
    });

    try {
      String schoolId;
      if (code == "DPS@ATTENI") {
        schoolId = "DPS";
      } else {
        final db = FirebaseDatabase.instance.ref();
        final schoolSnap = await db.child("artifacts/student-system-v2/public/data/system_auth/schools/" + code).get();
        if (schoolSnap.exists) {
          schoolId = schoolSnap.value.toString();
        } else {
          throw Exception("Invalid Access Code");
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("SELECTED_SCHOOL", schoolId);
      await prefs.setString("SELECTED_SCHOOL_CODE", code);
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/parent_selection");
      }
    } catch (e) {
      setState(() {
        _errorText = "Invalid Code. Please enter DPS@ATTENI or your valid school security code.";
        _isLoading = false;
      });
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
                        'PARENT LOGIN',
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
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE0F2FE)),
            ),
          ),
          Positioned(
            top: 350,
            left: -150,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF3E8FF)),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFCE7F3)),
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
                            decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle),
                            child: Icon(Icons.shield, color: Colors.indigo.shade600),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_t('Parent Login'), style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                                Text(_step == 1 ? _t('Step 1: Verification') : _t('Proceed'), style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B))),
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

                      Text(_t('SCHOOL SECURITY CODE'), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        keyboardType: TextInputType.visiblePassword,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B), letterSpacing: 2),
                        onSubmitted: (_) => _isLoading ? null : _verifySchoolCode(),
                        decoration: InputDecoration(
                          hintText: _t('Enter Security Code (e.g. DPS@ATTENI)'),
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.blueGrey.shade50,
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.indigo.shade400, width: 2)),
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
                            : Text(_t('Verify Code'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
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
