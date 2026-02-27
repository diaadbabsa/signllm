import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  static Map<String, String> _authHeaders(String token) => {
        ..._defaultHeaders,
        'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login/'),
      headers: _defaultHeaders,
      body: jsonEncode({'username': username, 'password': password}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    } else {
      return {
        'success': false,
        'error': data['error'] ?? 'حدث خطأ غير متوقع',
      };
    }
  }

  static Future<Map<String, dynamic>?> getMe(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me/'),
        headers: _authHeaders(accessToken),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> refreshToken(String refresh) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/token/refresh/'),
        headers: _defaultHeaders,
        body: jsonEncode({'refresh': refresh}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['access'];
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> uploadVideo(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final ext = filePath.split('.').last.toLowerCase();
    final mimeMap = {
      'mp4': 'video/mp4',
      'webm': 'video/webm',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
    };
    final mime = mimeMap[ext] ?? 'video/mp4';
    final parts = mime.split('/');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/videos/analyze/'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['ngrok-skip-browser-warning'] = 'true';
    request.files.add(
      await http.MultipartFile.fromPath(
        'video',
        filePath,
        contentType: MediaType(parts[0], parts[1]),
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 300),
    );
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return {
        'success': true,
        'result': data['result'] ?? '',
        'avatar_url': data['avatar_url'],
      };
    } else {
      return {
        'success': false,
        'error': data['error'] ?? 'حدث خطأ غير متوقع',
      };
    }
  }
}
