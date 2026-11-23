import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceSyncService {
  static const String _prefix = 'att_v2_';

  // Save attendance locally
  static Future<void> saveLocally(String date, String scope, Map<String, dynamic> attendanceList) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${date}_$scope';
    
    final payload = {
      'list': attendanceList,
      'lastUpdatedLocal': DateTime.now().toIso8601String(), // We use local time for the ISO string, but it serves to indicate dirty status
      'isLocalDirty': true,
    };
    
    await prefs.setString(key, jsonEncode(payload));
  }

  // Load local attendance
  static Future<Map<String, dynamic>?> loadLocally(String date, String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${date}_$scope';
    
    final data = prefs.getString(key);
    if (data != null) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Clear local attendance (used when successfully synced to cloud)
  static Future<void> clearLocal(String date, String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${date}_$scope';
    await prefs.remove(key);
  }
}
