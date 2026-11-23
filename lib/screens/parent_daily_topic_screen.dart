import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/premium_alert.dart';
import '../widgets/premium_toast.dart';

class ParentDailyTopicScreen extends StatefulWidget {
  const ParentDailyTopicScreen({super.key});

  @override
  State<ParentDailyTopicScreen> createState() => _ParentDailyTopicScreenState();
}

class _ParentDailyTopicScreenState extends State<ParentDailyTopicScreen> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _classCtrl = TextEditingController();
  final TextEditingController _sectionCtrl = TextEditingController();
  bool _isLoading = false;

  List<Map<String, dynamic>> _topicsFound = [];
  bool _hasSearched = false;

  Future<void> _fetchTopics() async {
    final c = _classCtrl.text.trim();
    if (c.isEmpty) {
      PremiumAlert.showError(
        context,
        title: 'Class Required',
        text: 'Please enter the class number (e.g. 5) to view curriculum topics.',
      );
      return;
    }
    final s = _sectionCtrl.text.trim();
    if (_isLoading) return; // Prevent double-tap
    
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _topicsFound = [];
    });

    try {
      final String targetDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final prefs = await SharedPreferences.getInstance();
      final connectedSchool = prefs.getString('SELECTED_SCHOOL') ?? 'DPS';

      final response = await http
          .get(Uri.parse('https://atteni-otp.piyushassudani.in/api/tasks/get_all?date=$targetDate&school_code=$connectedSchool'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        if (resData['success'] == true && resData['data'] is List) {
          final allTasks = resData['data'] as List;
          List<Map<String, dynamic>> found = [];

          for (var taskEntry in allTasks) {
            if (taskEntry is! Map) continue;
            // Filter by school if school_code exists
            final entrySchool = (taskEntry['school_code'] ?? '').toString().trim();
            if (entrySchool.isNotEmpty && entrySchool.toUpperCase() != connectedSchool.toUpperCase()) {
              continue;
            }
            // Check date match
            if (taskEntry['date'] == targetDate) {
              final periods = taskEntry['periods'] as List?;
              if (periods != null) {
                final teacherName = taskEntry['task_users'] != null ? (taskEntry['task_users']['name'] ?? 'Unknown Teacher') : 'Unknown Teacher';
                
                for (var p in periods) {
                  if (p is! Map) continue;
                  final pClass = (p['class'] ?? '').toString();
                  final pSection = (p['section'] ?? '').toString();
                  final topic = (p['topic'] ?? '').toString();
                  
                  if (pClass.toLowerCase() == c.toLowerCase() && (s.isEmpty || pSection.toLowerCase() == s.toLowerCase())) {
                    if (topic.isNotEmpty) {
                      found.add({
                        'subject': p['subject'] ?? 'General',
                        'topic': topic,
                        'teacher': teacherName,
                      });
                    }
                  }
                }
              }
            }
          }
          
          if (mounted) {
            setState(() {
              _topicsFound = found;
            });
            if (found.isNotEmpty) {
              PremiumToast.showSuccess(context, 'Found ${found.length} topic${found.length > 1 ? 's' : ''} taught!');
            }
          }
        }
      } else {
        if (mounted) {
          PremiumAlert.showError(
            context,
            title: 'Unable to Load Topics',
            text: 'Server returned error status (${response.statusCode}). Please try again later.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        PremiumAlert.showError(
          context,
          title: 'Network Error',
          text: 'Unable to reach the curriculum server. Please check your internet connection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        if (_hasSearched) _fetchTopics();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Top Pill Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Back Button
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF334155)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'logo.webp',
                        height: 28,
                        width: 28,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported, size: 28, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // ATTENI Text
                    Text(
                      'ATTENI',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Version Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'v1.0.4',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // About Button (Premium subtle colored pill)
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/developer_profile'),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 6),
                            Text(
                              'About',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Topic Taught',
                            style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: const Color(0xFF111827), letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter class details to see what was taught today.',
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280)),
                          ),
                    const SizedBox(height: 24),
                    
                    // Date Selector
                    Text('Date', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                            Icon(Icons.calendar_today_rounded, size: 20, color: Colors.grey.shade500),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Class & Section
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Class (e.g. 10)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: TextField(
                                  controller: _classCtrl,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sec (Opt)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: TextField(
                                  controller: _sectionCtrl,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Search Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _fetchTopics,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Search Topics', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Results List
              if (_hasSearched && !_isLoading) ...[
                if (_topicsFound.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No topics found for this day.', style: GoogleFonts.inter(color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  )
                else
                  ..._topicsFound.map((t) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t['subject'],
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue.shade100),
                                  ),
                                  child: Text(
                                    t['teacher'],
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t['topic'],
                              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade800, height: 1.5),
                            ),
                          ],
                        ),
                      )).toList(),
              ],
            ],
          ),
        ),
       ),
      ],
     ),
    ),
   );
  }
}
