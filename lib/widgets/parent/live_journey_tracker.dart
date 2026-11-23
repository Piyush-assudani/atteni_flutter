import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';

class LiveJourneyTracker extends StatefulWidget {
  final String studentId;

  const LiveJourneyTracker({Key? key, required this.studentId}) : super(key: key);

  @override
  State<LiveJourneyTracker> createState() => _LiveJourneyTrackerState();
}

class _LiveJourneyTrackerState extends State<LiveJourneyTracker> {
  bool _isLoading = true;
  bool _isPresent = false;
  DateTime? _markedAt;
  int _journeyDurationMins = 45;
  
  Timer? _timer;
  double _progressPercent = 0.0;
  int _remainingMins = 0;

  @override
  void initState() {
    super.initState();
    _fetchTodayAttendance();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTodayAttendance() async {
    try {
      final today = DateTime.now();
      final dateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final prefs = await SharedPreferences.getInstance();
      final schoolId = prefs.getString('SELECTED_SCHOOL') ?? 'DPS';
      
      final dbRef = FirebaseService().getBaseRef(schoolId).child('attendance/$dateStr/list/${widget.studentId}');
      final snap = await dbRef.get();
      
      if (snap.exists && snap.value != null) {
        final data = snap.value;
        String status = '';
        int timestamp = 0;
        
        if (data is Map) {
          status = data['status']?.toString() ?? '';
          timestamp = data['timestamp'] != null ? int.tryParse(data['timestamp'].toString()) ?? 0 : 0;
          if (timestamp == 0 && data['markedAt'] != null) {
            timestamp = int.tryParse(data['markedAt'].toString()) ?? 0;
          }
        } else if (data is String) {
          status = data;
        }

        bool isP = status.toLowerCase() == 'p' || status.toLowerCase() == 'present' || status.toLowerCase() == 'true';
        
        if (isP) {
          _isPresent = true;
          if (timestamp > 0) {
            // Firebase timestamp is usually in milliseconds
            _markedAt = DateTime.fromMillisecondsSinceEpoch(timestamp > 9999999999 ? timestamp : timestamp * 1000);
          } else {
            // Fallback to start of day if no timestamp exists
            _markedAt = DateTime(today.year, today.month, today.day, 8, 0); // Assuming 8 AM
          }
          _startTrackerTimer();
        }
      }
    } catch (e) {
      debugPrint("Error fetching live attendance: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startTrackerTimer() {
    _updateProgress();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateProgress();
    });
  }

  void _updateProgress() {
    if (!mounted || _markedAt == null) return;
    
    final now = DateTime.now();
    final elapsedSeconds = now.difference(_markedAt!).inSeconds;
    final totalSeconds = _journeyDurationMins * 60;
    
    double progress = (elapsedSeconds / totalSeconds) * 100;
    if (progress < 0) progress = 0;
    if (progress > 100) progress = 100;
    
    int remaining = ((totalSeconds - elapsedSeconds) / 60).floor();
    if (remaining < 0) remaining = 0;

    setState(() {
      _progressPercent = progress;
      _remainingMins = remaining;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFEFF6FF)]),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isPresent) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFEFF6FF)]),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('LIVE STATUS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade600, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Not Present Yet', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(height: 4, decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(2))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIconNode(Icons.school, 'SCHOOL'),
                    _buildIconNode(Icons.home, 'HOME'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(child: Text('Waiting for attendance...', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade400))),
          ],
        ),
      );
    }

    // Is Present, show animated tracker
    bool isArrived = _progressPercent >= 100;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: 0.9), Colors.indigo.shade50.withValues(alpha: 0.5)]),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.indigo.shade100.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8, 
                    height: 8, 
                    decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                    // If we wanted pulse we'd use an animation controller, but a static dot is fine for now
                  ),
                  const SizedBox(width: 8),
                  Text('LIVE STATUS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade500, letterSpacing: 1)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(isArrived ? 'Reached Home' : 'Vehicle En-Route', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
          const SizedBox(height: 40),
          
          // Tracker Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(height: 6, decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(3))),
                
                // Active progress
                FractionallySizedBox(
                  widthFactor: _progressPercent / 100,
                  child: Container(
                    height: 6, 
                    decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                
                // Endpoints
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIconNode(Icons.school, 'SCHOOL', active: true),
                    _buildIconNode(Icons.home, 'HOME', active: isArrived),
                  ],
                ),
                
                // Moving Bus
                Positioned(
                  left: 0,
                  right: 0,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressPercent / 100,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.indigo.shade500.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                )
                              ]
                            ),
                            child: const Icon(Icons.directions_bus, color: Colors.white, size: 14),
                          ),
                          // Badge
                          Positioned(
                            top: -30,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: 1.0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade900,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isArrived ? 'HOME' : '$_remainingMins min',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Journey Settings
          Container(
            padding: const EdgeInsets.only(top: 24),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.indigo.shade100.withValues(alpha: 0.5))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('JOURNEY SETTINGS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade400, letterSpacing: 1)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$_journeyDurationMins Mins', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade600)),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: Colors.indigo,
                    inactiveTrackColor: Colors.blueGrey.shade100,
                    thumbColor: Colors.white,
                    overlayColor: Colors.indigo.withValues(alpha: 0.1),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 2),
                  ),
                  child: Slider(
                    value: _journeyDurationMins.toDouble(),
                    min: 10,
                    max: 180,
                    divisions: 34, // (180-10)/5 = 34
                    onChanged: (val) {
                      setState(() {
                        _journeyDurationMins = val.toInt();
                        _updateProgress();
                      });
                    },
                  ),
                ),
                Center(
                  child: Text(
                    isArrived ? 'Vehicle arrived at destination' : 'ETA: ~$_remainingMins mins to destination',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade500),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildIconNode(IconData icon, String label, {bool active = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40, 
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white, 
            shape: BoxShape.circle, 
            border: Border.all(color: active ? Colors.indigo.shade200 : Colors.blueGrey.shade200, width: 2),
            boxShadow: active ? [
              BoxShadow(color: Colors.indigo.withValues(alpha: 0.1), blurRadius: 10)
            ] : null
          ),
          child: Icon(icon, color: active ? Colors.indigo.shade400 : Colors.blueGrey.shade400, size: 20),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: active ? Colors.indigo.shade400 : Colors.blueGrey.shade400)),
      ],
    );
  }
}
