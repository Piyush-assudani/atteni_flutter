import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';

class SetupTab extends StatefulWidget {
  final Map<dynamic, dynamic> initialData;
  final String currentScope;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback? onDeleteVehicle;
  final bool isGlobalSetup;
  final bool isLocked;

  const SetupTab({
    super.key,
    required this.initialData,
    required this.currentScope,
    required this.onSave,
    this.onDeleteVehicle,
    this.isGlobalSetup = false,
    this.isLocked = false,
  });

  @override
  State<SetupTab> createState() => _SetupTabState();
}

class _SetupTabState extends State<SetupTab> {
  late TextEditingController _schoolNameCtrl;
  late TextEditingController _vanScopeCtrl;
  late TextEditingController _vehNoCtrl;
  late TextEditingController _teacherCtrl;
  late TextEditingController _driverCtrl;
  String _selectedVehType = 'Van';
  String _logoBase64 = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void didUpdateWidget(SetupTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialData != widget.initialData || oldWidget.currentScope != widget.currentScope) {
      _initData();
    }
  }

  void _initData() {
    _schoolNameCtrl = TextEditingController(text: widget.initialData['schoolName'] ?? '');
    _vanScopeCtrl = TextEditingController(text: widget.currentScope == 'All' ? '' : widget.currentScope);
    _vehNoCtrl = TextEditingController(text: widget.initialData['vehNo'] ?? '');
    _teacherCtrl = TextEditingController(text: widget.initialData['teacher'] ?? '');
    _driverCtrl = TextEditingController(text: widget.initialData['driver'] ?? '');
    
    const validTypes = ['Van', 'Bus', 'Mini Bus', 'Private', 'Shift'];
    final vehType = widget.initialData['vehType'] as String?;
    if (vehType != null && validTypes.contains(vehType)) {
      _selectedVehType = vehType;
    } else {
      _selectedVehType = 'Van';
    }
    _logoBase64 = widget.initialData['logoUrl'] ?? '';
  }

  @override
  void dispose() {
    _schoolNameCtrl.dispose();
    _vanScopeCtrl.dispose();
    _vehNoCtrl.dispose();
    _teacherCtrl.dispose();
    _driverCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 300, maxHeight: 300, imageQuality: 80);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() => _logoBase64 = base64Image);
    }
  }

  void _handleSave() {
    if (widget.currentScope == 'All') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit setup for All. Select a vehicle.')));
      return;
    }

    if (widget.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⛔ Setup is locked by Admin. Changes cannot be saved.'),
        backgroundColor: Color(0xFFDC2626),
      ));
      return;
    }
    
    widget.onSave({
      'schoolName': _schoolNameCtrl.text.trim(),
      'scopeName': _vanScopeCtrl.text.trim(),
      'vehNo': _vehNoCtrl.text.trim(),
      'vehType': _selectedVehType,
      'teacher': _teacherCtrl.text.trim(),
      'driver': _driverCtrl.text.trim(),
      'logoUrl': _logoBase64,
    });
  }

  Widget _buildLogoWidget(String? logoUrl) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return const Icon(Icons.camera_alt, color: Color(0xFF94A3B8), size: 32);
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
      return Image.network(logoUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.camera_alt, color: Color(0xFF94A3B8), size: 32));
    }
    return const Icon(Icons.camera_alt, color: Color(0xFF94A3B8), size: 32);
  }

  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: Color(0xFF4F46E5), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Local Configuration',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Logo
            Center(
              child: Column(
                children: [
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(50),
                    child: CustomPaint(
                      painter: _SetupDashedBorderPainter(color: const Color(0xFF94A3B8), radius: 50),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: _buildLogoWidget(_logoBase64),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('SCHOOL LOGO (LOCAL)', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Fields
            _buildLabeledField('SCHOOL NAME', _schoolNameCtrl, hint: 'e.g. School Name'),
            const SizedBox(height: 16),
            _buildLabeledField('VEHICLE NAME / ID', _vanScopeCtrl, editableLabel: 'Editable', hint: 'e.g. Van 01'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildLabeledField('VEHICLE NO.', _vehNoCtrl, hint: 'RJ-XX-XXXX')),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TYPE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _selectedVehType,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                        ),
                        items: ['Van', 'Bus', 'Mini Bus', 'Private', 'Shift']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: widget.isLocked ? null : (v) => setState(() => _selectedVehType = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLabeledField('TEACHER IN-CHARGE', _teacherCtrl, readOnly: widget.isLocked),
            const SizedBox(height: 16),
            _buildLabeledField('DRIVER NAME', _driverCtrl, readOnly: widget.isLocked),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleSave,
                icon: Icon(widget.isLocked ? Icons.lock : Icons.save_rounded, color: Colors.white),
                label: Text(widget.isLocked ? 'Setup Locked by Admin' : 'Save Configuration', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isLocked ? const Color(0xFF94A3B8) : const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),

            if (!widget.isGlobalSetup && widget.onDeleteVehicle != null && !widget.isLocked) ...[
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(context: context, builder: (c) => AlertDialog(
                      title: const Text('Delete Vehicle?'),
                      content: const Text('Do you want to delete this vehicle? This will flush all data associated with it.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(c);
                            widget.onDeleteVehicle!();
                          },
                          child: const Text('Yes, Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ));
                  },
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: Text('Delete Vehicle', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledField(String label, TextEditingController controller, {String? hint, String? editableLabel, String? valueText, bool readOnly = false}) {
    if (valueText != null && controller.text.isEmpty) {
      controller.text = valueText;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
            if (editableLabel != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFFC107), borderRadius: BorderRadius.circular(4)),
                child: Text(editableLabel, style: GoogleFonts.plusJakartaSans(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: editableLabel != null ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6C757D), fontWeight: FontWeight.w400, fontSize: 15),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
          ),
        ),
      ],
    );
  }
}

class _SetupDashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  _SetupDashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 2.0,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
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

    for (var measurePath in path.computeMetrics()) {
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
