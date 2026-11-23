import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';

class AttendanceTab extends StatelessWidget {
  final List<Map<dynamic, dynamic>> students;
  final Map<String, dynamic> attendanceMap;
  final DateTime selectedDate;
  final bool isHoliday;
  final Function(DateTime) onDateChanged;
  final Function(String, String) onMarkAttendance;
  final VoidCallback onMarkAllPresent;
  final VoidCallback onMarkAllAbsent;
  final Function(bool) onToggleHoliday;
  final VoidCallback onFinalSave;
  final bool isSyncing;
  final bool justSynced;

  const AttendanceTab({
    super.key,
    required this.students,
    required this.attendanceMap,
    required this.selectedDate,
    required this.isHoliday,
    required this.onDateChanged,
    required this.onMarkAttendance,
    required this.onMarkAllPresent,
    required this.onMarkAllAbsent,
    required this.onToggleHoliday,
    required this.onFinalSave,
    this.isSyncing = false,
    this.justSynced = false,
  });

  String _getStatus(String id) {
    if (isHoliday) return 'H';
    final val = attendanceMap[id];
    if (val == null) return '';
    if (val is Map) return val['status'] ?? '';
    return val.toString();
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
            if (isHoliday)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy, color: Color(0xFF92400E), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This day is marked as a HOLIDAY. No attendance required.',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF92400E),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => onToggleHoliday(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text('Unmark', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  ],
                ),
              ),

            // Date & Mark All Buttons Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;

                Widget datePicker = SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ATTENDANCE DATE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) onDateChanged(date);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFF0D6EFD)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy').format(selectedDate),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0D6EFD),
                                ),
                              ),
                              const Icon(Icons.calendar_today, color: Color(0xFF0D6EFD), size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                Widget actionButtons = SizedBox(
                  width: isMobile ? double.infinity : 350,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderBtn(
                              icon: Icons.done_all,
                              label: 'All Present',
                              color: const Color(0xFF198754),
                              onPressed: isHoliday ? null : onMarkAllPresent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHeaderBtn(
                              icon: Icons.highlight_off,
                              label: 'All Absent',
                              color: const Color(0xFFDC3545),
                              onPressed: isHoliday ? null : onMarkAllAbsent,
                            ),
                          ),
                        ],
                      ),
                      if (!isHoliday) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => onToggleHoliday(true),
                            icon: const Icon(Icons.event_busy, size: 16),
                            label: const Text('Holiday'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF3CD),
                              foregroundColor: const Color(0xFF856404),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFFFFEEBA)),
                              ),
                              textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13.5),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      datePicker,
                      const SizedBox(height: 16),
                      actionButtons,
                    ],
                  );
                } else {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      datePicker,
                      actionButtons,
                    ],
                  );
                }
              },
            ),
            
            const SizedBox(height: 16),

            // List/Table
            LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 600;

                if (students.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFDEE2E6)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('No students available for attendance.', style: TextStyle(color: Color(0xFF6C757D)))),
                  );
                }

                // Dynamic Column Flex and Text Styles for Mobile/Desktop Table
                // No more squishing text on mobile, just horizontal scroll!
                final double fontSizeName = 13.5;
                final double fontSizeDetails = 12.0;
                
                final int flexName = 4;
                final int flexDetails = 2;
                final int flexStatus = 3;
                final int flexMark = 3;

                Widget tableContent = SizedBox(
                  width: constraints.maxWidth < 600 ? 600.0 : constraints.maxWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFDEE2E6)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: const Color(0xFFF8F9FA),
                          child: Row(
                            children: [
                              Expanded(flex: flexName, child: Text('Student', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 13.5))),
                              Expanded(flex: flexDetails, child: Text('Details', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 13.5))),
                              Expanded(flex: flexStatus, child: Text('Status', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 13.5))),
                              Expanded(flex: flexMark, child: Text('Mark', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF212529), fontSize: 13.5))),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFDEE2E6), thickness: 1),
                        
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                            itemCount: students.length,
                            separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFDEE2E6), thickness: 1),
                            itemBuilder: (context, i) {
                              final s = students[i];
                              final id = s['id'].toString();
                              final status = _getStatus(id);

                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: isMobile ? 8 : 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: flexName,
                                      child: Text(
                                        s['name'] ?? '', 
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: fontSizeName, color: const Color(0xFF212529)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: flexDetails,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('Cls ${s['class'] ?? ''}', style: GoogleFonts.plusJakartaSans(fontSize: fontSizeDetails, fontWeight: FontWeight.bold, color: const Color(0xFF6C757D))),
                                          Text('Sec ${s['section'] ?? ''}', style: GoogleFonts.plusJakartaSans(fontSize: fontSizeDetails, fontWeight: FontWeight.bold, color: const Color(0xFF6C757D))),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: flexStatus,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildStatusPill(status, isMobile: isMobile),
                                      ),
                                    ),
                                    Expanded(
                                      flex: flexMark,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: _buildButtonGroup(id, status, isMobile: isMobile),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );

                if (isMobile) {
                  return Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: tableContent,
                    ),
                  );
                }
                return tableContent;
              },
            ),
            
            // Footer (Sync Button)
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.only(top: 24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFDEE2E6))),
              ),
              child: Center(
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: students.isEmpty ? null : onFinalSave,
                      icon: const Icon(Icons.cloud_upload, size: 20),
                      label: const Text('Final Save to Cloud'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        shadowColor: const Color(0xFF4F46E5).withOpacity(0.5),
                        textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isSyncing)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text(
                            'Saving latest change to cloud...',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF0284C7), fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    else if (justSynced)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                          const SizedBox(width: 6),
                          Text(
                            'All changes saved to cloud',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Attendance loaded. Auto-save is active.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF6C757D), fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBtn({required IconData icon, required String label, required Color color, required VoidCallback? onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: GoogleFonts.plusJakartaSans(color: color, fontWeight: FontWeight.bold, fontSize: 12.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0, 
      ),
    );
  }

  Widget _buildStatusPill(String status, {bool isMobile = false}) {
    Color bg, text;
    String label;
    switch (status) {
      case 'P':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        label = 'PRESENT';
        break;
      case 'A':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        label = 'ABSENT';
        break;
      case 'E':
        bg = const Color(0xFFFEF9C3);
        text = const Color(0xFF854D0E);
        label = 'EARLY';
        break;
      case 'H':
        bg = const Color(0xFFF3E8FF);
        text = const Color(0xFF7E22CE);
        label = 'HOLIDAY';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF94A3B8);
        label = '-';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 14, vertical: isMobile ? 4 : 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: text,
          fontSize: isMobile ? 9 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildButtonGroup(String id, String status, {bool isMobile = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildGroupBtn('P', status == 'P', const Color(0xFF198754), true, false, () => onMarkAttendance(id, 'P'), isMobile: isMobile),
        _buildGroupBtn('E', status == 'E', const Color(0xFFFFC107), false, false, () => onMarkAttendance(id, 'E'), isMobile: isMobile),
        _buildGroupBtn('A', status == 'A', const Color(0xFFDC3545), false, true, () => onMarkAttendance(id, 'A'), isMobile: isMobile),
      ],
    );
  }

  Widget _buildGroupBtn(String label, bool isSelected, Color baseColor, bool isFirst, bool isLast, VoidCallback onTap, {bool isMobile = false}) {
    final bgColor = isSelected ? baseColor : Colors.transparent;
    final textColor = isSelected ? Colors.white : (label == 'E' ? Colors.black87 : baseColor);
    final borderColor = isSelected ? baseColor : const Color(0xFFE2E8F0).withValues(alpha: 0.6);

    return InkWell(
      onTap: isHoliday ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 4 : 6),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
            left: BorderSide(color: borderColor),
            right: isLast ? BorderSide(color: borderColor) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? const Radius.circular(6) : Radius.zero,
            bottomLeft: isFirst ? const Radius.circular(6) : Radius.zero,
            topRight: isLast ? const Radius.circular(6) : Radius.zero,
            bottomRight: isLast ? const Radius.circular(6) : Radius.zero,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 12 : 14,
          ),
        ),
      ),
    );
  }
}
