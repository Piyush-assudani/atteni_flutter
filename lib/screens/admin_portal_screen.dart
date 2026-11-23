import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  int _activeTab = 0; // 0: Manage, 1: Add Student, 2: Live Audit, 3: Staff
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Dashboard State
  int _totalStudents = 0;
  int _activeVans = 0;
  int _presentToday = 0;
  String _connStatus = 'Connecting...';
  List<Map<String, dynamic>> _students = [];
  bool _isLoadingDb = true;

  // Student Entry State
  final _studentFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _srNoCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String _selectedGender = 'Male';
  String? _selectedClass;
  String? _selectedSection;
  String? _selectedPrimaryVehicle;
  List<String> _availableVehicles = [];
  bool _isAddingStudent = false;

  // Live Audit State
  DateTime _auditDate = DateTime.now();
  String? _auditSelectedVan;
  bool _isFetchingAudit = false;
  List<Map<String, dynamic>> _auditLogs = [];

  // Staff Management State
  final _staffFormKey = GlobalKey<FormState>();
  final _staffNameCtrl = TextEditingController();
  final _staffPinCtrl = TextEditingController();
  bool _obscureStaffPin = true;
  String _staffRole = 'Gatekeeper';
  bool _isAddingStaff = false;
  List<Map<String, dynamic>> _staffList = [];

  final _dbRef = FirebaseDatabase.instance.ref('artifacts/student-system-v2/public/data');

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final snapshot = await _dbRef.child('students').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final List<Map<String, dynamic>> loadedStudents = [];
        final Set<String> uniqueVans = {};
        int presentCount = 0; // In a real scenario, this would come from an attendance node

        data.forEach((key, value) {
          if (value is Map) {
            final student = Map<String, dynamic>.from(value);
            student['id'] = key;
            loadedStudents.add(student);
            try {
              if (student['vehicle'] != null) {
                final v = student['vehicle'].toString();
                if (v.trim().isNotEmpty && v != 'null' && v != 'undefined') {
                  uniqueVans.add(v);
                }
              }
            } catch (_) {}
          }
        });

        final vehiclesSnapshot = await _dbRef.child('vehicles').get();
        if (vehiclesSnapshot.exists) {
          final vehiclesData = Map<String, dynamic>.from(vehiclesSnapshot.value as Map);
          _availableVehicles = vehiclesData.keys.toList()..sort();
        }

        final staffSnapshot = await _dbRef.child('staff').get();
        final List<Map<String, dynamic>> loadedStaff = [];
        if (staffSnapshot.exists) {
          final staffData = Map<String, dynamic>.from(staffSnapshot.value as Map);
          staffData.forEach((key, value) {
            if (value is Map) {
              final staffObj = Map<String, dynamic>.from(value);
              staffObj['id'] = key;
              loadedStaff.add(staffObj);
            }
          });
        }

        setState(() {
          _students = loadedStudents;
          _staffList = loadedStaff;
          _totalStudents = loadedStudents.length;
          _activeVans = uniqueVans.length;
          _presentToday = presentCount;
          _connStatus = 'Online';
          _isLoadingDb = false;
        });
      } else {
        setState(() {
          _connStatus = 'Online';
          _isLoadingDb = false;
        });
      }
    } catch (e) {
      setState(() {
        _connStatus = 'Error';
        _isLoadingDb = false;
      });
    }
  }

  String _safeString(dynamic value, [String fallback = '']) {
    try {
      if (value == null) return fallback;
      final str = value.toString();
      return (str == 'null' || str == 'undefined' || str.trim().isEmpty) ? fallback : str;
    } catch (e) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF3F4F6),
      drawer: isDesktop ? null : Drawer(
        backgroundColor: Colors.transparent,
        child: _buildSidebar(),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFFEBEBF5), Color(0xFFF3F4F6)],
          ),
        ),
        child: Stack(
          children: [
            // Background blur blobs (Glassmorphism effect)
            Positioned(
              top: -100, left: -100,
              child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF8B5CF6).withValues(alpha: 0.1))),
            ),
            Positioned(
              bottom: -100, right: -100,
              child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6366F1).withValues(alpha: 0.1))),
            ),
            
            Row(
              children: [
                if (isDesktop) _buildSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      if (!isDesktop) _buildMobileHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildActiveTabContent(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border(right: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(2, 0))],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 5))],
                        color: Colors.white,
                      ),
                      child: const Icon(Icons.shield, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 12),
                    Text('ATTENI', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('ADMIN MENU', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2, color: const Color(0xFF64748B))),
              ),
              const SizedBox(height: 8),
              _buildNavItem(0, Icons.speed, 'Dashboard'),
              _buildNavItem(1, Icons.person_add, 'Student Entry'),
              _buildNavItem(2, Icons.analytics, 'Live Audit'),
              _buildNavItem(3, Icons.badge, 'Staff'),
              const Spacer(),
              _buildNavItem(-1, Icons.logout, 'Log Out'),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title) {
    final isActive = _activeTab == index;
    return InkWell(
      onTap: () {
        if (index == -1) {
          Navigator.pushReplacementNamed(context, '/');
        } else {
          setState(() => _activeTab = index);
          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
            _scaffoldKey.currentState?.closeDrawer();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6366F1).withValues(alpha: 0.15) : Colors.transparent,
          border: Border(left: BorderSide(color: isActive ? const Color(0xFF6366F1) : Colors.transparent, width: 4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF475569)),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.shield, color: Color(0xFF6366F1)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'ADMIN PANEL',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 0: return _buildDashboardTab(context);
      case 1: return _buildStudentEntryTab();
      case 2: return _buildLiveAuditTab();
      case 3: return _buildStaffTab();
      default: return const SizedBox();
    }
  }

  Widget _buildStaffTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Staff Management', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
          ),
          child: Form(
            key: _staffFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Staff Name', _staffNameCtrl, Icons.person),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _staffRole,
                  decoration: _inputDecoration('Designation / Role', Icons.badge),
                  items: ['Gatekeeper', 'Teacher', 'Admin', 'Driver']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => _staffRole = v ?? 'Gatekeeper'),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Login PIN (Passcode)',
                  _staffPinCtrl,
                  Icons.password,
                  keyboardType: TextInputType.number,
                  isPassword: true,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isAddingStaff ? null : _addStaff,
                    child: _isAddingStaff 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('Register Staff', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_staffList.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                columns: const [
                  DataColumn(label: Text('NAME')),
                  DataColumn(label: Text('ROLE')),
                  DataColumn(label: Text('PIN')),
                  DataColumn(label: Text('STATUS')),
                ],
                rows: _staffList.map((staff) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_safeString(staff['name']))),
                      DataCell(Text(_safeString(staff['role']))),
                      DataCell(Text(_safeString(staff['pin']))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Active', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addStaff() async {
    if (!_staffFormKey.currentState!.validate()) return;
    
    setState(() => _isAddingStaff = true);
    
    try {
      final staffId = 'STF${DateTime.now().millisecondsSinceEpoch}';
      await _dbRef.child('staff').child(staffId).set({
        'name': _staffNameCtrl.text.trim(),
        'role': _staffRole,
        'pin': _staffPinCtrl.text.trim(),
        'status': 'active'
      });
      
      _staffNameCtrl.clear();
      _staffPinCtrl.clear();
      setState(() {
        _staffRole = 'Gatekeeper';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff Registered Successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      _fetchDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding staff: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isAddingStaff = false);
    }
  }

  Widget _buildLiveAuditTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Live Audit Terminal', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _auditDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _auditDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFF6366F1), size: 20),
                            const SizedBox(width: 12),
                            Text('${_auditDate.year}-${_auditDate.month.toString().padLeft(2, '0')}-${_auditDate.day.toString().padLeft(2, '0')}', 
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _auditSelectedVan,
                      decoration: _inputDecoration('Select Van (Optional)', Icons.directions_bus),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Vans')),
                        ..._availableVehicles.map((v) => DropdownMenuItem(value: v, child: Text(v))),
                      ],
                      onChanged: (v) => setState(() => _auditSelectedVan = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isFetchingAudit ? null : _fetchAuditData,
                    icon: _isFetchingAudit ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.refresh, color: Colors.white),
                    label: Text('Fetch Data', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_auditLogs.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                columns: const [
                  DataColumn(label: Text('TIME')),
                  DataColumn(label: Text('STUDENT')),
                  DataColumn(label: Text('CLASS')),
                  DataColumn(label: Text('VEHICLE')),
                  DataColumn(label: Text('STATUS')),
                ],
                rows: _auditLogs.map((log) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_safeString(log['timestamp']))),
                      DataCell(Text(_safeString(log['studentName']))),
                      DataCell(Text('${_safeString(log['class'])} ${_safeString(log['section'])}')),
                      DataCell(Text(_safeString(log['vehicle']))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_safeString(log['status'], 'Present'), style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          )
        else if (!_isFetchingAudit)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Select a date and click "Fetch Data" to view logs.', style: TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }

  Future<void> _fetchAuditData() async {
    setState(() => _isFetchingAudit = true);
    
    try {
      final dateStr = '${_auditDate.year}-${_auditDate.month.toString().padLeft(2, '0')}-${_auditDate.day.toString().padLeft(2, '0')}';
      final snapshot = await _dbRef.child('logs/$dateStr').get();
      
      final List<Map<String, dynamic>> logs = [];
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        data.forEach((key, value) {
          if (value is Map) {
            final log = Map<String, dynamic>.from(value);
            // Optional Van filter
            if (_auditSelectedVan != null && _auditSelectedVan!.isNotEmpty) {
              if (log['vehicle'] != _auditSelectedVan) return;
            }
            logs.add(log);
          }
        });
      }
      
      // Sort by time descending if timestamp is available, else keep original
      logs.sort((a, b) => _safeString(b['timestamp']).compareTo(_safeString(a['timestamp'])));
      
      setState(() {
        _auditLogs = logs;
      });
      if (logs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No audit logs found for this filter.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load audit logs: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isFetchingAudit = false);
    }
  }

  Widget _buildStudentEntryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Student Enrollment', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
          ),
          child: Form(
            key: _studentFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Full Name', _nameCtrl, Icons.person),
                const SizedBox(height: 16),
                _buildTextField('SR Number', _srNoCtrl, Icons.numbers),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedClass,
                        decoration: _inputDecoration('Class', Icons.class_),
                        items: ['Nursery', 'LKG', 'UKG', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _selectedClass = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSection,
                        decoration: _inputDecoration('Section', Icons.group),
                        items: ['A', 'B', 'C', 'D', 'E']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _selectedSection = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField('Father\'s Name', _fatherNameCtrl, Icons.person_outline),
                const SizedBox(height: 16),
                _buildTextField('Contact Number', _contactCtrl, Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedPrimaryVehicle,
                  decoration: _inputDecoration('Primary Vehicle No', Icons.directions_bus),
                  items: _availableVehicles.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _selectedPrimaryVehicle = v),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isAddingStudent ? null : _addStudent,
                    child: _isAddingStudent 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('Add Student', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType? keyboardType,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: isPassword ? _obscureStaffPin : false,
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      decoration: _inputDecoration(
        label,
        icon,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscureStaffPin ? Icons.visibility_off : Icons.visibility,
                  color: Colors.blueGrey,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureStaffPin = !_obscureStaffPin),
              )
            : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.blueGrey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
    );
  }

  Future<void> _addStudent() async {
    if (!_studentFormKey.currentState!.validate()) return;
    
    setState(() => _isAddingStudent = true);
    
    try {
      final studentId = 'STU${DateTime.now().millisecondsSinceEpoch}';
      await _dbRef.child('students').child(studentId).set({
        'name': _nameCtrl.text.trim(),
        'sr_no': _srNoCtrl.text.trim(),
        'class': _selectedClass,
        'section': _selectedSection,
        'father_name': _fatherNameCtrl.text.trim(),
        'contact': _contactCtrl.text.trim(),
        'vehicle': _selectedPrimaryVehicle,
        'gender': _selectedGender,
        'status': 'active'
      });
      
      _nameCtrl.clear();
      _srNoCtrl.clear();
      _fatherNameCtrl.clear();
      _contactCtrl.clear();
      setState(() {
        _selectedClass = null;
        _selectedSection = null;
        _selectedPrimaryVehicle = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student Added Successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      _fetchDashboardData(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding student: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isAddingStudent = false);
    }
  }

  Widget _buildDashboardTab(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatCard('Total Students', '$_totalStudents', Icons.people, Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('Active Vans', '$_activeVans', Icons.directions_bus, Colors.blue)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatCard('Present Today', '$_presentToday', Icons.check_circle, Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('Status', _connStatus, Icons.sensors, _connStatus == 'Online' ? Colors.green : Colors.orange)),
                ],
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Students', '$_totalStudents', Icons.people, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Active Vans', '$_activeVans', Icons.directions_bus, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Present Today', '$_presentToday', Icons.check_circle, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Status', _connStatus, Icons.sensors, _connStatus == 'Online' ? Colors.green : Colors.orange)),
            ],
          ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student Database', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
              const SizedBox(height: 16),
              _isLoadingDb 
                  ? const Center(child: CircularProgressIndicator())
                  : _students.isEmpty
                      ? const Center(child: Text('No students found.'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            columns: const [
                              DataColumn(label: Text('NAME')),
                              DataColumn(label: Text('SR NO')),
                              DataColumn(label: Text('CLASS')),
                              DataColumn(label: Text('VEHICLE')),
                            ],
                            rows: _students.take(50).map((student) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(_safeString(student['name'], 'Unknown'))),
                                  DataCell(Text(_safeString(student['sr_no'], '-'))),
                                  DataCell(Text('${_safeString(student['class'])} ${_safeString(student['section'])}'.trim())),
                                  DataCell(Text(_safeString(student['vehicle'], 'None'))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
