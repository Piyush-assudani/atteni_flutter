import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class ExportTab extends StatelessWidget {
  final List<Map<dynamic, dynamic>> students;
  final Map<String, dynamic> attendanceMap;
  final DateTime selectedDate;
  final Map<dynamic, dynamic> setupData;
  final String currentScope;

  const ExportTab({
    super.key,
    required this.students,
    required this.attendanceMap,
    required this.selectedDate,
    required this.setupData,
    required this.currentScope,
  });

  String _getStatus(String id) {
    final val = attendanceMap[id];
    if (val == null) return '';
    if (val is Map) return val['status'] ?? '';
    return val.toString();
  }

  Map<String, int> _calculateStats() {
    int p = 0, a = 0, e = 0, h = 0;
    for (var s in students) {
      final status = _getStatus(s['id'].toString());
      if (status == 'P') p++;
      else if (status == 'A') a++;
      else if (status == 'E') e++;
      else if (status == 'H') h++;
    }
    return {'Total': students.length, 'P': p, 'A': a, 'E': e, 'H': h};
  }

  Future<void> _generatePdf(BuildContext context) async {
    if (currentScope == 'All') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a specific vehicle to export.')));
      return;
    }
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students to export.')));
      return;
    }

    final doc = pw.Document();
    final dateStr = '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';

    pw.ImageProvider? logoImage;
    final logoUrlStr = setupData['logoUrl']?.toString() ?? '';
    if (logoUrlStr.isNotEmpty) {
      try {
        if (logoUrlStr.startsWith('data:image')) {
          final split = logoUrlStr.split(',');
          if (split.length == 2) {
            logoImage = pw.MemoryImage(base64Decode(split[1]));
          }
        } else if (logoUrlStr.startsWith('http')) {
          logoImage = await networkImage(logoUrlStr);
        }
      } catch (_) {}
    }
    
    if (logoImage == null) {
      try {
        final bytes = await rootBundle.load('logo.webp');
        logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {
        try {
          final bytes = await rootBundle.load('logo.jpeg');
          logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
        } catch (_) {}
      }
    }

    final tableData = students.asMap().entries.map((entry) {
      int idx = entry.key;
      var s = entry.value;
      final statusRaw = _getStatus(s['id'].toString());
      final status = statusRaw == 'P' ? 'Present' : statusRaw == 'A' ? 'Absent' : statusRaw == 'E' ? 'Early' : '-';
      return [
        (idx + 1).toString(),
        s['name'] ?? '',
        '${s['class'] ?? ''} ${s['section'] ?? ''}'.trim(),
        status,
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 40,
                    height: 40,
                    margin: const pw.EdgeInsets.only(right: 10),
                    child: pw.Image(logoImage),
                  ),
                pw.Text(
                  setupData['schoolName'] ?? 'Attendance Report',
                  style: pw.TextStyle(
                    font: pw.Font.timesBold(),
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Date: $dateStr', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10, color: const PdfColor.fromInt(0xFF3C3C3C))),
                    pw.SizedBox(height: 4),
                    pw.Text('Teacher: ${setupData['teacher'] ?? '-'}', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10, color: const PdfColor.fromInt(0xFF3C3C3C))),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Vehicle No: ${setupData['vehNo'] ?? '-'}', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10, color: const PdfColor.fromInt(0xFF3C3C3C))),
                    pw.SizedBox(height: 4),
                    pw.Text('Driver: ${setupData['driver'] ?? '-'}', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10, color: const PdfColor.fromInt(0xFF3C3C3C))),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Student Name', 'Class', 'Status'],
              data: tableData,
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
              headerStyle: pw.TextStyle(font: pw.Font.timesBold(), color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF282828)), // [40, 40, 40]
              cellStyle: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10),
              cellHeight: 22,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
              },
              oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)), // [245, 245, 245]
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated via Atteni Premium',
                style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: const PdfColor.fromInt(0xFF969696)), // 150
              ),
            ),
          ];
        },
      ),
    );

    final fileName = 'Attendance_${currentScope}_$dateStr.pdf';
    final bytes = await doc.save();
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      debugPrint('Error saving/opening PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 8),
                    Text('Export', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Generate a printable PDF report for the selected date and vehicle.', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF64748B))),
                const SizedBox(height: 24),
                
                Text('REPORT DATE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                      const Icon(Icons.calendar_today, color: Color(0xFF1E293B), size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)), // shadow-sm
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _generatePdf(context),
                    icon: const Icon(Icons.picture_as_pdf, size: 20),
                    label: const Text('Download PDF Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5), // btn-primary
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // PDF Preview Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(0), // HTML uses sharp/A4 look for the inner page, or slightly rounded wrapper
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, spreadRadius: -10, offset: const Offset(0, 20)),
              ],
            ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Text(setupData['schoolName'] ?? 'ATTENDANCE REPORT', style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Color(0xFF333333))),
                  const SizedBox(height: 8),
                  Text('Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')} | Scope: $currentScope', style: const TextStyle(fontFamily: 'sans-serif', fontSize: 12, color: Color(0xFF666666))),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF333333), thickness: 2.0),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(text: TextSpan(style: const TextStyle(fontSize: 11, color: Color(0xFF555555)), children: [const TextSpan(text: 'Teacher: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: '${setupData['teacher'] ?? '-'}')])),
                          const SizedBox(height: 8),
                          RichText(text: TextSpan(style: const TextStyle(fontSize: 11, color: Color(0xFF555555)), children: [const TextSpan(text: 'Vehicle No: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: '${setupData['vehNo'] ?? '-'}')])),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          RichText(text: TextSpan(style: const TextStyle(fontSize: 11, color: Color(0xFF555555)), children: [const TextSpan(text: 'Driver: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: '${setupData['driver'] ?? '-'}')])),
                          const SizedBox(height: 8),
                          RichText(text: TextSpan(style: const TextStyle(fontSize: 11, color: Color(0xFF555555)), children: [const TextSpan(text: 'Vehicle Type: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: '${setupData['vehType'] ?? '-'}')])),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Table
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFFF8F9FA)), // background: #f8f9fa;
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Present: ${stats['P'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                        Text('Early: ${stats['E'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                        Text('Absent: ${stats['A'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                        Text('Total: ${stats['Total'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    color: const Color(0xFFE0E7FF), // background: #e0e7ff;
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Text('#', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 3, child: Text('Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 3, child: Text('Class', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 3, child: Text('Status', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF999999)),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: students.length,
                    itemBuilder: (ctx, i) {
                      final s = students[i];
                        final stRaw = _getStatus(s['id'].toString());
                        final stText = stRaw == 'P' ? 'Present' : stRaw == 'A' ? 'Absent' : stRaw == 'E' ? 'Early' : '-';
                        final stColor = stRaw == 'P' ? Colors.green : stRaw == 'A' ? Colors.red : stRaw == 'E' ? Colors.orange : const Color(0xFFAAAAAA);
                        
                        return Container(
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 1, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 3, child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 3, child: Text('${s['class'] ?? ''}'.trim(), style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 3, child: Text(stText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stColor))),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 40),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Generated via Atteni Premium', style: const TextStyle(fontSize: 10, color: Color(0xFF999999))),
                  ),
                  const SizedBox(height: 48),
                  Text('ATTENI PREMIUM © 2026', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Owned & Developed by Piyush Assudani — Founder, Assudani Group', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF64748B))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
