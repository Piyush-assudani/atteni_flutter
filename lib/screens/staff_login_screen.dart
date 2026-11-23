import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../services/firebase_service.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
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
  String _localDeviceId = '';

  @override
  void initState() {
    super.initState();
    _initDeviceId();
    _checkAutoLogin();
  }

  Future<void> _initDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('local_device_id');
    if (id == null) {
      id = 'DEV-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}';
      await prefs.setString('local_device_id', id);
    }
    _localDeviceId = id;
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole');
    if (role != null && (role == 'teacher' || role == 'admin' || role == 'master' || role == 'gatekeeper')) {
      if (mounted) Navigator.pushReplacementNamed(context, '/staff');
    }
  }

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
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      
      final db = FirebaseDatabase.instance.ref();
      String schoolId;
      if (code == 'DPS@ATTENI') {
        schoolId = 'DPS';
      } else {
        final schoolSnap = await db.child('artifacts/student-system-v2/public/data/system_auth/schools/$code').get();
        if (!schoolSnap.exists) {
          throw Exception("Invalid Access Code");
        }
        schoolId = schoolSnap.value.toString();
      }
      
      // Check maintenance
      final acSnap = await db.child('artifacts/student-system-v2/public/data/system_auth/access_controls/$schoolId').get();
      if (acSnap.exists) {
        final ac = acSnap.value as Map<dynamic, dynamic>;
        if (ac['maintenance'] == true) {
          throw Exception("SERVER DOWN: Under Maintenance");
        }
      }
      
      setState(() {
        _connectedSchool = schoolId;
        _step = 2;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _errorText = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
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

      final staffSnap = await FirebaseService().getBaseRef(_connectedSchool).child('staff').get();

      if (!staffSnap.exists) {
        throw Exception("No staff records found in this node");
      }

      final staffData = staffSnap.value as Map<dynamic, dynamic>;
      String? matchedKey;
      Map<dynamic, dynamic>? matchedData;

      if (staffData[email] != null) {
        matchedKey = email;
        matchedData = staffData[email] as Map<dynamic, dynamic>;
      } else {
        for (var entry in staffData.entries) {
          var d = entry.value as Map<dynamic, dynamic>;
          if ((d['email'] != null && d['email'].toString().toLowerCase() == email.toLowerCase()) || 
              (d['mobile'] != null && d['mobile'].toString() == email)) {
            matchedKey = entry.key.toString();
            matchedData = d;
            break;
          }
        }
      }

      if (matchedKey == null || matchedData == null) {
        throw Exception("Invalid Staff ID or Username");
      }

      if (matchedData['pass'] != password) {
        throw Exception("Incorrect Passcode");
      }

      // Removed multi-device login check for staff to allow shared logins like 'dps'
      final sessionRef = FirebaseDatabase.instance.ref('artifacts/student-system-v2/public/data/system_auth/staff_sessions/$_connectedSchool/$matchedKey');

      // Set new active session
      await sessionRef.set({
        'deviceId': _localDeviceId,
        'deviceName': kIsWeb ? 'Web Browser' : 'Mobile App',
        'timestamp': ServerValue.timestamp,
      });

      // Save session info
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('STAFF_AUTH_KEY', matchedKey);
      await prefs.setString('STAFF_ID', matchedKey);
      await prefs.setString('STAFF_NAME', matchedData['name'] ?? matchedKey);
      await prefs.setString('STAFF_ROLE', matchedData['role'] ?? 'Teacher');
      
      final roleStr = (matchedData['role'] ?? 'Teacher').toString().toLowerCase();
      await prefs.setString('userRole', roleStr);
      await prefs.setString('teacherEmail', email);
      await prefs.setString('SELECTED_SCHOOL', _connectedSchool);
      
      if (mounted) {
        // Go to staff portal and remove this screen from stack
        Navigator.pushNamedAndRemoveUntil(context, '/staff', (route) => false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Widget _buildPortalChoiceButton({
    required String title,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.shade100, width: 2),
          borderRadius: BorderRadius.circular(20),
          color: color.shade50.withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color.shade700, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blueGrey.shade900,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.blueGrey.shade300),
          ],
        ),
      ),
    );
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
                        onPressed: () {
                          if (_step == 2) {
                            setState(() {
                              _step = 1;
                              _connectedSchool = '';
                              _emailController.clear();
                              _passwordController.clear();
                              _errorText = '';
                            });
                          } else {
                            Navigator.pushReplacementNamed(context, '/main');
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'STAFF LOGIN',
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
                                Text('Staff Login', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
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
                              : Text('Verify Code', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                      ] else if (_step == 2) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 32),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.indigo.shade100)),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigo.shade100, shape: BoxShape.circle), child: Icon(Icons.school, color: Colors.indigo.shade600, size: 24)),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CONNECTED TO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade400, letterSpacing: 1)),
                                  Text(_connectedSchool, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text('SELECT PORTAL', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
                        const SizedBox(height: 16),
                        _buildPortalChoiceButton(
                          title: 'Vehicle Attendance',
                          icon: Icons.directions_bus,
                          color: Colors.blue,
                          onTap: () => setState(() => _step = 3),
                        ),
                        const SizedBox(height: 16),
                        _buildPortalChoiceButton(
                          title: 'Daily Planner!',
                          icon: Icons.assignment_turned_in,
                          color: Colors.indigo,
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('SELECTED_SCHOOL', _connectedSchool);
                            if (mounted) {
                              Navigator.pushNamed(context, '/task_manager_login');
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildPortalChoiceButton(
                          title: 'Gate Keeper',
                          icon: Icons.security,
                          color: Colors.orange,
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('SELECTED_SCHOOL', _connectedSchool);
                            if (mounted) {
                              Navigator.pushNamed(context, '/gatekeeper_login');
                            }
                          },
                        ),
                      ] else if (_step == 3) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 32),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.indigo.shade100)),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigo.shade100, shape: BoxShape.circle), child: Icon(Icons.school, color: Colors.indigo.shade600, size: 24)),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CONNECTED TO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade400, letterSpacing: 1)),
                                  Text(_connectedSchool, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text('TEACHER USERNAME', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
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
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.indigo.shade400, width: 2)),
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
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.indigo.shade400, width: 2)),
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
                            backgroundColor: Colors.indigo.shade600,
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
