import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;
import 'dart:io' show Platform;

class TaskManagerLoginScreen extends StatefulWidget {
  const TaskManagerLoginScreen({super.key});

  @override
  State<TaskManagerLoginScreen> createState() => _TaskManagerLoginScreenState();
}

class _TaskManagerLoginScreenState extends State<TaskManagerLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  String _errorText = '';
  String _schoolCode = '';

  @override
  void initState() {
    super.initState();
    _loadSchoolCode();
  }

  Future<void> _loadSchoolCode() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Auto-login logic: If teacher is already logged in, skip login screen
    final taskId = prefs.getString('TASK_MANAGER_ID');
    if (taskId != null && taskId.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/task_manager');
        return; // Stop further execution since we are navigating away
      }
    }

    setState(() {
      _schoolCode = prefs.getString('SELECTED_SCHOOL') ?? 'Unknown School';
    });
  }

  Future<void> _login({bool forceOverride = false}) async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Please enter both Username and Password');
      return;
    }

    if (_isLoading) return; // Prevent double-tap
    setState(() {
      _isLoading = true;
      _errorText = '';
    });

    try {
      final response = await http.post(
        Uri.parse('https://atteni-otp.piyushassudani.in/api/tasks/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final user = data['user'];

        // Verify school code matches (Optional security check)
        if (user['school_code'] != _schoolCode && user['school_code'] != 'ALL') {
           setState(() => _errorText = 'User does not belong to $_schoolCode');
           return;
        }

        // Multi-device session check
        final safeUsername = username.replaceAll('.', '_').replaceAll('#', '_').replaceAll('\$', '_').replaceAll('[', '_').replaceAll(']', '_');
        final db = FirebaseDatabase.instance.ref();
        final sessionRef = db.child('artifacts/student-system-v2/public/data/system_auth/task_manager_sessions/$safeUsername');
        
        if (!forceOverride) {
          final snap = await sessionRef.get();
          if (snap.exists) {
            final existingData = snap.value as Map<dynamic, dynamic>;
            final lastActive = existingData['lastActive'] as int? ?? 0;
            final isStale = DateTime.now().millisecondsSinceEpoch - lastActive > 24 * 60 * 60 * 1000;
            
            if (!isStale) {
              if (mounted) {
                setState(() => _isLoading = false);
                final shouldOverride = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Already Logged In'),
                    content: Text('This account is currently active on another device (${existingData['deviceInfo'] ?? 'Unknown'}).\n\nDo you want to log out the other device and continue here?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true), 
                        child: const Text('Logout Other Device', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                
                if (shouldOverride == true) {
                  return _login(forceOverride: true);
                } else {
                  return;
                }
              }
            }
          }
        }
        
        final deviceId = '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}';
        String deviceInfo = kIsWeb ? 'Web Browser' : (Platform.isAndroid ? 'Android App' : (Platform.isIOS ? 'iOS App' : 'Unknown Device'));
        
        await sessionRef.set({
          'deviceId': deviceId,
          'deviceInfo': deviceInfo,
          'lastActive': ServerValue.timestamp,
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('TASK_MANAGER_ID', username);
        await prefs.setString('TASK_MANAGER_NAME', user['name'] ?? username);
        await prefs.setString('TASK_MANAGER_DEVICE_ID', deviceId);
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/task_manager');
        }
      } else {
        final errData = json.decode(response.body);
        setState(() => _errorText = errData['error'] ?? 'Invalid credentials');
      }
    } catch (e) {
      setState(() => _errorText = 'Network Error. Is the backend running?');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blueGrey.shade900),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/staff_login');
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
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
                        child: Icon(Icons.assignment_turned_in, color: Colors.indigo.shade600),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Daily Planner', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                            Text('Login to view & edit tasks', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B))),
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

                  Text('USERNAME', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    decoration: _inputDecoration('Enter your Task ID'),
                  ),
                  const SizedBox(height: 24),
                  
                  Text('PASSWORD', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: _inputDecoration('••••••••').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off, color: Colors.grey.shade400),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Login to Tasks', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.blueGrey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.indigo.shade400, width: 2)),
    );
  }
}
