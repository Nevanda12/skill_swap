import 'package:shared_preferences/shared_preferences.dart';

/// Mengelola status login yang tersimpan di HP (bukan di server),
/// supaya user tidak perlu login ulang setiap buka aplikasi.
class SessionService {
  static const String _keyUserId = 'user_id';
  static const String _keyFullName = 'full_name';
  static const String _keyEmail = 'email';

  /// Dipanggil setelah login (manual maupun Google) berhasil.
  static Future<void> saveSession({
    required int userId,
    required String fullName,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyFullName, fullName);
    await prefs.setString(_keyEmail, email);
  }

  /// Mengembalikan user_id yang tersimpan, atau null kalau belum pernah
  /// login / sudah logout. Dipanggil dari SplashScreen.
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullName);
  }

  /// Menghapus semua data sesi. Dipanggil saat user menekan tombol logout.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyEmail);
  }
}