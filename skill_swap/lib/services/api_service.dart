import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  // Pastikan IP ini sesuai dengan IP laptopmu yang sukses!
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

  // 3. Service untuk Mendapatkan Rekomendasi (Discovery)
  static Future<Map<String, dynamic>> discoverUsers(int userId) async {
    final url = Uri.parse('$baseUrl/discover/$userId');

    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal terhubung ke server: $e"};
    }
  }


// 4. Service untuk Melakukan Swipe (Like / Dislike)
  static Future<Map<String, dynamic>> swipeUser({
    required int swiperId,
    required int swipedId,
    required bool isLiked,
  }) async {
    final url = Uri.parse('$baseUrl/swipe');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "swiper_id": swiperId,
          "swiped_id": swipedId,
          "is_liked": isLiked,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal terhubung ke server: $e"};
    }
  }

}