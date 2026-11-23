import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../widgets/premium_toast.dart';
import '../widgets/premium_alert.dart';
import '../widgets/parent/live_journey_tracker.dart';

enum ParentStage { login, signup, dashboard, studentDetail, directSearch }

class ParentPortalScreen extends StatefulWidget {
  const ParentPortalScreen({super.key});

  @override
  State<ParentPortalScreen> createState() => _ParentPortalScreenState();
}

class _ParentPortalScreenState extends State<ParentPortalScreen> {

  ParentStage _currentStage = ParentStage.login;
  static bool _tipShown = false;

  // Controllers
  final TextEditingController _loginMobileCtrl = TextEditingController();
  final TextEditingController _loginPassCtrl = TextEditingController();
  final TextEditingController _signupMobileCtrl = TextEditingController();
  final TextEditingController _otpCtrl1 = TextEditingController();
  final TextEditingController _otpCtrl2 = TextEditingController();
  final TextEditingController _otpCtrl3 = TextEditingController();
  final TextEditingController _otpCtrl4 = TextEditingController();

  bool _obscureLoginPass = true;
  bool _isLocked = false;
  bool _legacyParentSearch = true;
  int _signupStep = 1;
  bool _isLoading = false;

  final TextEditingController _searchNameCtrl = TextEditingController();
  final TextEditingController _searchClassCtrl = TextEditingController();
  final TextEditingController _searchSectionCtrl = TextEditingController();
  final TextEditingController _searchSrNoCtrl = TextEditingController();

  List<Map<dynamic, dynamic>> _myChildren = [];
  Map<dynamic, dynamic>? _selectedChild;
  
  // History & Stats
  bool _isHistoryLoaded = false;
  bool _isLoadingHistory = false;
  Map<String, dynamic> _historyData = {};
  Map<String, dynamic> _vehicleDetails = {};
  int _statPresent = 0;
  int _statAbsent = 0;
  String _statRate = "0%";
  List<FlSpot> _trendSpots = [];
  double _journeyDurationMins = 45.0;
  String _schoolId = 'DPS';

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
    if (!_tipShown) {
      _tipShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PremiumAlert.show(
          context,
          title: '💡 Quick Guidance',
          text: 'New User? Sign Up First.\nAlready have an account? Login.',
          confirmText: 'Got It!',
        );
      });
    }
  }

  Future<void> _checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _schoolId = prefs.getString('SELECTED_SCHOOL') ?? 'DPS';
    });
    _checkSystemLock();
    
    // Auto-fetch toggle value directly to prevent UI flash
    final ref = FirebaseService().getBaseRef(_schoolId).child('system/legacyParentSearch');
    final snap = await ref.get();
    if (snap.exists) {
      _legacyParentSearch = snap.value as bool;
    }
    
    if (!_legacyParentSearch) {
      final savedData = prefs.getString('atteni_tracked_students');
      if (savedData != null && savedData.isNotEmpty) {
        try {
          List<dynamic> parsed = jsonDecode(savedData);
          List<Map<dynamic, dynamic>> children = [];
          for (var item in parsed) {
            children.add(Map<dynamic, dynamic>.from(item));
          }
          if (children.isNotEmpty) {
            setState(() {
              _myChildren = children;
              _currentStage = ParentStage.dashboard;
            });
            return;
          }
        } catch (e) {
          // Fallback if parsing fails
        }
      }
      setState(() {
        _currentStage = ParentStage.directSearch;
      });
      return;
    }

    final parentMobile = prefs.getString('PARENT_MOBILE');
    if (parentMobile != null && parentMobile.isNotEmpty) {
      _loadChildren(parentMobile);
      setState(() {
        _currentStage = ParentStage.dashboard;
        _signupMobileCtrl.text = parentMobile; // Store the mobile for reuse
      });
    }
  }

  Future<void> _fetchChildBySrNo(String srNo) async {
    final ref = FirebaseService().getBaseRef(_schoolId).child('students');
    final snap = await ref.get();
    if (snap.exists) {
      final data = snap.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final dbSrNo = (entry.value['srNo'] ?? entry.value['scholar_no'] ?? '').toString();
        if (dbSrNo.toLowerCase() == srNo.toLowerCase()) {
          setState(() {
            _selectedChild = {...entry.value, 'id': entry.key};
            _currentStage = ParentStage.studentDetail;
          });
          _fetchVehicleDetails(entry.value['vehicle'] ?? '');
          _loadHistoryForSelectedChild();
          return;
        }
      }
    }
    // If not found, revert to search
    setState(() => _currentStage = ParentStage.directSearch);
  }

  void _checkSystemLock() {
    FirebaseService()
        .getBaseRef(_schoolId)
        .child('system_auth/access_controls/$_schoolId')
        .onValue
        .listen((event) {
          if (event.snapshot.exists) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null && data['maintenance'] == true) {
              setState(() => _isLocked = true);
            }
          }
        });
        
    FirebaseService()
        .getBaseRef(_schoolId)
        .child('system/legacyParentSearch')
        .onValue
        .listen((event) {
          if (event.snapshot.exists) {
            final val = event.snapshot.value as bool;
            if (mounted && _legacyParentSearch != val) {
              setState(() {
                _legacyParentSearch = val;
                if (!val && _currentStage != ParentStage.studentDetail) {
                  _currentStage = ParentStage.directSearch;
                } else if (val && _currentStage == ParentStage.directSearch) {
                  _currentStage = ParentStage.login;
                }
              });
            }
          }
        });
  }

  Future<void> _handleSendOtp() async {
    final phone = _signupMobileCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10) {
      PremiumAlert.showError(
        context,
        title: 'Invalid Mobile Number',
        text: 'Please enter a valid 10-digit mobile number registered with the school.',
      );
      return;
    }
    if (_isLoading) return; // Prevent double-tap
    setState(() => _isLoading = true);
    final res = await ApiService.requestOTPWithDetails(phone);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (res['success'] == true) {
      PremiumToast.showSuccess(context, 'OTP sent to WhatsApp successfully!');
      setState(() => _signupStep = 2);
    } else {
      PremiumAlert.showError(
        context,
        title: 'Unable to Send OTP',
        text: res['message'] ?? 'Failed to send OTP. Please try again.',
      );
    }
  }

  Future<void> _handleVerifyOtp() async {
    final code = (_otpCtrl1.text + _otpCtrl2.text + _otpCtrl3.text + _otpCtrl4.text).trim();
    if (code.length != 4) {
      PremiumToast.showError(context, 'Please enter the complete 4-digit OTP');
      return;
    }
    if (_isLoading) return; // Prevent double-tap

    setState(() => _isLoading = true);
    final phone = _signupMobileCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    final res = await ApiService.verifyOTP(phone, code);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', 'parent');
      await prefs.setString('PARENT_MOBILE', phone);

      _loadChildren(phone);
      setState(() {
        _currentStage = ParentStage.dashboard;
        _signupStep = 1;
      });
    } else {
      PremiumAlert.showError(
        context,
        title: 'Verification Failed',
        text: res['message'] ?? 'Invalid OTP code. Please check and try again.',
      );
    }
  }

  Future<void> _loadChildren(String phone) async {
    final ref = FirebaseService().getBaseRef(_schoolId).child('students');
    final snap = await ref.get();
    if (snap.exists && snap.value is Map) {
      final data = snap.value as Map<dynamic, dynamic>;
      List<Map<dynamic, dynamic>> children = [];
      data.forEach((key, value) {
        if (value is Map) {
          final pMobile = value['parentMobile']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
          final pContact = value['contact']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
          final pPhone = value['parent_phone']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
          List<dynamic> pPhones = [];
          if (value['parentPhones'] is List) {
            pPhones = value['parentPhones'];
          } else if (value['parentPhones'] != null) {
            pPhones = [value['parentPhones']];
          }
          final hasMatch = (value['parentMobile'] == phone) ||
              (pMobile.isNotEmpty && pMobile.endsWith(phone)) ||
              (pContact.isNotEmpty && pContact.endsWith(phone)) ||
              (pPhone.isNotEmpty && pPhone.endsWith(phone)) ||
              pPhones.any((p) => p.toString().replaceAll(RegExp(r'\D'), '').endsWith(phone));
          if (hasMatch) {
            children.add({...value, 'id': key});
          }
        }
      });
      setState(() {
        _myChildren = children;
      });
    }
  }

  Future<void> _handleDirectSearch() async {
    final sNameRaw = _searchNameCtrl.text.trim().toLowerCase();
    final sClassRaw = _searchClassCtrl.text.trim().toUpperCase();
    final sSection = _searchSectionCtrl.text.trim().toLowerCase();
    final sSrNo = _searchSrNoCtrl.text.trim();
    
    if (sNameRaw.isEmpty || sClassRaw.isEmpty || sSrNo.isEmpty) {
      PremiumAlert.showError(
        context,
        title: 'Missing Details',
        text: 'Please enter Student Name, Class, and Scholar/Sr Number to search.',
      );
      return;
    }

    if (_isLoading) return; // Prevent double-tap
    setState(() => _isLoading = true);
    
    try {
      final ref = FirebaseService().getBaseRef(_schoolId).child('students');
      final snap = await ref.get().timeout(const Duration(seconds: 10));
      
      if (snap.exists && snap.value is Map) {
        final data = snap.value as Map<dynamic, dynamic>;
        
        // We will look for an exact Sr No match first
        for (var entry in data.entries) {
          final d = entry.value;
          if (d is! Map) continue;
          final dbSrNo = (d['srNo'] ?? d['scholar_no'] ?? '').toString().trim();
          if (dbSrNo.toLowerCase() == sSrNo.toLowerCase()) {
            // Additional validation for privacy
            final dbClass = (d['class'] ?? '').toString().toUpperCase();
            final dbSection = (d['section'] ?? 'a').toString().toLowerCase();
            final dbName = (d['name'] ?? '').toString().trim().toLowerCase();
            
            final normalizedSearchSec = sSection.isEmpty ? 'a' : sSection;
            
            // Match class, section and loosely name
            if (dbClass == sClassRaw && dbSection == normalizedSearchSec) {
              final dbFirstName = dbName.isNotEmpty ? dbName.split(' ')[0] : '';
              final sFirstName = sNameRaw.isNotEmpty ? sNameRaw.split(' ')[0] : '';
              if (dbName.contains(sNameRaw) || (dbFirstName.isNotEmpty && dbFirstName == sFirstName) || sNameRaw.contains(dbFirstName)) {
                // Found!
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('userRole', 'parent');
                
                final newChild = {...d, 'id': entry.key};
                
                // Add to local children list if not already there
                if (!_myChildren.any((c) => c['id'] == entry.key)) {
                  _myChildren.add(newChild);
                  await prefs.setString('atteni_tracked_students', jsonEncode(_myChildren));
                }
                
                if (mounted) {
                  setState(() {
                    _currentStage = ParentStage.dashboard;
                    _isLoading = false;
                  });
                  PremiumToast.showSuccess(context, 'Student record connected successfully!');
                }
                return;
              }
            }
          }
        }
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        PremiumAlert.showError(
          context,
          title: 'Student Not Found',
          text: 'No student found matching Scholar No: $sSrNo in Class $sClassRaw. Please verify the credentials with school admin.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PremiumAlert.showError(
          context,
          title: 'Search Connection Error',
          text: 'Unable to reach the school database. Please check your internet connection and try again.',
        );
      }
    }
  }

  void _switchStage(ParentStage stage) {
    setState(() {
      _currentStage = stage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBodyBehindAppBar: true,
      body: SafeArea(
            child: _isLocked
                ? _buildLockOverlay()
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 24.0,
                    ),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        if (!_legacyParentSearch)
                           if (_currentStage == ParentStage.directSearch)
                              _buildDirectSearchStage()
                           else if (_currentStage == ParentStage.studentDetail)
                              _buildStudentDetailStage()
                           else if (_currentStage == ParentStage.dashboard)
                              _buildDashboardStage()
                           else
                              _buildDirectSearchStage() // fallback
                        else ...[
                          if (_currentStage == ParentStage.login || _currentStage == ParentStage.signup)
                            _buildAuthStage()
                          else if (_currentStage == ParentStage.dashboard)
                            _buildDashboardStage()
                          else if (_currentStage == ParentStage.studentDetail)
                            _buildStudentDetailStage(),
                        ],
                      ],
                    ),
                  ),
          ),
    );
  }

  Widget _buildDirectSearchStage() {
    return _buildGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find Your Child',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please enter the student details exactly as registered.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _searchSrNoCtrl,
            label: 'Scholar No / Sr No',
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _searchNameCtrl,
            label: 'Child\'s Name (First Name)',
            icon: Icons.person_outline,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildTextField(
                  controller: _searchClassCtrl,
                  label: 'Class (e.g. 10)',
                  icon: Icons.class_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _searchSectionCtrl,
                  label: 'Sec (Opt)',
                  icon: Icons.group_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildPremiumButton(
            label: 'Search Student',
            onPressed: _handleDirectSearch,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black87.withValues(alpha: 0.03)),
            boxShadow: [
              BoxShadow(
                color: Colors.black87.withValues(alpha: 0.05),
                blurRadius: 5,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'Enter $label',
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.black87.withValues(alpha: 0.03)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.red.shade200, blurRadius: 5),
                    ],
                  ),
                  child: Icon(
                    Icons.lock_person,
                    color: Colors.red.shade600,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Access Restricted',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The Parent Portal is currently restricted by the system administrator.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Return to Dashboard',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    color: Colors.black87,
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Go Back',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.03),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: Image.asset('logo.webp', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'ATTENI',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'v32.0.0',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_currentStage != ParentStage.login &&
              _currentStage != ParentStage.signup)
            InkWell(
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('PARENT_MOBILE');
                await prefs.remove('userRole');
                setState(() => _currentStage = ParentStage.login);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.power_settings_new,
                      color: Colors.red.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Logout',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final defaultPadding = EdgeInsets.all(screenWidth < 360 ? 16 : 24);
    return Container(
      padding: padding ?? defaultPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: kIsWeb ? child : BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: child,
        ),
      ),
    );
  }

  Widget _buildPremiumInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? _obscureLoginPass : false,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade700,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: Colors.grey.shade500,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscureLoginPass
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () => setState(
                        () => _obscureLoginPass = !_obscureLoginPass,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumButton({
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildAuthStage() {
    final isLogin = _currentStage == ParentStage.login;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _currentStage = ParentStage.login),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isLogin ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isLogin
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 5,
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Login',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: isLogin
                            ? Colors.black87
                            : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _currentStage = ParentStage.signup;
                    _signupStep = 1;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !isLogin ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: !isLogin
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 5,
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign Up',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: !isLogin
                            ? Colors.black87
                            : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildGlassCard(
          child: isLogin ? _buildLoginForm() : _buildSignupForm(),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.black54,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Welcome Back',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Log in to view your child\'s tracking status.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info, color: Colors.black87, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Old user? ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Enter your mobile and password to login.\n',
                      ),
                      TextSpan(
                        text: 'New user? ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: 'Switch to the Sign Up tab above.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildPremiumInput(
          label: 'MOBILE NUMBER (WITHOUT +91)',
          hint: 'Enter 10-digit mobile number',
          controller: _loginMobileCtrl,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildPremiumInput(
          label: 'PASSWORD',
          hint: 'Enter your password',
          controller: _loginPassCtrl,
          isPassword: true,
        ),
        const SizedBox(height: 32),
        _buildPremiumButton(
          label: 'Login',
          isLoading: _isLoading,
          onPressed: () async {
            final mobile = _loginMobileCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
            final pass = _loginPassCtrl.text.trim();

            if (mobile.length != 10) {
              PremiumAlert.showError(
                context,
                title: 'Invalid Mobile Number',
                text: 'Please enter a valid 10-digit mobile number.',
              );
              return;
            }
            if (pass.isEmpty) {
              PremiumAlert.showError(
                context,
                title: 'Password Required',
                text: 'Please enter your password.',
              );
              return;
            }

            if (_isLoading) return;
            setState(() => _isLoading = true);

            try {
              final dbRef = FirebaseService().getBaseRef(_schoolId);
              final accSnap = await dbRef.child('parent_accounts/$mobile').get().timeout(const Duration(seconds: 10));

              if (accSnap.exists && accSnap.value is Map) {
                final accData = accSnap.value as Map<dynamic, dynamic>;
                if (accData['password'] != null && accData['password'].toString().isNotEmpty && accData['password'].toString() != pass) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    PremiumAlert.showError(
                      context,
                      title: 'Incorrect Password',
                      text: 'The password you entered is incorrect. Please check and try again.',
                    );
                  }
                  return;
                }
              } else {
                // Backward compatibility: If parent_accounts doesn't exist yet, check if student is registered with this phone
                final stuSnap = await dbRef.child('students').get().timeout(const Duration(seconds: 10));
                bool hasLinkedStudent = false;
                if (stuSnap.exists && stuSnap.value is Map) {
                  final stuData = stuSnap.value as Map<dynamic, dynamic>;
                  for (var s in stuData.values) {
                    if (s is Map) {
                      final pMob = (s['parentMobile'] ?? s['contact'] ?? s['parent_phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
                      if (pMob.endsWith(mobile)) {
                        hasLinkedStudent = true;
                        break;
                      }
                      if (s['parentPhones'] is List) {
                        for (var p in s['parentPhones']) {
                          if (p.toString().replaceAll(RegExp(r'\D'), '').endsWith(mobile)) {
                            hasLinkedStudent = true;
                            break;
                          }
                        }
                      }
                      if (hasLinkedStudent) break;
                    }
                  }
                }

                if (!hasLinkedStudent) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    PremiumAlert.showError(
                      context,
                      title: 'Account Not Found',
                      text: 'No student or parent account found registered with mobile number $mobile in this school. Please register via Sign Up or verify with school admin.',
                    );
                  }
                  return;
                }
              }

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('userRole', 'parent');
              await prefs.setString('PARENT_MOBILE', mobile);
              
              await _loadChildren(mobile);

              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _currentStage = ParentStage.dashboard;
                  _signupMobileCtrl.text = mobile;
                });
                PremiumToast.showSuccess(context, 'Logged in successfully!');
              }
            } catch (e) {
              if (mounted) {
                setState(() => _isLoading = false);
                PremiumAlert.showError(
                  context,
                  title: 'Login Error',
                  text: 'Could not connect to verify account. Please check your network and try again.',
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    if (_signupStep == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              'Create Parent Account',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Register to track your child\'s real-time school transit.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          _buildPremiumInput(
            label: 'MOBILE NUMBER (WITHOUT +91)',
            hint: 'Enter 10-digit number without +91',
            controller: _signupMobileCtrl,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 32),
          _buildPremiumButton(
            label: 'Continue',
            isLoading: _isLoading,
            onPressed: _handleSendOtp,
          ),
        ],
      );
    } else if (_signupStep == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              'Create Parent Account',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'An OTP has been sent to your registered mobile number.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOtpBox(_otpCtrl1),
              _buildOtpBox(_otpCtrl2),
              _buildOtpBox(_otpCtrl3),
              _buildOtpBox(_otpCtrl4),
            ],
          ),
          const SizedBox(height: 32),
          _buildPremiumButton(
            label: 'Verify OTP',
            isLoading: _isLoading,
            onPressed: _handleVerifyOtp,
          ),
        ],
      );
    }
    return Container();
  }

  Widget _buildOtpBox(TextEditingController ctrl) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boxSize = screenWidth < 360 ? 46.0 : 54.0;
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: ctrl,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: GoogleFonts.inter(
          fontSize: screenWidth < 360 ? 20 : 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (val) {
          if (val.isNotEmpty) FocusScope.of(context).nextFocus();
        },
      ),
    );
  }

  Widget _buildDashboardStage() {
    String parentDisplayName = 'Authorized Guardian';
    if (_myChildren.isNotEmpty) {
      final firstChild = _myChildren.first;
      final father = firstChild['father'] ?? firstChild['fatherName'] ?? firstChild['parentName'];
      if (father != null && father.toString().trim().isNotEmpty) {
        parentDisplayName = father.toString().trim();
      } else if (firstChild['name'] != null && firstChild['name'].toString().trim().isNotEmpty) {
        parentDisplayName = 'Parent of ${firstChild['name']}';
      }
    } else if (_signupMobileCtrl.text.trim().isNotEmpty) {
      parentDisplayName = 'Parent (${_signupMobileCtrl.text.trim()})';
    }
    final avatarLetter = parentDisplayName.trim().isNotEmpty ? parentDisplayName.trim()[0].toUpperCase() : 'P';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlassCard(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black87.withValues(alpha: 0.03),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    avatarLetter,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PARENT PROFILE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      parentDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildDirectSearchStage(), // Smart Search Block just like parent.html
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MY FAMILY',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 1,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '${_myChildren.length}',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  if (!_legacyParentSearch) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() => _currentStage = ParentStage.directSearch);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black87.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('Add Child', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_myChildren.isEmpty)
          _buildGlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.family_restroom, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No children linked yet.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please contact the school to link your mobile number to your children\'s profiles.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._myChildren.map((child) => _buildChildCard(child)),
      ],
    );
  }

  Widget _buildChildCard(Map<dynamic, dynamic> child) {
    final name = child['name'] ?? 'Unknown';
    final cls = child['class'] ?? '';
    final sec = child['section'] ?? '';
    final van = child['vehicle'] ?? '-';
    final initial = name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildGlassCard(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedChild = child;
              _currentStage = ParentStage.studentDetail;
            });
            _fetchVehicleDetails(child['vehicle'] ?? '');
            _loadHistoryForSelectedChild();
          },
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.black87],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.03),
                      blurRadius: 5,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Class $cls${sec.toString().isNotEmpty ? ' $sec' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            van.toString().isNotEmpty ? van.toString() : 'No Vehicle',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey.shade500, size: 20),
                onPressed: () async {
                  setState(() {
                    _myChildren.removeWhere((c) => c == child);
                  });
                  if (!_legacyParentSearch) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('atteni_tracked_students', jsonEncode(_myChildren));
                  }
                  PremiumToast.show(context, 'Student removed from tracking', isError: false);
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  hoverColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentDetailStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailHeader(),
        const SizedBox(height: 24),
        _buildJourneyTracker(),
        const SizedBox(height: 24),
        if (!_isHistoryLoaded) _buildLoadHistoryButton(),
        if (_isHistoryLoaded) ...[
          _buildParentTourStats(),
          const SizedBox(height: 24),
          _buildDataVisualizations(),
          const SizedBox(height: 24),
          _buildCalendarGrid(),
          const SizedBox(height: 32),
          // GENERATE SMART REPORT BUTTON
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black87, Colors.black87],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black87.withValues(alpha: 0.03),
                  blurRadius: 5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _generateAndPrintPdf,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'GENERATE SMART REPORT (PDF)',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // LOGOUT BUTTON
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade100, width: 2),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                hoverColor: Colors.red.shade50,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('loggedInParent');
                  await prefs.remove('userRole');
                  setState(() => _currentStage = ParentStage.login);
                },
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.power_settings_new, color: Colors.red.shade500, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'LOGOUT',
                        style: GoogleFonts.inter(
                          color: Colors.red.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  Widget _buildDetailHeader() {
    final student = _selectedChild ?? {};
    final name = student['name'] ?? 'Unknown';
    final cls = student['class'] ?? '';
    final sec = student['section'] ?? '';
    final van = student['vehicle'] ?? '-';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _currentStage = _myChildren.isNotEmpty ? ParentStage.dashboard : ParentStage.directSearch;
                });
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Icon(Icons.arrow_back, color: Colors.black54, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _myChildren.isNotEmpty ? 'My Family' : 'Back to Search',
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (!_legacyParentSearch)
              InkWell(
                onTap: () {
                  setState(() {
                    _currentStage = ParentStage.directSearch;
                    _selectedChild = null; // Clear on back
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1, size: 12, color: Colors.black87),
                      const SizedBox(width: 4),
                      Text('Track new child', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _buildGlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.blue, Colors.black87]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.blue.withValues(alpha: 0.03), blurRadius: 5, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text('$cls $sec'.trim(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(color: Colors.black87.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  children: [
                    _buildPremiumInfoRow(Icons.directions_bus_rounded, 'Vehicle', van),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                    _buildPremiumInfoRow(Icons.person_rounded, 'Teacher Incharge', _vehicleDetails['teacher']?.toString().isNotEmpty == true ? _vehicleDetails['teacher'] : 'Not Assigned'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                    _buildPremiumInfoRow(Icons.badge_rounded, 'Driver Name', _vehicleDetails['driver']?.toString().isNotEmpty == true ? _vehicleDetails['driver'] : 'Not Assigned'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                    _buildPremiumInfoRow(Icons.phone_rounded, 'Driver No.', _vehicleDetails['driverMobile']?.toString().isNotEmpty == true ? _vehicleDetails['driverMobile'] : 'Not Assigned'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Icon(icon, size: 16, color: Colors.black87),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600)),
              Text(value, style: GoogleFonts.inter(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJourneyTracker() {
    if (_selectedChild == null || _selectedChild!['id'] == null) {
      return const SizedBox();
    }
    return LiveJourneyTracker(studentId: _selectedChild!['id']);
  }

  Widget _buildLoadHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _isLoadingHistory ? null : _loadHistoryForSelectedChild,
        child: _isLoadingHistory 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text('LOAD HISTORY', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildParentTourStats() {
    return Row(
      children: [
        _buildStatCard('Present', _statPresent.toString(), Colors.green),
        const SizedBox(width: 12),
        _buildStatCard('Absent', _statAbsent.toString(), Colors.red),
        const SizedBox(width: 12),
        _buildStatCard('Rate', _statRate, Colors.black87),
      ],
    );
  }

  Widget _buildStatCard(String title, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)],
        ),
        child: Column(
          children: [
            Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            Text(val, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDataVisualizations() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance Trend', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: _trendSpots.isEmpty 
              ? Center(child: Text('No attendance data available yet', style: GoogleFonts.inter(color: Colors.black54))) 
              : _trendSpots.length == 1 
                ? Center(child: Text('Need at least 2 days of data to show a trend', style: GoogleFonts.inter(color: Colors.black54))) 
                : LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _trendSpots,
                    isCurved: true,
                    color: Colors.black87,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.black87.withValues(alpha: 0.03)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPrintPdf() async {
    if (_selectedChild == null) return;
    final student = _selectedChild!;
    
    final name = student['name'] ?? 'Unknown';
    final cls = student['class'] ?? '';
    final sec = student['section'] ?? '';
    final van = student['vehicle'] ?? 'Not assigned';

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)), // Indigo 600
                child: pw.Column(
                  children: [
                    pw.Text('ATTENI PREMIUM', style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Intelligent Attendance & Journey Tracking System', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              
              // Profile
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(name.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E293B))),
                    pw.SizedBox(height: 4),
                    pw.Text('Class: $cls | Section: $sec', style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF64748B))),
                    pw.Text('Vehicle: $van', style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF64748B))),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Summary Stats
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPdfStatBox('Present Days', _statPresent.toString(), const PdfColor.fromInt(0xFF22C55E)),
                    _buildPdfStatBox('Absent Days', _statAbsent.toString(), const PdfColor.fromInt(0xFFEF4444)),
                    _buildPdfStatBox('Success Rate', _statRate, const PdfColor.fromInt(0xFF4F46E5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              
              // Last 30 days log (simplified version for PDF)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Last 30 Days Activity Log', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E293B))),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          ],
                        ),
                        ..._historyData.entries.map((e) => pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 10))),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8), 
                              child: pw.Text(e.value == 'P' ? 'PRESENT' : 'ABSENT', style: pw.TextStyle(fontSize: 10, color: e.value == 'P' ? const PdfColor.fromInt(0xFF22C55E) : const PdfColor.fromInt(0xFFEF4444)))
                            ),
                          ],
                        )).toList().take(10), // Limit to 10 for demo layout
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${name}_Attendance_Report.pdf',
    );
  }

  pw.Widget _buildPdfStatBox(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF94A3B8))),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final startingWeekday = firstDay.weekday; // 1 = Monday, 7 = Sunday
    
    List<Widget> dayWidgets = [];
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    for (var d in weekDays) {
      dayWidgets.add(Center(child: Text(d, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54))));
    }
    
    int emptyLeadingDays = startingWeekday - 1;
    for (int i = 0; i < emptyLeadingDays; i++) {
      dayWidgets.add(const SizedBox());
    }
    
    for (int i = 1; i <= daysInMonth; i++) {
      String dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${i.toString().padLeft(2, '0')}";
      final dataEntry = _historyData[dateStr];
      String status = '';
      String timeStr = '';
      
      if (dataEntry is Map) {
        status = dataEntry['status'] ?? '';
        timeStr = dataEntry['time'] ?? '';
      } else if (dataEntry is String) {
        status = dataEntry;
      }
      
      Color bgColor = Colors.grey.shade100;
      Color textColor = Colors.black54;
      
      if (status == 'P') {
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
      } else if (status == 'A') {
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
      }
      
      dayWidgets.add(
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(i.toString(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                if (timeStr.isNotEmpty)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(timeStr, style: GoogleFonts.inter(fontSize: 8, color: textColor.withValues(alpha: 0.03))),
                    ),
                  ),
              ],
            ),
          ),
        )
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Calendar', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              InkWell(
                onTap: _isLoadingHistory ? null : _loadHistoryForSelectedChild,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isLoadingHistory 
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Load Data', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: dayWidgets,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.green.shade500, 'Present'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.red.shade500, 'Absent'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.grey.shade200, 'Not marked'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.blueGrey.shade600, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _fetchVehicleDetails(String van) async {
    if (van.isEmpty || van == '-') {
      setState(() => _vehicleDetails = {});
      return;
    }
    final ref = FirebaseService().getBaseRef(_schoolId).child('registered_vehicles/$van');
    final snap = await ref.get();
    if (snap.exists) {
      final data = snap.value as Map<dynamic, dynamic>;
      setState(() {
        _vehicleDetails = {
          'teacher': data['teacher'] ?? 'Not Assigned',
          'driver': data['driver'] ?? 'Not Assigned',
          'driverMobile': data['driverMobile'] ?? 'Not Assigned',
        };
      });
    } else {
      setState(() => _vehicleDetails = {});
    }
  }

  void _loadHistoryForSelectedChild() async {
    if (_selectedChild == null) return;
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final String studentId = _selectedChild!['id'];
      final DateTime today = DateTime.now();
      // Fetch current month and previous month
      final String currentMonth = "${today.year}-${today.month.toString().padLeft(2, '0')}";
      
      // We will just fetch the whole attendance node and filter client-side for simplicity,
      // but if the node is large, we should just query specific dates.
      // Since Realtime Database can't easily query wildcard nested paths, we can either:
      // 1. Fetch all attendance and filter (bad idea).
      // 2. We know the HTML portal does this: loops through all days of the month.
      
      Map<String, dynamic> historyData = {};
      int presentCount = 0;
      int absentCount = 0;
      
      final dbRef = FirebaseService().getBaseRef(_schoolId).child('attendance');
      final snap = await dbRef.get();
      
      if (snap.exists && snap.value != null) {
        final Map<dynamic, dynamic> allAtt = snap.value as Map<dynamic, dynamic>;
        
        allAtt.forEach((dateStr, dateData) {
          if (dateStr.startsWith(currentMonth) && dateData != null && dateData['list'] != null) {
            final list = dateData['list'] as Map<dynamic, dynamic>;
            if (list.containsKey(studentId)) {
              final entry = list[studentId];
              String status = '';
              String timeStr = '';
              
              if (entry is String) {
                status = entry;
              } else if (entry is Map) {
                status = entry['status'] ?? '';
                if (entry['markedAt'] != null) {
                  final m = entry['markedAt'];
                  try {
                    if (m is String) {
                      final dt = DateTime.parse(m).toLocal();
                      timeStr = "${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')}";
                    } else if (m is int) {
                      final dt = DateTime.fromMillisecondsSinceEpoch(m).toLocal();
                      timeStr = "${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')}";
                    }
                  } catch(e) {}
                }
              }
              
              // Fallback to separate markedAt node if exists
              if (timeStr.isEmpty && dateData['markedAt'] != null) {
                final ma = dateData['markedAt'] as Map<dynamic, dynamic>;
                if (ma.containsKey(studentId)) {
                  final m = ma[studentId];
                  try {
                    if (m is String) {
                      final dt = DateTime.parse(m).toLocal();
                      timeStr = "${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')}";
                    } else if (m is int) {
                      final dt = DateTime.fromMillisecondsSinceEpoch(m).toLocal();
                      timeStr = "${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')}";
                    }
                  } catch(e) {}
                }
              }
              
              bool isP = status == 'P' || status == 'Present' || status == 'true' || status.toLowerCase().startsWith('p');
              historyData[dateStr] = {
                'status': isP ? 'P' : 'A',
                'time': timeStr
              };
              
              if (isP) {
                presentCount++;
              } else {
                absentCount++;
              }
            }
          }
        });
      }
      
      int totalDays = presentCount + absentCount;
      String rate = "0%";
      if (totalDays > 0) {
        rate = "${((presentCount / totalDays) * 100).round()}%";
      }
      
      if (mounted) {
        setState(() {
          _historyData = historyData;
          _statPresent = presentCount;
          _statAbsent = absentCount;
          _statRate = rate;
          
          // Generate trend spots
          _trendSpots = _generateTrendSpots(historyData);
          
          _isHistoryLoaded = true;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
        PremiumToast.show(context, 'Failed to load history', isError: true);
      }
    }
  }

  List<FlSpot> _generateTrendSpots(Map<String, dynamic> data) {
    if (data.isEmpty) return [];
    List<FlSpot> spots = [];
    int x = 0;
    int cumulativePresent = 0;
    
    var sortedKeys = data.keys.toList()..sort();
    for (var date in sortedKeys) {
      final entry = data[date];
      final status = (entry is Map) ? entry['status'] : entry;
      if (status == 'P') cumulativePresent++;
      spots.add(FlSpot(x.toDouble(), cumulativePresent.toDouble()));
      x++;
    }
    return spots;
  }

}
