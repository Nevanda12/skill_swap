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

  // 3. Service untuk Mendapatkan Rekomendasi (Discovery) & Pencarian
  static Future<Map<String, dynamic>> discoverUsers(int userId, {String? searchName, String? filterSkill}) async {
    // Membangun URL beserta parameter filter jika ada
    var uri = Uri.parse('$baseUrl/discover/$userId');
    Map<String, String> queryParams = {};
    
    if (searchName != null && searchName.trim().isNotEmpty) {
      queryParams['search_name'] = searchName.trim();
    }
    if (filterSkill != null && filterSkill.isNotEmpty && filterSkill != 'Semua Skill') {
      queryParams['filter_skill'] = filterSkill;
    }

    if (queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    try {
      final response = await http.get(uri);
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
// 5. Service untuk Mendapatkan Riwayat Chat
  static Future<Map<String, dynamic>> getChatHistory(int matchId) async {
    final url = Uri.parse('$baseUrl/chat/history/$matchId');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal memuat chat: $e"};
    }
  }

  // 6. Service untuk Mengirim Pesan Chat
  static Future<Map<String, dynamic>> sendChatMessage({
    required int matchId,
    required int senderId,
    required String message,
  }) async {
    final url = Uri.parse('$baseUrl/chat/send');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "match_id": matchId,
          "sender_id": senderId,
          "message": message,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal mengirim pesan: $e"};
    }
  }

static Future<Map<String, dynamic>> getActiveMatches(int userId) async {
    final url = Uri.parse('$baseUrl/matches/active/$userId');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal memuat daftar chat: $e"};
    }
  }
  
// 7. Service untuk Mengubah Status Match (Workflow State)
  static Future<Map<String, dynamic>> updateMatchStatus({
    required int matchId,
    required int currentUserId,
    required String newStatus,
  }) async {
    final url = Uri.parse('$baseUrl/match/status');
    
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "match_id": matchId,
          "current_user_id": currentUserId,
          "new_status": newStatus,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal memperbarui status: $e"};
    }
  }

// 8. Service untuk Mengirim Ulasan (Rating & Review)
  static Future<Map<String, dynamic>> submitReview({
    required int matchId,
    required int reviewerId,
    required int reviewedUserId, // ID lawan bicara
    required int rating,
    required String reviewText,
  }) async {
    final url = Uri.parse('$baseUrl/review/submit');
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "match_id": matchId,
          "reviewer_id": reviewerId,
          "reviewed_user_id": reviewedUserId,
          "rating": rating,
          "review_text": reviewText,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal mengirim ulasan: $e"};
    }
  }

// 9. Service untuk Mengecek Status Ulasan (Apakah sudah pernah menilai)
  static Future<Map<String, dynamic>> checkReviewStatus({
    required int matchId,
    required int reviewerId,
  }) async {
    final url = Uri.parse('$baseUrl/review/check/$matchId/$reviewerId');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal mengecek ulasan: $e"};
    }
  }

// 10. Service untuk Mendapatkan Profil, Rating, & Keahlian User
  static Future<Map<String, dynamic>> getUserProfile(int userId) async {
    final url = Uri.parse('$baseUrl/profile/$userId');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal memuat profil: $e"};
    }
  }

// 11. Service untuk Mendapatkan Daftar Ulasan User
  static Future<Map<String, dynamic>> getUserReviews(int userId) async {
    final url = Uri.parse('$baseUrl/profile/reviews/$userId');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal memuat daftar ulasan: $e"};
    }
  }

// 12. Service untuk Update Foto Profil
  static Future<Map<String, dynamic>> updateProfilePhoto({
    required int userId,
    required String photoBase64,
  }) async {
    final url = Uri.parse('$baseUrl/profile/photo');
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "photo_base64": photoBase64,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal update foto: $e"};
    }
  }

  // 12b. Service untuk Update Latar Belakang Profil
  static Future<Map<String, dynamic>> updateBackgroundPhoto({
    required int userId,
    required String photoBase64,
  }) async {
    final url = Uri.parse('$baseUrl/profile/background');
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "photo_base64": photoBase64,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal update background: $e"};
    }
  }

  // 13. Service untuk Update Skills
  static Future<Map<String, dynamic>> saveUserSkills({
    required int userId,
    required List<Map<String, String>> skills,
  }) async {
    final url = Uri.parse('$baseUrl/user-skills');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "skills": skills,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal update skills: $e"};
    }
  }

// 14. Service untuk Mengecek Notifikasi Pesan Baru (Unread)
  static Future<Map<String, dynamic>> checkUnreadMessages(int userId) async {
    final url = Uri.parse('$baseUrl/chat/unread/$userId');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal mengecek notifikasi pesan: $e"};
    }
  }

  // 15. Service untuk Menandai Pesan Telah Dibaca
  static Future<Map<String, dynamic>> markMessagesAsRead({
    required int matchId,
    required int userId,
  }) async {
    final url = Uri.parse('$baseUrl/chat/read/$matchId/$userId');
    try {
      final response = await http.put(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal update status baca: $e"};
    }
  }

// 16. Service untuk Menghapus Obrolan (Delete Match)
  static Future<Map<String, dynamic>> deleteMatch(int matchId) async {
    final url = Uri.parse('$baseUrl/match/delete/$matchId');
    try {
      final response = await http.delete(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal menghapus obrolan: $e"};
    }
  }

  // 17. Service untuk Memblokir Pengguna
  static Future<Map<String, dynamic>> blockUser({
    required int blockerId,
    required int blockedId,
  }) async {
    final url = Uri.parse('$baseUrl/user/block');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "blocker_id": blockerId,
          "blocked_id": blockedId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal memblokir pengguna: $e"};
    }
  }

// 18. Service untuk Mengambil Rekap Skill di Halaman Jelajah
  static Future<Map<String, dynamic>> getSkillsSummary() async {
    final url = Uri.parse('$baseUrl/skills/summary');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal memuat rekap skill: $e"};
    }
  }
}