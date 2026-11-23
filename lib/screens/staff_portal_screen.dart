import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;

import '../services/firebase_service.dart';
import '../services/attendance_sync_service.dart';
import '../services/live_tracking_service.dart';

import '../widgets/staff/setup_tab.dart';
import '../widgets/staff/students_tab.dart';
import '../widgets/staff/attendance_tab.dart';
import 'dart:ui';

import '../widgets/premium_toast.dart';
import '../services/notification_service.dart';
import 'profile_overlay.dart';

import '../widgets/staff/export_tab.dart';
import '../widgets/staff/skeleton_loader.dart';

class StaffPortalScreen extends StatefulWidget {
  const StaffPortalScreen({super.key});

  @override
  State<StaffPortalScreen> createState() => _StaffPortalScreenState();
}

class _StaffPortalScreenState extends State<StaffPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // States
  bool _isLoading = true;
  bool _isOffline = false;
  bool _justBackOnline = false;
  bool _isProcessingAction = false;
  bool _isMaintenance = false;
  bool _forceUpdate = false;
  bool _dataEntryLocked = false;
  bool _vehicleEntryLocked = false;
  bool _readOnlyMode = false;
  bool _setupEditLocked = false;
  bool _showLoader = false;
  Timer? _skelTimer;
  String _broadcastMessage = '';
  String _holidayBannerDate = '';
  bool _allowHolidayAttendance = false;
  
  String? _teacherAssignedScope;
  String _currentScope = 'All';
  bool _showVehicleSelector = false;
  
  Map<dynamic, dynamic> _setupData = {};
  List<Map<dynamic, dynamic>> _students = [];
  Map<dynamic, dynamic> _allVehiclesData = {};
  
  // Attendance State
  Map<String, dynamic> _attendanceList = {};
  DateTime _selectedDate = DateTime.now();
  bool _isHoliday = false;

  // Rate Limiting & Timers
  Timer? _debounceTimer;
  final Set<String> _pendingAttendanceIds = {};
  bool _isSyncing = false;
  bool _justSynced = false;
  Timer? _justSyncedTimer;
  Timer? _loadTimeoutTimer;
  Timer? _backOnlineTimer;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;
  late DatabaseReference _db;
  String _schoolId = 'DPS'; // Fallback
  String? _userRole;
  String? _selectedGroup;
  String _transportSearchQuery = '';
  String? _highlightedStudentId;

  String _localDeviceId = '';
  StreamSubscription? _sessionSub;

  Future<void> _initSessionListener() async {
    final prefs = await SharedPreferences.getInstance();
    _localDeviceId = prefs.getString('local_device_id') ?? '';
    final role = prefs.getString('userRole');
    if (role != 'teacher' && role != 'admin' && role != 'master') return;
    
    final school = prefs.getString('SELECTED_SCHOOL');
    final staffKey = prefs.getString('STAFF_AUTH_KEY') ?? prefs.getString('STAFF_KEY') ?? prefs.getString('STAFF_ID');
    if (staffKey == null || school == null) return;

    _sessionSub = FirebaseDatabase.instance.ref('artifacts/student-system-v2/public/data/system_auth/staff_sessions/$school/$staffKey').onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        // Removed device validation for staff portal to allow simultaneous logins
        // if (data['deviceId'] != null && data['deviceId'] != _localDeviceId) {
        //   _forceLogoutDueToAnotherDevice();
        // }
      }
    });
  }

  void _forceLogoutDueToAnotherDevice() async {
    _sessionSub?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('STAFF_AUTH_KEY');
    await prefs.remove('userRole');
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('Session Expired', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text('You have been logged out because your account was accessed from another device.\n\nPlease log in again if this was you.', style: TextStyle(fontSize: 15)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/staff_login', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initSessionListener();
    _saveLastOpened();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _skelTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted && _isLoading) {
        setState(() => _showLoader = true);
      }
    });
    
    // 12-second load timeout logic (Offline fallback)
    _loadTimeoutTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _isLoading) {
        setState(() => _isOffline = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection timeout. Switched to offline mode.', style: TextStyle(color: Colors.white)),
            backgroundColor: Color(0xFFD97706),
            duration: Duration(seconds: 4),
          )
        );
      }
    });
    
    _initConnectivity();
    _checkAccessAndLoad();
    _fetchPublicIp();
  }

  Future<void> _saveLastOpened() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('LAST_OPENED', 'staff');
  }

  Future<void> _fetchPublicIp() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        debugPrint('Public IP: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching IP: $e');
    }
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    LiveTrackingService().stopTracking();
    _skelTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    _debounceTimer?.cancel();
    _backOnlineTimer?.cancel();
    _justSyncedTimer?.cancel();
    _tabController.dispose();
    _connectivitySub.cancel();
    super.dispose();
  }

  void _initConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
      if (_isOffline && !isOffline) {
        // Back online
        setState(() {
          _isOffline = false;
          _justBackOnline = true;
        });
        _backOnlineTimer?.cancel();
        _backOnlineTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _justBackOnline = false);
        });
        _syncLocalAttendance();
      } else {
        setState(() => _isOffline = isOffline);
      }
    });
  }

  Future<void> _checkAccessAndLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final savedSchool = prefs.getString('SELECTED_SCHOOL');
      if (savedSchool != null && savedSchool.isNotEmpty) {
        _schoolId = savedSchool;
      }
      _db = FirebaseService().getBaseRef(_schoolId);
      
      final role = prefs.getString('userRole');
      if (mounted) setState(() => _userRole = role);
      if (role != 'teacher' && role != 'admin' && role != 'master' && role != 'gatekeeper') {
        if (mounted) Navigator.pushReplacementNamed(context, '/staff_login');
        return;
      }

      // 1. Maintenance & Access Check
      final acSnap = await _db.child('system_auth/access_controls/$_schoolId').get();
      if (acSnap.exists) {
        final ac = acSnap.value as Map<dynamic, dynamic>;
        if (mounted) {
          setState(() {
            _allowHolidayAttendance = role == 'master' ? true : ac['allowHolidayAttendance'] == true;
          });
        }
        if (ac['maintenance'] == true) {
          if (role != 'master') {
            setState(() => _isMaintenance = true);
            return;
          }
        }
        if (role != 'master' && ac['panels'] != null && ac['panels']['teacher'] == false) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teacher App disabled by Admin.')));
            Navigator.pushReplacementNamed(context, '/');
          }
          return;
        }
      }

      // Listeners for global state
      _db.child('system/maintenance').onValue.listen((event) {
        final val = event.snapshot.value == true;
        if (mounted && _isMaintenance != val) {
          setState(() => _isMaintenance = val);
          if (!_isLoading) PremiumToast.show(context, val ? 'Maintenance Mode Activated' : 'Maintenance Mode Deactivated', isError: val);
        }
      });
      _db.child('system/forceUpdate').onValue.listen((event) {
        final val = event.snapshot.value == true;
        if (mounted && _forceUpdate != val) {
          setState(() => _forceUpdate = val);
        }
      });
      _db.child('system/dataEntryLocked').onValue.listen((event) {
        final val = event.snapshot.value == true;
        if (mounted) {
          setState(() => _dataEntryLocked = role == 'master' ? false : (role == 'gatekeeper' ? true : val));
          if (!_isLoading && role != 'master' && role != 'gatekeeper') PremiumToast.show(context, val ? 'Data Entry Locked by Admin' : 'Data Entry Unlocked', isError: val);
        }
      });
      _db.child('system/vehicleEntryLocked').onValue.listen((event) {
        final val = event.snapshot.value == true;
        if (mounted) {
          setState(() => _vehicleEntryLocked = role == 'master' ? false : (role == 'gatekeeper' ? true : val));
          if (!_isLoading && role != 'master' && role != 'gatekeeper') PremiumToast.show(context, val ? 'Vehicle Entry Locked by Admin' : 'Vehicle Entry Unlocked', isError: val);
        }
      });
      _db.child('system/readOnlyMode').onValue.listen((event) {
        final val = event.snapshot.value == true;
        if (mounted) {
          setState(() => _readOnlyMode = role == 'master' ? false : val);
          if (!_isLoading && role != 'master' && role != 'gatekeeper') PremiumToast.show(context, val ? 'App is now in Read-Only Mode' : 'Read-Only Mode Disabled', isError: val);
        }
      });
      _db.child('system/setupEditLocked').onValue.listen((event) {
        final val = event.snapshot.value == true;
        if (mounted) {
          setState(() => _setupEditLocked = role == 'master' ? false : (role == 'gatekeeper' ? true : val));
          if (!_isLoading && role != 'master' && role != 'gatekeeper') PremiumToast.show(context, val ? 'Setup Edit Locked by Admin' : 'Setup Edit Unlocked', isError: val);
        }
      });
      _db.child('system/message').onValue.listen((event) {
        setState(() => _broadcastMessage = (event.snapshot.value as String?) ?? '');
      });

      // Settings
      _db.child('settings').onValue.listen((event) {
        if (event.snapshot.exists) {
          setState(() {
            final map = event.snapshot.value as Map<dynamic, dynamic>;
            _setupData = Map.from(_setupData);
            _setupData['schoolName'] = map['schoolName'];
            _setupData['logoUrl'] = map['logoUrl'];
          });
          _refreshSetupData();
        }
      });

      // Staff (for assigned scope)
      final staffId = prefs.getString('STAFF_ID');
      _db.child('staff').onValue.listen((event) {
        if (event.snapshot.exists && staffId != null) {
          final staffMap = event.snapshot.value as Map<dynamic, dynamic>;
          final member = staffMap[staffId];
          if (member != null) {
            _teacherAssignedScope = member['assignedVan'];
          }
        }
        _resolveScope();
      });

      _db.child('registered_vehicles').onValue.listen((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final val = event.snapshot.value;
          if (val is Map) {
            setState(() => _allVehiclesData = val);
          } else if (val is List) {
            final map = <dynamic, dynamic>{};
            for (int i = 0; i < val.length; i++) {
              if (val[i] != null) map[i.toString()] = val[i];
            }
            setState(() => _allVehiclesData = map);
          }
        } else {
          setState(() => _allVehiclesData = {});
        }
        _refreshSetupData();
      });

      // Students
      _db.child('students').onValue.listen((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final val = event.snapshot.value;
          Map<dynamic, dynamic> stMap = {};
          if (val is Map) {
            stMap = val;
          } else if (val is List) {
            for (int i = 0; i < val.length; i++) {
              if (val[i] != null) stMap[i.toString()] = val[i];
            }
          }
          final list = stMap.entries.map((e) => {'id': e.key, ...e.value as Map}).toList();
          list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
          // Clear timers since load is successful
          _skelTimer?.cancel();
          _loadTimeoutTimer?.cancel();
          setState(() {
            _students = list;
            _isLoading = false;
            _showLoader = false;
          });
        } else {
          setState(() {
            _students = [];
            _isLoading = false;
          });
        }
      });

      _loadAttendanceForDate(_selectedDate);
      _showWelcomeTourIfNeeded();

    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    // Fallback timeout to ensure we never get stuck on the loader
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  Widget _buildTourItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.indigo.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.blueGrey.shade800,
                  fontSize: 13.5,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWelcomeTourIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('hasSeenStaffTour') != true) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.indigo.shade600),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Welcome to Atteni Staff!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: ListBody(
                children: [
                  Text(
                    'Quick guide to get you started:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTourItem(Icons.settings, 'Setup', 'Configure your vehicle details & logo.'),
                  _buildTourItem(Icons.people, 'Students', 'Manage your student roster and transfer students.'),
                  _buildTourItem(Icons.checklist, 'Attendance', 'Mark P/A/E/H. Remember to click "Final Save" at the bottom!'),
                  _buildTourItem(Icons.picture_as_pdf, 'Export', 'Generate and share printable PDF reports seamlessly.'),
                  const SizedBox(height: 16),
                  Text(
                    '💡 Works completely offline and syncs automatically when you\'re back online!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  prefs.setBool('hasSeenStaffTour', true);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Get Started'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _resolveScope() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole');
    final isLocked = role == 'teacher' && _teacherAssignedScope != null && _teacherAssignedScope != 'All';

    if (role == 'gatekeeper') {
      _currentScope = 'Private';
      _showVehicleSelector = false;
    } else if (isLocked) {
      _currentScope = _teacherAssignedScope!;
      _showVehicleSelector = false;
    } else {
      final savedScope = prefs.getString('busAppScope');
      if (savedScope != null && savedScope.isNotEmpty) {
        _currentScope = savedScope;
        _showVehicleSelector = false;
      } else {
        _showVehicleSelector = true;
        _selectedGroup = null; // Reset group selection when showing selector
      }
    }
    _refreshSetupData();
    setState(() {
      _isLoading = false;
    });
  }

  void _refreshSetupData() {
    setState(() {
      _setupData = Map.from(_setupData); // Ensure new reference triggers update
      if (_currentScope != 'All' && _allVehiclesData.containsKey(_currentScope)) {
        final vData = _allVehiclesData[_currentScope];
        if (vData is Map) {
          _setupData['teacher'] = vData['teacher'];
          _setupData['driver'] = vData['driver'];
          _setupData['vehNo'] = vData['vehNo'];
          _setupData['vehType'] = vData['vehType'];
        }
      } else if (_currentScope != 'All') {
        _setupData.remove('teacher');
        _setupData.remove('driver');
        _setupData.remove('vehNo');
        _setupData.remove('vehType');
      }
    });
  }

  void _switchVehicle() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole');
    final isLocked = role == 'teacher' && _teacherAssignedScope != null && _teacherAssignedScope != 'All';

    if (role == 'gatekeeper') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gatekeeper is locked to PRIVATE.')));
      return;
    }

    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login is locked to $_teacherAssignedScope.')));
      return;
    }
    
    await prefs.remove('busAppScope');
    setState(() {
      _currentScope = 'All';
      _showVehicleSelector = true;
    });
  }

  void _selectScope(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('busAppScope', scope);
    setState(() {
      _currentScope = scope;
      _showVehicleSelector = false;
    });
    _refreshSetupData();
    _loadAttendanceForDate(_selectedDate);
    
    // Start tracking if they select a specific vehicle, otherwise stop
    if (scope != 'All') {
      LiveTrackingService().startTracking(scope);
    } else {
      LiveTrackingService().stopTracking();
    }
  }

  Future<void> _loadAttendanceForDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    // Check Local
    final localAtt = await AttendanceSyncService.loadLocally(dateStr, _currentScope);
    
    final snap = await _db.child('attendance/$dateStr').get();
    if (snap.exists) {
      final dbData = snap.value as Map<dynamic, dynamic>;
      final dbList = (dbData['list'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {};
      
      // Holiday check
      _isHoliday = dbData['holiday'] == true;
      _holidayBannerDate = _isHoliday ? dateStr : '';

      // Conflict resolution
      if (localAtt != null && localAtt['isLocalDirty'] == true) {
        // Simple merge: local wins if dirty
        _attendanceList = {...dbList, ...localAtt['list']};
      } else {
        _attendanceList = dbList;
        await AttendanceSyncService.clearLocal(dateStr, _currentScope);
      }
    } else {
      _isHoliday = false;
      _attendanceList = localAtt?['list'] ?? {};
    }
    setState(() {});
  }

  Future<void> _syncLocalAttendance() async {
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final localAtt = await AttendanceSyncService.loadLocally(dateStr, _currentScope);
    
    if (localAtt != null && localAtt['isLocalDirty'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Back online. Syncing local changes...', style: TextStyle(color: Colors.green))));
      await _persistAttendanceSelection(localAtt['list'].keys.toList(), isFinal: false, silent: true);
    }
  }

  Future<void> _persistAttendanceSelection(List<String> ids, {bool isFinal = false, bool silent = false}) async {
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    
    final updates = <String, dynamic>{};
    final nowIso = DateTime.now().toIso8601String();
    
    updates['attendance/$dateStr/lastUpdated'] = nowIso;
    if (isFinal) {
      updates['attendance/$dateStr/finalSavedAt'] = nowIso;
      try {
        final ipRes = await http.get(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 3));
        if (ipRes.statusCode == 200) {
          final ipData = jsonDecode(ipRes.body);
          updates['attendance/$dateStr/savedByIp'] = ipData['ip'];
        }
      } catch (_) {}
    } else {
      updates['attendance/$dateStr/lastAutoSavedAt'] = nowIso;
    }

    for (var id in ids) {
      if (_attendanceList[id] != null) {
        updates['attendance/$dateStr/list/$id'] = _attendanceList[id];
        updates['attendance/$dateStr/markedAt/$id'] = nowIso;
      }
    }

    try {
      await _db.update(updates);
      await AttendanceSyncService.clearLocal(dateStr, _currentScope);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFinal ? 'Final save complete. You can export now.' : 'Auto-saved to cloud.')));
      }
    } catch (e) {
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection weak: Saved locally.', style: TextStyle(color: Colors.orange))));
      await AttendanceSyncService.saveLocally(dateStr, _currentScope, _attendanceList);
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _justSynced = true;
        });
        _justSyncedTimer?.cancel();
        _justSyncedTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _justSynced = false);
        });
      }
    }
  }

  // UI BUILDERS
  Widget _buildBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF8FAFC),
    );
  }

  Widget _buildOfflineBanner() {
    if (!_isOffline && !_justBackOnline) return const SizedBox.shrink();
    
    final bgColor = _justBackOnline ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final iconColor = _justBackOnline ? const Color(0xFF15803D) : Colors.red;
    final borderColor = _justBackOnline ? const Color(0xFF22C55E).withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2);
    final iconData = _justBackOnline ? Icons.wifi : Icons.wifi_off;
    final titleText = _justBackOnline ? 'Back Online' : 'Offline Mode';
    final subText = _justBackOnline ? 'Synchronizing with cloud...' : 'Saving locally • Auto-sync active';
    final titleColor = _justBackOnline ? const Color(0xFF15803D) : const Color(0xFFDC2626);
    
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: kIsWeb ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                border: Border.all(color: borderColor),
              ),
                            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, color: titleColor, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titleText, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                      Text(subText, style: TextStyle(color: titleColor.withValues(alpha: 0.8), fontSize: 12)),
                    ],
                  ),
                ],
              ),
          ) : BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                    child: Center(child: Icon(iconData, color: iconColor, size: 18)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titleText, style: GoogleFonts.plusJakartaSans(color: titleColor, fontWeight: FontWeight.w800, height: 1.0, fontSize: 13.6)),
                      const SizedBox(height: 2),
                      Text(subText, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 11.2)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  if (_isOffline)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaintenanceOverlay() {
    if (!_isMaintenance) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.engineering, size: 64, color: Colors.orange),
              ),
              const SizedBox(height: 24),
              Text('System Maintenance', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              const SizedBox(height: 12),
              Text('Atteni is currently undergoing scheduled maintenance to improve your experience. We will be back online shortly.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF64748B), height: 1.5)),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildForceUpdateOverlay() {
    if (!_forceUpdate) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.indigo.withValues(alpha: 0.2), blurRadius: 40)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.system_update, size: 64, color: Colors.indigo),
              ),
              const SizedBox(height: 24),
              Text('Update Available', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              const SizedBox(height: 12),
              Text('A new version of Atteni is available! Please update to continue enjoying a seamless experience.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF64748B), height: 1.5)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // Simulating an update action or redirect.
                    PremiumToast.show(context, 'Redirecting to update page...', isError: false);
                  },
                  child: Text('Update Now', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _forceUpdate = false),
                child: Text('Dismiss for now', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildVehicleSelector() {
    if (!_showVehicleSelector) return const SizedBox.shrink();

    final allVehs = <String>{};
    _students.forEach((s) { if (s['vehicle'] != null) allVehs.add(s['vehicle']); });
    allVehs.addAll(_allVehiclesData.keys.map((k) => k.toString()));
    final sortedVehs = allVehs.toList()..sort();
    
    // Group logic based on vehType dynamically
    final Map<String, List<String>> types = {};
    for (var v in sortedVehs) {
      final dynamic rawData = _allVehiclesData[v];
      final Map<dynamic, dynamic> vData = (rawData is Map) ? rawData : {};
      final vehType = vData['vehType']?.toString() ?? 'Van';
      if (types[vehType] == null) {
        types[vehType] = [];
      }
      types[vehType]!.add(v);
    }

    return Positioned.fill(
      child: Container(
        color: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _selectedGroup != null ? InkWell(
                    onTap: () {
                      setState(() => _selectedGroup = null);
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text('Back', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ) : const SizedBox(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/task_manager');
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_note, size: 16, color: Colors.indigo),
                              const SizedBox(width: 8),
                              Text('Daily Planner', style: GoogleFonts.plusJakartaSans(color: Colors.indigo, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                    onTap: () async {
                      await LiveTrackingService().stopTracking();
                      await FirebaseAuth.instance.signOut();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('STAFF_AUTH_KEY');
                      await prefs.remove('STAFF_ID');
                      await prefs.remove('STAFF_NAME');
                      await prefs.remove('STAFF_ROLE');
                      await prefs.remove('userRole');
                      await prefs.remove('teacherEmail');
                      if (mounted) Navigator.pushReplacementNamed(context, '/');
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.power_settings_new, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 8),
                          Text('Logout', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  ],
                ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Text('Select Transport', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text('Choose a vehicle or search for a student.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF64748B))),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _transportSearchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search child by name or ID...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: _transportSearchQuery.isNotEmpty 
                  ? _buildStudentSearchResults()
                  : _selectedGroup == null
                    ? _buildGroupsList(types)
                    : _buildVehiclesList(
                        types[_selectedGroup] ?? [],
                        (_selectedGroup ?? '').toLowerCase().contains('van') ? Icons.directions_car : Icons.directions_bus,
                      ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildGroupsList(Map<String, List<String>> types) {
    final groups = [];
    types.forEach((type, vehicleList) {
      IconData icon = Icons.directions_bus;
      final typeLower = type.toLowerCase();
      if (typeLower.contains('private')) icon = Icons.person;
      else if (typeLower.contains('van')) icon = Icons.directions_car;
      else if (typeLower.contains('shift')) icon = Icons.access_time;
      else if (typeLower.contains('bus')) icon = Icons.directions_bus;
      
      bool groupFullyMarked = true;
      bool groupEmpty = true;

      for (var v in vehicleList) {
        final vehStudents = _students.where((s) => s['vehicle'] == v).toList();
        if (vehStudents.isNotEmpty) {
          groupEmpty = false;
          int markedCount = vehStudents.where((s) => _attendanceList[s['id'].toString()] != null).length;
          if (markedCount != vehStudents.length) {
            groupFullyMarked = false;
          }
        }
      }
      final isCompleted = !groupEmpty && groupFullyMarked;
      
      groups.add({'name': type, 'count': vehicleList.length, 'icon': icon, 'isCompleted': isCompleted});
    });

    final double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    final childrenList = [
      ...groups.map((group) {
        return _buildCardItem(
          title: group['name'],
          subtitle: 'Group',
          badgeText: '${group['count']} Vehicles',
          icon: group['icon'],
          isCompleted: group['isCompleted'],
          onTap: () => setState(() => _selectedGroup = group['name']),
        );
      }).toList(),
      _buildAddVehicleCard(),
    ];

    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: childrenList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, i) => childrenList[i],
      );
    } else {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: childrenList.map((c) => SizedBox(width: 280, child: c)).toList(),
      );
    }
  }

  Widget _buildVehiclesList(List<String> vehs, IconData defaultIcon) {
    final double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    final childrenList = [
      ...vehs.map((v) {
        final vehStudents = _students.where((s) => s['vehicle'] == v).toList();
        bool isCompleted = false;
        if (vehStudents.isNotEmpty) {
          int markedCount = vehStudents.where((s) => _attendanceList[s['id'].toString()] != null).length;
          isCompleted = markedCount == vehStudents.length;
        }

        final dynamic vData = _allVehiclesData[v];
        final String teacherName = (vData is Map && vData['teacher'] != null && vData['teacher'].toString().trim().isNotEmpty) ? vData['teacher'].toString() : 'Teacher Incharge';

        return _buildCardItem(
          title: v,
          subtitle: teacherName,
          badgeText: '${vehStudents.length} Students',
          icon: defaultIcon,
          isCompleted: isCompleted,
          onTap: () => _selectScope(v),
        );
      }).toList(),
      _buildAddVehicleCard(),
    ];

    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: childrenList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, i) => childrenList[i],
      );
    } else {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: childrenList.map((c) => SizedBox(width: 280, child: c)).toList(),
      );
    }
  }

  Widget _buildStudentSearchResults() {
    final query = _transportSearchQuery.toLowerCase();
    final results = _students.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final id = (s['scholar_no'] ?? s['id'] ?? '').toString().toLowerCase();
      return name.contains(query) || id.contains(query);
    }).toList();

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('No students found for "$_transportSearchQuery"', 
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8))),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final student = results[i];
        final name = student['name'] ?? 'Unknown';
        final cls = student['class'] ?? '';
        final sec = student['section'] ?? '';
        final vehicle = student['vehicle'] ?? 'Not Assigned';
        
        return InkWell(
          onTap: vehicle != 'Not Assigned' && vehicle.isNotEmpty ? () {
            setState(() {
              _transportSearchQuery = '';
              _highlightedStudentId = student['id'];
            });
            _selectScope(vehicle);
            _tabController.animateTo(1);
            
            Timer(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() => _highlightedStudentId = null);
              }
            });
          } : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text('Class $cls $sec', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_bus, size: 12, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 4),
                      Text(vehicle, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardItem({
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required VoidCallback onTap,
    bool isCompleted = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: isCompleted ? Border.all(color: const Color(0xFF22C55E), width: 1.5) : null,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isCompleted)
                Positioned(
                  top: -24,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: Color(0xFF15803D), size: 20),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(icon, color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF3B82F6), size: 28),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(title, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: isCompleted ? const Color(0xFFBBF7D0) : const Color(0xFFDBEAFE)),
                      borderRadius: BorderRadius.circular(20),
                      color: isCompleted ? const Color(0xFFF0FDF4) : Colors.transparent,
                    ),
                    child: Text(badgeText, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                  ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddVehicleCard() {
    return InkWell(
      onTap: () {
        if (_vehicleEntryLocked || _readOnlyMode) {
          PremiumToast.show(context, '⛔ Vehicle Entry is LOCKED by Admin.', isError: true);
          return;
        }
        showDialog(context: context, builder: (c) {
          final ctrl = TextEditingController();
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Register New Vehicle', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  Text('This vehicle will be created in the database\nimmediately, even if no students are\nassigned yet.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B))),
                  const SizedBox(height: 24),
                  TextField(
                    controller: ctrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'E.G. VAN-5',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final name = ctrl.text.trim().toUpperCase();
                            if (name.isNotEmpty) {
                              _db.child('registered_vehicles/$name').set({
                                'name': name,
                                'vehType': 'Van',
                                'status': 'Active',
                                'schoolId': _schoolId,
                                'createdAt': DateTime.now().toIso8601String(),
                              });
                              Navigator.pop(c);
                              _selectScope(name);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: Text('Create Vehicle', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF64748B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
      child: CustomPaint(
        painter: DashedBorderPainter(color: const Color(0xFF4F46E5), radius: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(24),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFF4F46E5),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Icon(Icons.add, color: Colors.white, size: 28)),
              ),
              const SizedBox(height: 16),
              Text('Add New Vehicle', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5))),
              const SizedBox(height: 4),
              Text('Transport & Setup', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8))),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildTabPill(int index, String label, IconData icon) {
    final isActive = _tabController.index == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {});
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF4F46E5) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive ? [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(
                    color: isActive ? Colors.white : const Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.0,
                  )),
                ),
              ],
            ),
        ),
      ),
    );
  }

  Widget _buildMainApp() {
    if (_showVehicleSelector || _isMaintenance) return const SizedBox.shrink();
    if (_isLoading) {
      return _showLoader ? SkeletonAppLoader(isMainApp: _currentScope != 'All') : const SizedBox.shrink();
    }

    return Positioned.fill(
      child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Top Navbar (Matches HTML sticky-top nav)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Logo & School Info
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                              ),
                              child: ClipOval(
                                child: _buildLogoWidget(_setupData['logoUrl']?.toString()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _setupData['schoolName']?.toString().isNotEmpty == true ? _setupData['schoolName'].toString() : 'School Name', 
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFF4F46E5), height: 1.1),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Text('Vehicle:', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B))),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          _currentScope, 
                                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Action Buttons
                            if (_userRole == 'gatekeeper')
                            InkWell(
                              onTap: () async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.remove('STAFF_AUTH_KEY');
                                await prefs.remove('STAFF_ID');
                                await prefs.remove('STAFF_NAME');
                                await prefs.remove('STAFF_ROLE');
                                await prefs.remove('userRole');
                                await prefs.remove('teacherEmail');
                                if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border: Border.all(color: Colors.red.shade100),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.power_settings_new, size: 14, color: Colors.red.shade700),
                                    const SizedBox(width: 4),
                                    Text('Logout', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade700)),
                                  ],
                                ),
                              ),
                            )
                          else if (!(_teacherAssignedScope != null && _teacherAssignedScope != 'All'))
                              if (_showVehicleSelector || _currentScope != 'All')
                                InkWell(
                                onTap: _switchVehicle,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5)],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.swap_horiz, size: 14, color: Color(0xFF334155)),
                                      const SizedBox(width: 4),
                                      Text('Switch', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF334155))),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => ProfileOverlay.show(context),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text('Profile', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Small Drop shadow for navbar
                      Container(height: 1, color: Colors.black.withValues(alpha: 0.05)),
                      Container(height: 3, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.03), Colors.transparent]))),
                        
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    minHeight: 68,
                    maxHeight: 68,
                    child: Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            _buildTabPill(0, 'Setup', Icons.settings),
                            _buildTabPill(1, 'Students', Icons.people),
                            _buildTabPill(2, 'Attendance', Icons.fact_check),
                            _buildTabPill(3, 'Export', Icons.download),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: Column(
              children: [
                const SizedBox(height: 12),
                if (_readOnlyMode)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: Color(0xFF92400E), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Read-Only Mode: Attendance marking is allowed. Adding or editing students/vehicles is disabled by admin.',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _tabController,
                    children: [
                      SetupTab(
                        initialData: _setupData,
                        currentScope: _currentScope,
                        onSave: _handleSaveSetup,
                        onDeleteVehicle: _currentScope == 'All' ? null : () async {
                          if (_vehicleEntryLocked || _readOnlyMode) {
                            PremiumToast.show(context, '⛔ Vehicle deletion is LOCKED by Admin.', isError: true);
                            return;
                          }
                          try {
                            setState(() => _isLoading = true);
                            await _db.child('registered_vehicles/$_currentScope').remove();
                            // Also delete all students associated with this vehicle to completely flush data
                            final vehStudents = _students.where((s) => s['vehicle'] == _currentScope).toList();
                            for (var s in vehStudents) {
                              if (s['id'] != null) {
                                await _db.child('students/${s['id']}').remove();
                              }
                            }
                            // Delete attendance data for this vehicle
                            await _db.child('attendance_records/$_currentScope').remove();
                            
                            PremiumToast.show(context, '$_currentScope deleted successfully.', isError: false);
                            _selectScope('All');
                          } catch (e) {
                            PremiumToast.show(context, 'Failed to delete vehicle', isError: true);
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        isGlobalSetup: _setupData['isGlobalSetup'] == true,
                        isLocked: _setupEditLocked || _readOnlyMode,
                      ),
                      StudentsTab(
                        students: _currentScope == 'All' ? _students : _students.where((s) => s['vehicle'] == _currentScope).toList(),
                        currentScope: _currentScope,
                        allVehicles: _allVehiclesData.keys.map((k) => k.toString()).toList(),
                        dataEntryLocked: _dataEntryLocked || _readOnlyMode,
                        vehicleEntryLocked: _vehicleEntryLocked || _readOnlyMode,
                        highlightedStudentId: _highlightedStudentId,
                        onAddStudent: _handleAddStudent,
                        onEditStudent: _handleEditStudent,
                        onDeleteStudent: _handleDeleteStudent,
                      ),
                      AttendanceTab(
                        students: _currentScope == 'All' ? _students : _students.where((s) => s['vehicle'] == _currentScope).toList(),
                        attendanceMap: _attendanceList,
                        selectedDate: _selectedDate,
                        isHoliday: _isHoliday,
                        isSyncing: _isSyncing,
                        justSynced: _justSynced,
                        onDateChanged: (d) {
                          setState(() => _selectedDate = d);
                          _loadAttendanceForDate(d);
                        },
                        onMarkAttendance: _handleMarkAttendance,
                        onMarkAllPresent: _handleMarkAllPresent,
                        onMarkAllAbsent: _handleMarkAllAbsent,
                        onToggleHoliday: _handleToggleHoliday,
                        onFinalSave: _handleFinalSave,
                      ),
                      ExportTab(
                        students: _currentScope == 'All' ? _students : _students.where((s) => s['vehicle'] == _currentScope).toList(),
                        attendanceMap: _attendanceList,
                        selectedDate: _selectedDate,
                        setupData: _setupData,
                        currentScope: _currentScope,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
      ),
    );
  }

  // --- Handlers for Tabs ---

  void _handleSaveSetup(Map<String, dynamic> newData) async {
    if (_currentScope == 'All') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit setup for All.')));
      return;
    }
    final newScopeName = newData['scopeName'];
    final updates = <String, dynamic>{};
    
    // Update global settings
    updates['settings/schoolName'] = newData['schoolName'];
    updates['settings/logoUrl'] = newData['logoUrl'];
    
    final vehiclePayload = {
      'teacher': newData['teacher'],
      'driver': newData['driver'],
      'vehNo': newData['vehNo'],
      'vehType': newData['vehType'],
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    if (newScopeName != _currentScope && newScopeName.isNotEmpty) {
      // Rename Sequence
      // Update students
      for (var s in _students) {
        if (s['vehicle'] == _currentScope) {
          updates['students/${s['id']}/vehicle'] = newScopeName;
        }
      }
      // Update staff
      final staffSnap = await _db.child('staff').get();
      if (staffSnap.exists) {
        final stMap = staffSnap.value as Map<dynamic, dynamic>;
        for (var k in stMap.keys) {
          if (stMap[k]['assignedVan'] == _currentScope) {
            updates['staff/$k/assignedVan'] = newScopeName;
          }
        }
      }
      updates['registered_vehicles/$_currentScope'] = null;
      updates['registered_vehicles/$newScopeName'] = vehiclePayload;
      
      await _db.update(updates);
      setState(() {
        _currentScope = newScopeName;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vehicle renamed to $newScopeName seamlessly!')));
      }
    } else {
      updates['registered_vehicles/$_currentScope'] = vehiclePayload;
      await _db.update(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration saved!')));
      }
    }
  }

  void _handleAddStudent(Map<String, dynamic> student) {
    student['addedAt'] = DateTime.now().toIso8601String();
    student['schoolId'] = _schoolId;
    _db.child('students/${student['id']}').set(student);
  }

  void _handleEditStudent(String id, Map<String, dynamic> newUpdates, bool isTransfer) async {
    final updates = <String, dynamic>{};
    if (isTransfer) {
      final oldSt = _students.firstWhere((s) => s['id'] == id);
      final newVehicle = newUpdates['vehicle'];
      final today = DateTime.now().toIso8601String().split('T')[0];
      final logId = 'tr_${id}_${newVehicle.replaceAll(RegExp(r'\s+'), '_')}_$today';
      final newId = 'std_tr_${id}_${newVehicle.replaceAll(RegExp(r'\s+'), '_')}';
      
      final email = FirebaseAuth.instance.currentUser?.email ?? 'Staff';
      
      updates['transfer_logs/$logId'] = {
        'studentId': id,
        'studentName': oldSt['name'],
        'from': oldSt['vehicle'],
        'to': newVehicle,
        'timestamp': DateTime.now().toIso8601String(),
        'by': email,
      };

      updates['students/$id'] = null;
      updates['attendance/$today/list/$id'] = null;
      
      final newStudentData = Map<String, dynamic>.from(oldSt);
      newStudentData.addAll(newUpdates);
      newStudentData['transferredFrom'] = id;
      newStudentData['schoolId'] = _schoolId;
      newStudentData['addedAt'] = DateTime.now().toIso8601String();
      
      updates['students/$newId'] = newStudentData;
    } else {
      newUpdates.forEach((key, value) {
        updates['students/$id/$key'] = value;
      });
    }
    
    await _db.update(updates);
  }

  void _handleDeleteStudent(String id) async {
    final st = _students.firstWhere((s) => s['id'] == id);
    final archiveRecord = {...st, 'archivedAt': DateTime.now().toIso8601String(), 'archivedBy': 'Teacher_Session', 'originalPath': 'students/$id'};
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    
    final updates = <String, dynamic>{
      'recycle_bin/students/$id': archiveRecord,
      'students/$id': null,
      'attendance/$dateStr/list/$id': 'ARCHIVED_STUDENT',
    };
    
    await _db.update(updates);
  }

  Widget _buildLogoWidget(String? logoUrl) {
    final fallback = Container(
      color: const Color(0xFF4F46E5),
      child: Center(
        child: Text(
          (_setupData['schoolName']?.toString() ?? 'S').isNotEmpty
              ? (_setupData['schoolName']?.toString() ?? 'S')[0].toUpperCase()
              : 'S',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
    );

    if (logoUrl == null || logoUrl.isEmpty) {
      return fallback;
    }
    if (logoUrl.startsWith('data:image')) {
      try {
        final split = logoUrl.split(',');
        if (split.length == 2) {
          return Image.memory(base64Decode(split[1]), fit: BoxFit.cover);
        }
      } catch (_) {}
    }
    if (logoUrl.startsWith('http')) {
      return Image.network(logoUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => fallback);
    }
    return fallback;
  }

  void _handleMarkAttendance(String id, String status) async {
    setState(() => _isProcessingAction = true);
    await Future.delayed(const Duration(milliseconds: 200)); // UX Loader Delay
    
    if (_selectedDate.weekday == DateTime.sunday && !_allowHolidayAttendance) {
      setState(() => _isProcessingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance marking is disabled on Sundays.')));
      return;
    }
    
    final oldSt = _attendanceList[id];
    final oldStatus = (oldSt is Map) ? oldSt['status'] : oldSt;
    
    if (oldStatus == 'E' && _userRole != 'master' && _userRole != 'admin') {
      setState(() => _isProcessingAction = false);
      PremiumToast.show(context, '⛔ Early leave (E) is locked by Admin and cannot be changed.', isError: true);
      return;
    }
    
    Map<String, int> delta = {'P': 0, 'A': 0, 'E': 0, 'H': 0};
    if (oldStatus != null) delta[oldStatus] = (delta[oldStatus] ?? 0) - 1;
    delta[status] = (delta[status] ?? 0) + 1;

    setState(() {
      if (status == 'P') {
        _attendanceList[id] = 'P';
        
        // Find student name for the notification
        final student = _students.firstWhere((s) => s['id'] == id, orElse: () => {'name': 'Your child'});
        final name = student['name'];
        NotificationService().sendPushNotification(
          id, 
          "Journey Started 🚐", 
          "$name has boarded the vehicle and is on the way."
        ); } else {
        _attendanceList[id] = status;
      }
      _isSyncing = true;
    });
    
    _pendingAttendanceIds.add(id);
    _updateMetricsTransaction(delta);

    // Debounce Save Request
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (_pendingAttendanceIds.isNotEmpty) {
        _persistAttendanceSelection(_pendingAttendanceIds.toList(), silent: true);
        _pendingAttendanceIds.clear();
      }
    });
    
    setState(() => _isProcessingAction = false);
  }

  void _handleMarkAllPresent() async {
    setState(() => _isProcessingAction = true);
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (_selectedDate.weekday == DateTime.sunday && !_allowHolidayAttendance) {
      setState(() => _isProcessingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance marking is disabled on Sundays.')));
      return;
    }
    
    final list = _currentScope == 'All' ? _students : _students.where((s) => s['vehicle'] == _currentScope).toList();
    Map<String, int> delta = {'P': 0, 'A': 0, 'E': 0, 'H': 0};
    
    setState(() {
      for (var s in list) {
        final id = s['id'].toString();
        final oldSt = _attendanceList[id];
        final oldStatus = (oldSt is Map) ? oldSt['status'] : oldSt;
        
        if (oldStatus == 'E' && _userRole != 'master' && _userRole != 'admin') continue;
        
        if (oldStatus != null) delta[oldStatus] = (delta[oldStatus] ?? 0) - 1;
        delta['P'] = (delta['P'] ?? 0) + 1;
        
        _attendanceList[id] = 'P';
      }
    });
    _persistAttendanceSelection(list.map((s) => s['id'].toString()).toList(), silent: true);
    _updateMetricsTransaction(delta);
    
    setState(() => _isProcessingAction = false);
  }

  void _handleMarkAllAbsent() async {
    setState(() => _isProcessingAction = true);
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (_selectedDate.weekday == DateTime.sunday && !_allowHolidayAttendance) {
      setState(() => _isProcessingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance marking is disabled on Sundays.')));
      return;
    }
    
    final list = _currentScope == 'All' ? _students : _students.where((s) => s['vehicle'] == _currentScope).toList();
    Map<String, int> delta = {'P': 0, 'A': 0, 'E': 0, 'H': 0};
    
    setState(() {
      for (var s in list) {
        final id = s['id'].toString();
        final oldSt = _attendanceList[id];
        final oldStatus = (oldSt is Map) ? oldSt['status'] : oldSt;
        
        if (oldStatus == 'E' && _userRole != 'master' && _userRole != 'admin') continue;
        
        if (oldStatus != null) delta[oldStatus] = (delta[oldStatus] ?? 0) - 1;
        delta['A'] = (delta['A'] ?? 0) + 1;
        
        _attendanceList[id] = 'A';
      }
    });
    _persistAttendanceSelection(list.map((s) => s['id'].toString()).toList(), silent: true);
    _updateMetricsTransaction(delta);
    
    setState(() => _isProcessingAction = false);
  }

  void _handleToggleHoliday(bool markAsHoliday) async {
    setState(() => _isProcessingAction = true);
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    if (markAsHoliday) {
      Map<String, int> delta = {'P': 0, 'A': 0, 'E': 0, 'H': 0};
      final updates = <String, dynamic>{
        'attendance/$dateStr/holiday': true,
        'attendance/$dateStr/holidayMarkedAt': DateTime.now().toIso8601String(),
      };
      
      for (var s in _students) {
        final id = s['id'].toString();
        updates['attendance/$dateStr/list/$id'] = 'H';
        
        final oldSt = _attendanceList[id];
        final oldStatus = (oldSt is Map) ? oldSt['status'] : oldSt;
        if (oldStatus != null) delta[oldStatus] = (delta[oldStatus] ?? 0) - 1;
        delta['H'] = (delta['H'] ?? 0) + 1;
        
        setState(() => _attendanceList[id] = 'H');
      }
      
      await _db.update(updates);
      _updateMetricsTransaction(delta);
      setState(() => _isHoliday = true);
      
      NotificationService().showNotification(
        title: 'Holiday Marked 🏖️',
        body: 'You have marked $_selectedDate as a holiday.',
      );
    } else {
      final updates = <String, dynamic>{'attendance/$dateStr/holiday': false};
      for (var s in _students) {
        final id = s['id'].toString();
        if (_attendanceList[id] == 'H') {
          updates['attendance/$dateStr/list/$id'] = null;
          updates['attendance/$dateStr/markedAt/$id'] = null;
          setState(() => _attendanceList.remove(id));
        }
      }
      await _db.update(updates);
      setState(() => _isHoliday = false);
      
      NotificationService().showNotification(
        title: 'Holiday Removed',
        body: 'The holiday has been cleared for $_selectedDate.',
      );
    }
    setState(() => _isProcessingAction = false);
  }

  Future<void> _updateMetricsTransaction(Map<String, int> delta) async {
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final metricsRef = _db.child('attendance/$dateStr/metrics');
    
    await metricsRef.runTransaction((Object? currentData) {
      if (currentData == null) {
        return Transaction.success({'P': delta['P'], 'A': delta['A'], 'E': delta['E'], 'H': delta['H']});
      }
      Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(currentData as Map);
      ['P', 'A', 'E', 'H'].forEach((k) {
        data[k] = (data[k] ?? 0) + (delta[k] ?? 0);
        if (data[k] < 0) data[k] = 0;
      });
      return Transaction.success(data);
    });
  }

  void _handleFinalSave() async {
    setState(() => _isProcessingAction = true);
    final list = _currentScope == 'All' ? _students : _students.where((s) => s['vehicle'] == _currentScope).toList();
    final markedIds = list.map((s) => s['id'].toString()).where((id) => _attendanceList.containsKey(id) && _attendanceList[id] != null).toList();
    final unmarkedIds = list.map((s) => s['id'].toString()).where((id) => !_attendanceList.containsKey(id) || _attendanceList[id] == null).toList();

    if (markedIds.isEmpty && unmarkedIds.isNotEmpty) {
      setState(() => _isProcessingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No attendance marked for this vehicle.')));
      return;
    }

    if (unmarkedIds.isNotEmpty) {
      // Save what they have marked so far silently
      await _persistAttendanceSelection(markedIds, isFinal: false, silent: true);
      setState(() => _isProcessingAction = false);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(child: Text('Incomplete Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text('You have marked attendance for ${markedIds.length} students, but ${unmarkedIds.length} are left.\n\nYour progress is saved, but you should mark the rest to finalize. What would you like to do?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Do it manually', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Map<String, int> delta = {'P': 0, 'A': 0, 'E': 0, 'H': 0};
                setState(() {
                  for (var id in unmarkedIds) {
                    delta['A'] = (delta['A'] ?? 0) + 1;
                    _attendanceList[id] = {'status': 'A', 'markedAt': DateTime.now().toIso8601String()};
                  }
                });
                _updateMetricsTransaction(delta);
                _handleFinalSave();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Mark rest as Absent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Map<String, int> delta = {'P': 0, 'A': 0, 'E': 0, 'H': 0};
                setState(() {
                  for (var id in unmarkedIds) {
                    delta['P'] = (delta['P'] ?? 0) + 1;
                    _attendanceList[id] = {'status': 'P', 'markedAt': DateTime.now().toIso8601String()};
                  }
                });
                _updateMetricsTransaction(delta);
                _handleFinalSave();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF198754), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Mark rest as Present', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    await _persistAttendanceSelection(markedIds, isFinal: true);
    
    // Trigger Push Notification as requested
    NotificationService().showNotification(
      title: 'Attendance Saved',
      body: 'Final attendance has been recorded and pushed to the cloud for $_currentScope.',
    );
    
    setState(() => _isProcessingAction = false);
  }

  Widget _buildProcessingOverlay() {
    if (!_isProcessingAction) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 15, spreadRadius: 2)
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 3),
              const SizedBox(height: 20),
              Text('Processing...', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B))),
            ],
          ),
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          _buildMainApp(),
          _buildVehicleSelector(),
          _buildOfflineBanner(),
          _buildForceUpdateOverlay(),
          _buildMaintenanceOverlay(),
          _buildProcessingOverlay(),
        ],
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 2.0,
    this.dashWidth = 8.0,
    this.dashSpace = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    Path path = Path()..addRRect(rrect);
    Path dashPath = Path();

    for (PathMetric measurePath in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < measurePath.length) {
        dashPath.addPath(
          measurePath.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
