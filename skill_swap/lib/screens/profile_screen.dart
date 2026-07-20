import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert'; // <-- TAMBAHKAN BARIS INI
import 'review_list_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int currentUserId; // Mewajibkan input ID pengguna saat halaman dipanggil

  const ProfileScreen({super.key, required this.currentUserId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    var result = await ApiService.getUserProfile(widget.currentUserId);
    if (mounted) {
      setState(() {
        isLoading = false;
        if (result['status'] == 'success') {
          userData = result['data'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'MY PROFILE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : userData == null
              ? const Center(child: Text('Gagal memuat profil.', style: TextStyle(color: Colors.white)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bagian 1: Foto Profil & Identitas Utama
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[900],
                              // Menampilkan foto jika ada, jika tidak pakai ikon default
                              backgroundImage: userData!['profile_photo'] != null 
                                  ? MemoryImage(base64Decode(userData!['profile_photo'].split(',').last)) 
                                  : null,
                              child: userData!['profile_photo'] == null 
                                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              userData!['full_name'] ?? 'Nama Pengguna',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userData!['email'] ?? 'Email tidak tersedia',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            
                            // WIDGET BARU: Rating & Total Ulasan (Bisa Diklik)
                            GestureDetector(
                           onTap: () {
                             // Buka komentar navigasi ini
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (context) => ReviewListScreen(userId: widget.currentUserId),
                               ),
                             );
                           
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Halaman ulasan belum dibuat.')));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${userData!['average_rating']} / 5.0',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${userData!['total_reviews']} Reviews)',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Bagian 2: Keahlian yang Dimiliki (Can)
                      const Text(
                        'SKILLS I HAVE',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (userData!['skills']['can'] as List).isEmpty
                            ? [const Text('-', style: TextStyle(color: Colors.grey))]
                            : (userData!['skills']['can'] as List).map((skill) {
                                return _buildSkillChip(skill, true);
                              }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // Bagian 3: Keahlian yang Ingin Dipelajari (Want)
                      const Text(
                        'SKILL I WANT (Max 1)',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (userData!['skills']['want'] as List).isEmpty
                            ? [const Text('-', style: TextStyle(color: Colors.grey))]
                            : (userData!['skills']['want'] as List).map((skill) {
                                return _buildSkillChip(skill, false);
                              }).toList(),
                      ),
                      const SizedBox(height: 40),

                      // Tombol Edit Profil
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Tunggu sampai layar Edit ditutup, jika kembaliannya true, refresh data
                            bool? shouldRefresh = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(
                                  userId: widget.currentUserId, 
                                  currentData: userData!
                                ),
                              ),
                            );

                            if (shouldRefresh == true) {
                              setState(() { isLoading = true; });
                              _loadUserProfile(); // Tarik ulang data profil terbaru dari MySQL
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          // PASTIKAN BARIS 'child:' INI ADA
                          child: const Text('EDIT PROFILE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // Widget bantuan untuk membuat kotak tag keahlian
  Widget _buildSkillChip(String label, bool isOwned) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isOwned ? Colors.white : Colors.grey[800],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isOwned ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}