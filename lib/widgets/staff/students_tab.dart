import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme.dart';

class StudentsTab extends StatefulWidget {
  final List<Map<dynamic, dynamic>> students;
  final String currentScope;
  final List<String> allVehicles;
  final bool dataEntryLocked;
  final bool vehicleEntryLocked;
  final Function(Map<String, dynamic>) onAddStudent;
  final Function(String, Map<String, dynamic>, bool) onEditStudent;
  final Function(String) onDeleteStudent;
  final String? highlightedStudentId;

  const StudentsTab({
    super.key,
    required this.students,
    required this.currentScope,
    required this.allVehicles,
    required this.dataEntryLocked,
    required this.vehicleEntryLocked,
    required this.onAddStudent,
    required this.onEditStudent,
    required this.onDeleteStudent,
    this.highlightedStudentId,
  });

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final _addNameCtrl = TextEditingController();
  final _addClassCtrl = TextEditingController();
  final _addSecCtrl = TextEditingController();
  final _addSrNoCtrl = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.highlightedStudentId != null) {
      _scrollToHighlighted();
    }
  }

  @override
  void didUpdateWidget(covariant StudentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightedStudentId != oldWidget.highlightedStudentId && widget.highlightedStudentId != null) {
      _scrollToHighlighted();
    }
  }

  void _scrollToHighlighted() {
    final idx = widget.students.indexWhere((s) => s['id'] == widget.highlightedStudentId);
    if (idx != -1) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          final isMobile = MediaQuery.of(context).size.width < 600;
          final rowHeight = isMobile ? 130.0 : 49.0;
          final maxScroll = _scrollController.position.maxScrollExtent;
          var targetOffset = idx * rowHeight;
          if (targetOffset > maxScroll) targetOffset = maxScroll;
          if (targetOffset < 0) targetOffset = 0;
          
          _scrollController.animateTo(
            targetOffset, 
            duration: const Duration(milliseconds: 500), 
            curve: Curves.easeInOut
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _addNameCtrl.dispose();
    _addClassCtrl.dispose();
    _addSecCtrl.dispose();
    _addSrNoCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _toRoman(int num) {
    if (num <= 0) return num.toString();
    final vals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    final syms = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
    String r = '';
    for (int i = 0; i < vals.length; i++) {
      while (num >= vals[i]) {
        r += syms[i];
        num -= vals[i];
      }
    }
    return r;
  }

  String _normalizeClass(String cls) {
    final t = cls.trim().toUpperCase();
    if (int.tryParse(t) != null) return _toRoman(int.parse(t));
    return t;
  }

  String _normalizeStudentIdentity(String name, String cls, String section) {
    final n = name.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
    final c = _normalizeClass(cls);
    final s = section.trim().toUpperCase();
    if (n.isEmpty || c.isEmpty || s.isEmpty) return '';
    return '${n}_${c}_$s'.replaceAll(RegExp(r'[^A-Z0-9_]'), '_');
  }

  bool _isDuplicate(String identity, {String? excludeId}) {
    for (var s in widget.students) {
      if (s['id'] == excludeId) continue;
      if (s['id'] == identity || _normalizeStudentIdentity(s['name'] ?? '', s['class'] ?? '', s['section'] ?? '') == identity) {
        return true;
      }
    }
    return false;
  }

  void _handleAdd() {
    if (widget.dataEntryLocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⛔ Data entry is LOCKED by Admin. Contact admin for permission.')));
      return;
    }
    if (widget.currentScope == 'All') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a specific vehicle first.')));
      return;
    }

    final name = _addNameCtrl.text.trim();
    final cls = _normalizeClass(_addClassCtrl.text);
    final sec = _addSecCtrl.text.trim().toUpperCase();
    final srNo = _addSrNoCtrl.text.trim().toUpperCase();

    if (name.isEmpty || cls.isEmpty || sec.isEmpty || srNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, Class, Section, and Sr No are required')));
      return;
    }
    if (!RegExp(r'^[A-Z]+$').hasMatch(sec)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Section can ONLY contain alphabetic characters')));
      return;
    }

    final id = _normalizeStudentIdentity(name, cls, sec);
    if (_isDuplicate(id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already Added: Student is already in the system.')));
      return;
    }

    widget.onAddStudent({
      'id': id,
      'name': name,
      'class': cls,
      'section': sec,
      'srNo': srNo,
      'vehicle': widget.currentScope,
      'addedAt': DateTime.now().toIso8601String(),
    });

    _addNameCtrl.clear();
    _addClassCtrl.clear();
    _addSecCtrl.clear();
    _addSrNoCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Student Added', style: TextStyle(color: Colors.green))));
  }

  void _showEditModal(Map<dynamic, dynamic> student) {
    final editNameCtrl = TextEditingController(text: student['name']);
    final editClassCtrl = TextEditingController(text: _normalizeClass(student['class'] ?? ''));
    final editSecCtrl = TextEditingController(text: student['section']);
    String selectedVehicle = student['vehicle'] ?? widget.currentScope;
    
    if (!widget.allVehicles.contains(selectedVehicle)) {
      if (widget.allVehicles.isNotEmpty) selectedVehicle = widget.allVehicles.first;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          final isTransfer = selectedVehicle != student['vehicle'];

          InputDecoration inputDec(String hint) {
            return InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, color: Color(0xFF6366F1), size: 24),
                        const SizedBox(width: 8),
                        Text('Edit Student', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Update details or transfer to a different vehicle', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF64748B))),
                    const SizedBox(height: 24),

                    if (widget.dataEntryLocked)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber)),
                        child: Row(
                          children: [
                            Icon(Icons.lock, color: Colors.amber.shade900, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Data entry LOCKED — you can only transfer to a different vehicle.', style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      
                    Text('Full Name', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: editNameCtrl,
                      decoration: inputDec('E.g. Aafiya Bano'),
                      enabled: !widget.dataEntryLocked,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Class', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                              const SizedBox(height: 8),
                              TextField(controller: editClassCtrl, decoration: inputDec('II'), enabled: !widget.dataEntryLocked),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Section', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                              const SizedBox(height: 8),
                              TextField(controller: editSecCtrl, decoration: inputDec('B'), textCapitalization: TextCapitalization.characters, enabled: !widget.dataEntryLocked),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text('Vehicle / Transfer To', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedVehicle,
                      decoration: inputDec('').copyWith(prefixIcon: const Icon(Icons.directions_bus, color: Color(0xFF6366F1), size: 20)),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
                      items: widget.allVehicles.isEmpty 
                        ? [DropdownMenuItem(value: selectedVehicle, child: Text(selectedVehicle))]
                        : widget.allVehicles.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: widget.vehicleEntryLocked 
                        ? null 
                        : (v) => setStateModal(() => selectedVehicle = v!),
                    ),
                    if (isTransfer)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(color: Colors.orange.shade50, border: Border.all(color: Colors.orange.shade200), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Transfer: Student can be moved only to an already existing vehicle.', style: TextStyle(color: Colors.orange, fontSize: 12)),
                      ),
                    
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1E293B),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            final newName = editNameCtrl.text.trim();
                            final newClass = _normalizeClass(editClassCtrl.text);
                            final newSection = editSecCtrl.text.trim().toUpperCase();

                            if (newName.isEmpty || newClass.isEmpty || newSection.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, Class, and Section required')));
                              return;
                            }
                            if (!RegExp(r'^[A-Z]+$').hasMatch(newSection)) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Section can ONLY contain alphabetic characters')));
                              return;
                            }

                            final duplicate = _isDuplicate(_normalizeStudentIdentity(newName, newClass, newSection), excludeId: student['id']);
                            if (duplicate) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already Added in system.')));
                              return;
                            }

                            widget.onEditStudent(
                              student['id'],
                              {
                                'name': newName,
                                'class': newClass,
                                'section': newSection,
                                'vehicle': selectedVehicle,
                              },
                              isTransfer,
                            );
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: Text('Save Changes', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleDelete(Map<dynamic, dynamic> student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Archive'),
        content: Text('Move "${student['name']}" to Recycle Bin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              widget.onDeleteStudent(student['id']);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student moved to Recycle Bin.')));
            },
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;
        final double availableWidth = constraints.maxWidth;
        
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (widget.dataEntryLocked)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)]),
                border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('⛔ New data entry is LOCKED by Admin.', style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('You can only transfer students to a different vehicle.', style: TextStyle(color: Colors.brown.shade800, fontSize: 12)),
                ],
              ),
            ),
          
          if (!widget.dataEntryLocked)
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_add, color: Color(0xFF4F46E5), size: 24),
                      const SizedBox(width: 8),
                      Text('Quick Add Student', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Form Fields (Responsive-like layout)
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _addNameCtrl,
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Student Full Name',
                                hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6C757D), fontWeight: FontWeight.w400, fontSize: 15),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                                filled: true, fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _addClassCtrl,
                                    textCapitalization: TextCapitalization.characters,
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 15),
                                    decoration: InputDecoration(
                                      hintText: 'Class',
                                      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6C757D), fontWeight: FontWeight.w400, fontSize: 15),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                                      filled: true, fillColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _addSecCtrl,
                                    textCapitalization: TextCapitalization.characters,
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 15),
                                    decoration: InputDecoration(
                                      hintText: 'Section',
                                      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6C757D), fontWeight: FontWeight.w400, fontSize: 15),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                                        filled: true, fillColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _addSrNoCtrl,
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 15),
                                      decoration: InputDecoration(
                                        hintText: 'Scholar / Sr No',
                                        hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6C757D), fontWeight: FontWeight.w400, fontSize: 15),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                                        filled: true, fillColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _handleAdd,
                                icon: const Icon(Icons.person_add, size: 20),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 2,
                                  shadowColor: const Color(0xFF4F46E5).withOpacity(0.5),
                                  textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SizedBox(
                              width: (availableWidth - 80) * 0.25,
                              child: TextField(
                                controller: _addNameCtrl,
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Student Full Name',
                                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6C757D), fontWeight: FontWeight.w400, fontSize: 15),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                                  filled: true, fillColor: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: (availableWidth - 80) * 0.15,
                              child: TextField(
                                controller: _addClassCtrl,
                                textCapitalization: TextCapitalization.characters,
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Class',
                                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6C757D), fontWeight: FontWeight.w400, fontSize: 15),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                                  filled: true, fillColor: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: (availableWidth - 80) * 0.16,
                              child: TextField(
                                controller: _addSecCtrl,
                                textCapitalization: TextCapitalization.characters,
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Section',
                                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6C757D), fontWeight: FontWeight.w400, fontSize: 15),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                                  filled: true, fillColor: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: (availableWidth - 80) * 0.15,
                              child: TextField(
                                controller: _addSrNoCtrl,
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Scholar / Sr No',
                                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6C757D), fontWeight: FontWeight.w400, fontSize: 15),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                                  filled: true, fillColor: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: (availableWidth - 80) * 0.25 - 24,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _handleAdd,
                                icon: const Icon(Icons.person_add, size: 20),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 2,
                                  shadowColor: const Color(0xFF4F46E5).withOpacity(0.5),
                                  textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
            
          const SizedBox(height: 32),
          
          // Students Table List
          Expanded(
            child: widget.students.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFDEE2E6)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Text('No students found. Add one above!')),
                  )
              : Builder(
                  builder: (context) => isMobile
                    ? ListView.separated(
                      controller: _scrollController,
                      itemCount: widget.students.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final s = widget.students[i];
                        final isHighlighted = s['id'] == widget.highlightedStudentId;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isHighlighted ? const Color(0xFFEFF6FF) : Colors.white,
                            border: Border.all(
                              color: isHighlighted ? const Color(0xFF3B82F6) : const Color(0xFFDEE2E6),
                              width: isHighlighted ? 2.0 : 1.0,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: isHighlighted ? const Color(0xFF3B82F6).withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.02), 
                                blurRadius: isHighlighted ? 8 : 4, 
                                offset: const Offset(0, 2)
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(s['name'] ?? '', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 16))),
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () => _showEditModal(s),
                                        borderRadius: BorderRadius.circular(4),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.edit, color: Color(0xFF3B82F6), size: 20),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _handleDelete(s),
                                        borderRadius: BorderRadius.circular(4),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.delete, color: Color(0xFFEF4444), size: 20),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Class ${_normalizeClass(s['class'] ?? '')} • Sec ${s['section'] ?? ''}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, color: const Color(0xFF6C757D), fontSize: 13.5)),
                              const SizedBox(height: 4),
                              Text('Vehicle: ${s['vehicle'] ?? '-'}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5), fontSize: 13.5)),
                            ],
                          ),
                        );
                      },
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFDEE2E6)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Table Headers (table-light)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            color: const Color(0xFFF8F9FA),
                            child: Row(
                              children: [
                                Expanded(flex: 7, child: Text('Name', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 14))),
                                Expanded(flex: 5, child: Text('Class', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 14))),
                                Expanded(flex: 5, child: Text('Vehicle', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 14))),
                                Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: Text('Actions', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 14)))),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: const Color(0xFFDEE2E6), thickness: 1),
                          
                          Expanded(
                            child: ListView.separated(
                              controller: _scrollController,
                              itemCount: widget.students.length,
                            separatorBuilder: (c,i) => Divider(height: 1, color: const Color(0xFFDEE2E6), thickness: 1),
                            itemBuilder: (context, i) {
                              final s = widget.students[i];
                              final isHighlighted = s['id'] == widget.highlightedStudentId;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                color: isHighlighted ? const Color(0xFFEFF6FF) : Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 7,
                                        child: Text(s['name'] ?? '', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 14.5)),
                                      ),
                                      Expanded(
                                        flex: 5,
                                        child: Text('${_normalizeClass(s['class'] ?? '')} ${s['section'] ?? ''}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, color: const Color(0xFF6C757D), fontSize: 13.5)),
                                      ),
                                      Expanded(
                                        flex: 5,
                                        child: Text(s['vehicle'] ?? '-', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: const Color(0xFF212529), fontSize: 13.5)),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (!widget.dataEntryLocked) ...[
                                              InkWell(
                                                onTap: () => _showEditModal(s),
                                                borderRadius: BorderRadius.circular(4),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Icon(Icons.edit, color: Color(0xFF3B82F6), size: 18),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () => _handleDelete(s),
                                                borderRadius: BorderRadius.circular(4),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Icon(Icons.delete, color: Color(0xFFEF4444), size: 18),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ), // closes Expanded
            ],
          ),
        );
      }
    );
  }
}
