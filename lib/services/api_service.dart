import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String customBackendUrl = 'https://atteni-otp.piyushassudani.in';

  static Future<bool> requestOTP(String phone, {String type = 'signup'}) async {
    final res = await requestOTPWithDetails(phone, type: type);
    return res['success'] == true;
  }

  static Future<Map<String, dynamic>> requestOTPWithDetails(String phone, {String type = 'signup'}) async {
    try {
      final response = await http.post(
        Uri.parse('$customBackendUrl/api/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'type': type}),
      ).timeout(const Duration(seconds: 12));

      try {
        final body = jsonDecode(response.body);
        if (response.statusCode == 200) {
          return {'success': true, 'message': body['message'] ?? 'OTP sent successfully'};
        } else if (response.statusCode == 429) {
          return {'success': false, 'message': 'Too many OTP requests. Please wait 5 minutes.'};
        } else if (response.statusCode == 404) {
          return {'success': false, 'message': 'No student found linked with this mobile number in school records.'};
        }
        return {'success': false, 'message': body['message'] ?? 'Unable to send OTP (${response.statusCode})'};
      } catch (_) {
        return {'success': false, 'message': 'Server error (${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network connection error. Check your internet connection.'};
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(String phone, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$customBackendUrl/api/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'code': code}),
      ).timeout(const Duration(seconds: 12));
      
      try {
        final body = jsonDecode(response.body);
        return body is Map<String, dynamic> ? body : {'success': false, 'message': 'Invalid response'};
      } catch (_) {
        return {'success': false, 'message': 'Server response error (${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network connection error. Check your internet connection.'};
    }
  }
}
