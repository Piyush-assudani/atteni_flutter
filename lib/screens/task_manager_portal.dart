import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';

class TaskManagerPortal extends StatefulWidget {
  const TaskManagerPortal({super.key});

  @override
  State<TaskManagerPortal> createState() => _TaskManagerPortalState();
}

class _TaskManagerPortalState extends State<TaskManagerPortal> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _teacherName = '';
  StreamSubscription<DatabaseEvent>? _sessionSubscription;

  final List<String> _classes = ['Vacant Period', 'Nursery', 'LKG', 'UKG', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];
  final List<String> _sections = ['A', 'B', 'C', 'D'];

  // State for 8 periods
  // Each period is a Map: {'class': null, 'section': null, 'subject': '', 'topic': ''}
  List<Map<String, dynamic>> _periods = [];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _saveLastOpened();
    _initializeEmptyPeriods();
    _checkLockStatus();
  }
  
  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final taskId = prefs.getString('TASK_MANAGER_ID');
    final name = prefs.getString('TASK_MANAGER_NAME') ?? 'Teacher';
    if (taskId == null || taskId.isEmpty) {
      if (mounted) Navigator.pushReplacementNamed(context, '/task_manager_login');
    } else {
      if (mounted) {
        setState(() {
          _teacherName = name;
        });
      }
      _fetchData();
      _listenForSessionOverride(taskId);
    }
  }

  void _listenForSessionOverride(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final currentDeviceId = prefs.getString('TASK_MANAGER_DEVICE_ID');
    if (currentDeviceId == null) return;
    
    final safeUsername = username.replaceAll('.', '_').replaceAll('#', '_').replaceAll('\$', '_').replaceAll('[', '_').replaceAll(']', '_');
    final db = FirebaseDatabase.instance.ref();
    
    _sessionSubscription = db.child('artifacts/student-system-v2/public/data/system_auth/task_manager_sessions/$safeUsername').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final remoteDeviceId = data['deviceId'];
        if (remoteDeviceId != null && remoteDeviceId != currentDeviceId) {
          // Session overridden by another device
          _sessionSubscription?.cancel();
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('Session Expired'),
                content: const Text('Your account was logged in from another device. You have been securely logged out here.'),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _logout();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _saveLastOpened() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('LAST_OPENED', 'task_manager');
  }

  void _initializeEmptyPeriods() {
    _periods = List.generate(8, (index) => {
      'class': null,
      'section': null,
      'subject': '',
      'topic': '',
    });
  }

  bool get _isLocked {
    final now = DateTime.now();
    final limit = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final today = DateTime(now.year, now.month, now.day);

    if (selected.weekday == DateTime.sunday) return true;
    if (selected.isBefore(limit)) return true; // Older than 6 days locked
    if (selected.isAfter(today)) return true; // Future locked
    
    return false;
  }

  void _checkLockStatus() {
    setState(() {}); // trigger rebuild to update lock status
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 6)), // Only last 6 days
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade600,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _checkLockStatus();
      _fetchData();
    }
  }



  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final teacherEmail = prefs.getString('TASK_MANAGER_ID');
      if (teacherEmail == null) return;

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await http.get(
        Uri.parse('https://atteni-otp.piyushassudani.in/api/tasks/get?teacher_id=$teacherEmail&date=$dateStr'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        if (resData['success'] == true && resData['data'] != null) {
          final fetchedPeriods = List<Map<String, dynamic>>.from(resData['data']['periods']);
          setState(() {
            _periods = fetchedPeriods;
          });
        } else {
          _initializeEmptyPeriods();
        }
      } else {
        _initializeEmptyPeriods();
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      _initializeEmptyPeriods();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveData() async {
    if (_isLoading) return; // Prevent double-tap race condition
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final teacherEmail = prefs.getString('TASK_MANAGER_ID') ?? 'unknown';
      final schoolCode = prefs.getString('SELECTED_SCHOOL') ?? 'unknown';
      
      final payload = {
        'teacher_id': teacherEmail,
        'school_code': schoolCode,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'periods': _periods,
      };

      final response = await http.post(
        Uri.parse('https://atteni-otp.piyushassudani.in/api/tasks/save'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Tasks saved successfully!'), backgroundColor: Colors.green.shade600),
          );
        }
      } else if (response.statusCode == 403) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Your account has been deactivated. Logging out...'), backgroundColor: Colors.red.shade600),
          );
        }
        _logout();
      } else {
        throw Exception('Failed to save tasks: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade600),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('TASK_MANAGER_ID');
    await prefs.remove('TASK_MANAGER_NAME');
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/task_manager_login');
    }
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Text('Settings', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.5)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.calendar_today, color: Colors.blueAccent, size: 20),
                ),
                title: Text('Change Date', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1E293B))),
                onTap: () {
                  Navigator.pop(ctx);
                  _selectDate(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.privacy_tip, color: Colors.green, size: 20),
                ),
                title: Text('Privacy Policy', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1E293B))),
                onTap: () {
                  Navigator.pop(ctx);
                  _showWebDialog(context, 'https://atteni-otp.piyushassudani.in/Atteni_privacypolicies/index.html', 'Privacy Policy');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                ),
                title: Text('About Developer', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1E293B))),
                onTap: () {
                  Navigator.pop(ctx);
                  _showWebDialog(context, 'https://piyushassudani.in', 'About Developer');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.lock_reset, color: Colors.purple, size: 20),
                ),
                title: Text('Change Password', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1E293B))),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChangePasswordDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.devices, color: Colors.teal, size: 20),
                ),
                title: Text('Active Logins', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1E293B))),
                onTap: () {
                  Navigator.pop(ctx);
                  _showActiveLoginsDialog();
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Divider(height: 24, color: Color(0xFFE2E8F0)),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.logout, color: Colors.red, size: 20),
                ),
                title: Text('Logout', style: GoogleFonts.plusJakartaSans(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 15)),
                onTap: () {
                  Navigator.pop(ctx);
                  _logout();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showWebDialog(BuildContext context, String url, String title) {
    final WebViewController controller = WebViewController()
      ..loadRequest(Uri.parse(url));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.sizeOf(ctx).width * 0.9,
            height: MediaQuery.sizeOf(ctx).height * 0.8,
            child: WebViewWidget(controller: controller),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showActiveLoginsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('TASK_MANAGER_ID');
    if (username == null) return;
    
    final safeUsername = username.replaceAll('.', '_').replaceAll('#', '_').replaceAll('\$', '_').replaceAll('[', '_').replaceAll(']', '_');
    final db = FirebaseDatabase.instance.ref();
    final snap = await db.child('artifacts/student-system-v2/public/data/system_auth/task_manager_sessions/$safeUsername').get();
    
    String deviceInfo = 'None';
    String deviceId = '';
    if (snap.exists) {
      final data = snap.value as Map<dynamic, dynamic>;
      deviceInfo = data['deviceInfo'] ?? 'Unknown';
      deviceId = data['deviceId'] ?? '';
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Active Session'),
          content: Text('Your account is currently logged in on:\n\nDevice: $deviceInfo\nSession ID: $deviceId'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    }
  }

  void _showChangePasswordDialog() {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    bool isUpdating = false;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String errorText = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change Password',
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your new password below.',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: passController,
                    obscureText: obscureNew,
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black87, width: 1.5)),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black87, width: 1.5)),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                  if (errorText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(errorText, style: GoogleFonts.inter(color: Colors.red.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isUpdating ? null : () async {
                          final newPass = passController.text;
                          final confirmPass = confirmController.text;
                          
                          if (newPass.isEmpty || confirmPass.isEmpty) {
                            setDialogState(() => errorText = 'Please fill both fields.');
                            return;
                          }
                          if (newPass != confirmPass) {
                            setDialogState(() => errorText = 'Passwords do not match.');
                            return;
                          }
                          
                          setDialogState(() {
                            isUpdating = true;
                            errorText = '';
                          });
                          
                          final prefs = await SharedPreferences.getInstance();
                          final username = prefs.getString('TASK_MANAGER_ID');
                          
                          try {
                            final response = await http.post(
                              Uri.parse('https://atteni-otp.piyushassudani.in/api/tasks/users/update_password'),
                              headers: {'Content-Type': 'application/json'},
                              body: json.encode({'username': username, 'new_password': newPass}),
                            );
                            
                            if (response.statusCode == 200) {
                              Navigator.pop(ctx);
                              showDialog(
                                context: this.context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Text('Success', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  content: Text(
                                    'Your password has been changed to "$newPass"!',
                                    style: GoogleFonts.inter(fontSize: 15),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              setDialogState(() {
                                errorText = 'Failed to update password.';
                                isUpdating = false;
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              errorText = 'Network error occurred.';
                              isUpdating = false;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isUpdating 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Update Password', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pushReplacementNamed(context, '/staff');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/staff');
            },
          ),
          backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          (_teacherName != null && _teacherName!.isNotEmpty) ? 'Hello, $_teacherName 👋' : '',
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: TextButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/staff');
              },
              icon: const Icon(Icons.directions_bus, size: 16),
              label: Text('Vehicle Attendance', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black54, size: 20),
            onPressed: _showSettingsPanel,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Minimalist Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Daily Planner',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (_isLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: Colors.red.shade400, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _selectedDate.weekday == DateTime.sunday 
                      ? 'Sunday is a holiday. Data entry is locked.'
                      : 'Past week data is locked for editing.',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.red.shade700),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: 8,
              itemBuilder: (context, index) {
                return _buildPeriodCard(index, isMobile);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isLocked ? null : FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveData,
        backgroundColor: Colors.black87,
        elevation: 2,
        icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check, size: 18),
        label: Text('Save Planner', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14)),
      ),
      ),
    );
  }
  Widget _buildPeriodCard(int index, bool isMobile) {
    final period = _periods[index];
    final isVacant = period['class'] == 'Vacant Period';
    final needsSection = !['Vacant Period', 'Nursery', 'LKG', 'UKG'].contains(period['class']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Text(
                  'Period ${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 14, 
                    fontWeight: FontWeight.w600, 
                    color: isVacant ? Colors.grey.shade400 : Colors.black87
                  ),
                ),
                if (isVacant) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Vacant', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                  ),
                ]
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildClassDropdown(period)),
                            if (needsSection) ...[
                              const SizedBox(width: 16),
                              Expanded(child: _buildSectionDropdown(period)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                      _buildSubjectField(period, isVacant),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildClassDropdown(period)),
                      if (needsSection) ...[
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildSectionDropdown(period)),
                      ],
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: _buildSubjectField(period, isVacant)),
                    ],
                  ),
          ),
          if (!isVacant)
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Topic Taught', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
                  const SizedBox(height: 8),
                  TextFormField(
                    enabled: !_isLocked,
                    initialValue: period['topic'],
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                    decoration: _inputDecoration().copyWith(
                      hintText: 'Briefly describe the topic...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                    ),
                    onChanged: (val) => period['topic'] = val,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.black87, width: 1.5)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade200)),
      isDense: true,
    );
  }

  Widget _buildClassDropdown(Map<String, dynamic> period) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: period['class'],
          icon: const Icon(Icons.unfold_more, size: 16, color: Colors.black54),
          decoration: _inputDecoration(),
          style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
          items: _classes.map((c) => DropdownMenuItem(
            value: c, 
            child: Text(c, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: _isLocked ? null : (val) {
            setState(() {
              period['class'] = val;
              if (!['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'].contains(val)) {
                period['section'] = null;
              }
              if (val == 'Vacant Period') {
                period['subject'] = '';
                period['topic'] = '';
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildSectionDropdown(Map<String, dynamic> period) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Section', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: period['section'],
          icon: const Icon(Icons.unfold_more, size: 16, color: Colors.black54),
          decoration: _inputDecoration(),
          style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
          items: _sections.map((s) => DropdownMenuItem(
            value: s, 
            child: Text(s, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: _isLocked ? null : (val) => setState(() => period['section'] = val),
        ),
      ],
    );
  }

  Widget _buildSubjectField(Map<String, dynamic> period, bool isVacant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subject', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
        const SizedBox(height: 8),
        TextFormField(
          enabled: !_isLocked && !isVacant,
          initialValue: period['subject'],
          style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
          decoration: _inputDecoration().copyWith(
            hintText: isVacant ? 'N/A' : 'e.g. Mathematics',
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
          ),
          onChanged: (val) => period['subject'] = val,
        ),
      ],
    );
  }
}
