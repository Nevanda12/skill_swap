import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  // Gunakan 10.0.2.2 jika running di Emulator Android lokal
  static const String baseUrl = "http://192.168.43.190:8000/api";

  // 1. Service untuk Registrasi User
  static Future<Map<String, dynamic>> registerUser({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/register');
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "full_name": fullName,
          "email": email,
          "password": password,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal terhubung ke server: $e"};
    }
  }

  // 2. Service untuk Login User
  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal terhubung ke server: $e"};
    }
  }
}