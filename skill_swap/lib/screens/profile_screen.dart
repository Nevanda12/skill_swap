import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'review_list_screen.dart';
import 'edit_profile_screen.dart';
import 'skill_icon_helper.dart';
import '../widgets/app_bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  final int currentUserId;
  final bool isEditable;

  const ProfileScreen({super.key, required this.currentUserId, this.isEditable = false});

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

  void _goToEdit() async {
    bool? shouldRefresh = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          userId: widget.currentUserId,
          currentData: userData!,
        ),
      ),
    );

    if (shouldRefresh == true) {
      setState(() { isLoading = true; });
      _loadUserProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Jika user sudah punya background_photo (base64) dari hasil upload di Edit Profile,
    // tampilkan sebagai latar belakang layar. Kalau belum ada, fallback ke hitam polos.
    final String? bgPhoto = userData != null ? userData!['background_photo'] : null;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: bgPhoto != null,
      bottomNavigationBar: widget.isEditable
          ? AppBottomNav(currentUserId: widget.currentUserId, currentIndex: 3)
          : null,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220).withValues(alpha: 0.85),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.blueAccent.withValues(alpha: 0.15)),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.isEditable ? 'My Profile' : 'User Profile',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          if (widget.isEditable)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: _goToEdit,
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background dari galeri (jika ada)
          if (bgPhoto != null)
            Positioned.fill(
              child: Image.memory(
                base64Decode(bgPhoto.split(',').last),
                fit: BoxFit.cover,
              ),
            ),
          if (bgPhoto != null)
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),

          // Konten utama
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : userData == null
                  ? const Center(child: Text('Gagal memuat profil.', style: TextStyle(color: Colors.white)))
                  : SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ===== KOTAK 1: Foto, Identitas, Rating & Statistik =====
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: bgPhoto != null ? Colors.white.withValues(alpha: 0.18) : const Color(0xFF0B1220),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 38,
                                        backgroundColor: Colors.grey[900],
                                        backgroundImage: userData!['profile_photo'] != null
                                            ? MemoryImage(base64Decode(userData!['profile_photo'].split(',').last))
                                            : null,
                                        child: userData!['profile_photo'] == null
                                            ? const Icon(Icons.person, size: 38, color: Colors.white)
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              userData!['full_name'] ?? 'Nama Pengguna',
                                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 10),

                                            // Rating & Total Ulasan
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ReviewListScreen(userId: widget.currentUserId),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[900],
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${userData!['average_rating']} / 5.0',
                                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '(${userData!['total_reviews']} Reviews)',
                                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                                    ),
                                                    const SizedBox(width: 2),
                                                    const Icon(Icons.chevron_right, color: Colors.grey, size: 14),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  // BOX STATS: Connections, Swaps, Reviews
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: bgPhoto != null
                                          ? const Color(0xFF0F172A).withValues(alpha: 0.45)
                                          : const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildStatColumn(
                                          Icons.people,
                                          Colors.blueAccent,
                                          userData!['total_matches']?.toString() ?? '0',
                                          'Match',
                                        ),
                                        Container(height: 36, width: 1, color: Colors.grey[800]),
                                        _buildStatColumn(
                                          Icons.swap_horiz,
                                          Colors.indigoAccent,
                                          (userData!['skills']['can'] as List).length.toString(),
                                          'Skill',
                                        ),
                                        Container(height: 36, width: 1, color: Colors.grey[800]),
                                        _buildStatColumn(
                                          Icons.workspace_premium,
                                          Colors.tealAccent,
                                          userData!['total_reviews']?.toString() ?? '0',
                                          'Reviews',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ===== KOTAK 2: Skills I Have & Skill I Want =====
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: bgPhoto != null ? Colors.white.withValues(alpha: 0.18) : const Color(0xFF0B1220),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Keahlian yang Dimiliki (Can)
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Skills I Have',
                                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (userData!['skills']['can'] as List).isEmpty
                                        ? [const Text('-', style: TextStyle(color: Colors.grey))]
                                        : (userData!['skills']['can'] as List).map((skill) {
                                            return _buildSkillChip(skill, true, bgPhoto != null);
                                          }).toList(),
                                  ),
                                  const SizedBox(height: 24),

                                  // Keahlian yang Ingin Dipelajari (Want)
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: Colors.tealAccent, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Skill I Want (Max 1)',
                                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (userData!['skills']['want'] as List).isEmpty
                                        ? [const Text('-', style: TextStyle(color: Colors.grey))]
                                        : (userData!['skills']['want'] as List).map((skill) {
                                            return _buildSkillChip(skill, false, bgPhoto != null);
                                          }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, Color iconColor, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSkillChip(String label, bool isOwned, bool hasBg) {
    final iconData = skillIconData(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hasBg ? const Color(0xFF1E293B).withValues(alpha: 0.45) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOwned
              ? Colors.blueAccent.withValues(alpha: 0.4)
              : Colors.tealAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData.icon, color: iconData.color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}