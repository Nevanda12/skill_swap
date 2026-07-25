import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'dart:convert';
import 'review_list_screen.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'skill_icon_helper.dart';
import 'follow_list_screen.dart';
import 'chat_screen.dart';
import '../widgets/app_bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  // ID pemilik profil yang sedang ditampilkan di layar ini.
  final int currentUserId;
  // ID user yang sedang login (viewer). WAJIB diisi dengan benar oleh pemanggil
  // saat menampilkan profil ORANG LAIN (mis. ProfileScreen(currentUserId: idLawan,
  // viewerId: idSayaYangLogin)), supaya tombol Ikuti/Chat Sekarang & hak edit/hapus
  // galeri terhitung benar. Kalau dikosongkan, fallback lama dipakai: dianggap
  // profil sendiri HANYA jika isEditable true (mis. dipanggil dari Bottom Nav tab
  // Profile tanpa lewat Navigator.push).
  final int? viewerId;
  final bool isEditable;

  const ProfileScreen({
    super.key,
    required this.currentUserId,
    this.viewerId,
    this.isEditable = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  List<dynamic> galleryPhotos = [];
  bool isLoadingGallery = true;

  bool isFollowing = false;
  bool isFollowLoading = false;
  bool isStartingChat = false;

  // ID user yang SEDANG LOGIN di HP ini. Diambil otomatis dari SessionService
  // (sumber kebenaran satu-satunya), bukan lagi mengandalkan parameter viewerId
  // yang harus diingat-ingat dikirim oleh setiap layar yang membuka ProfileScreen.
  // widget.viewerId tetap dihormati kalau memang dikirim eksplisit (dipakai oleh
  // FollowListScreen supaya tidak perlu query ulang ke SessionService).
  int? _sessionViewerId;

  int? get _viewerId => widget.viewerId ?? _sessionViewerId;
  bool get _isOwnProfile =>
      _viewerId != null ? _viewerId == widget.currentUserId : widget.isEditable;

  @override
  void initState() {
    super.initState();
    _initViewerThenLoadProfile();
    _loadGalleryPhotos();
  }

  void _initViewerThenLoadProfile() async {
    if (widget.viewerId == null) {
      _sessionViewerId = await SessionService.getUserId();
    }
    if (!mounted) return;
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    var result = await ApiService.getUserProfile(
      widget.currentUserId,
      viewerId: _isOwnProfile ? null : _viewerId,
    );
    if (mounted) {
      setState(() {
        isLoading = false;
        if (result['status'] == 'success') {
          userData = result['data'];
          isFollowing = userData!['is_following'] == true;
        }
      });
    }
  }

  void _loadGalleryPhotos() async {
    var result = await ApiService.getGalleryPhotos(widget.currentUserId);
    if (mounted) {
      setState(() {
        isLoadingGallery = false;
        if (result['status'] == 'success') {
          galleryPhotos = result['data'] ?? [];
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

  // ===================== FOLLOW & CHAT (profil user lain) =====================

  void _toggleFollow() async {
    if (_isOwnProfile || _viewerId == null) return;
    setState(() => isFollowLoading = true);

    var result = isFollowing
        ? await ApiService.unfollowUser(followerId: _viewerId!, followingId: widget.currentUserId)
        : await ApiService.followUser(followerId: _viewerId!, followingId: widget.currentUserId);

    if (!mounted) return;
    setState(() {
      isFollowLoading = false;
      if (result['status'] == 'success') {
        isFollowing = !isFollowing;
        if (userData != null) {
          int current = (userData!['followers_count'] ?? 0) as int;
          userData!['followers_count'] = isFollowing ? current + 1 : (current > 0 ? current - 1 : 0);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal memproses permintaan.')),
        );
      }
    });
  }

  void _startChatNow() async {
    if (_isOwnProfile || _viewerId == null) return;
    setState(() => isStartingChat = true);
    var result = await ApiService.getOrCreateDirectMatch(
      userAId: _viewerId!,
      userBId: widget.currentUserId,
    );
    if (!mounted) return;
    setState(() => isStartingChat = false);

    if (result['status'] == 'success') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            matchId: result['match_id'],
            currentUserId: _viewerId!,
            chatPartnerId: widget.currentUserId,
            chatPartnerName: userData!['full_name'] ?? 'Pengguna',
            chatPartnerPhoto: userData!['profile_photo'],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Gagal memulai chat.')),
      );
    }
  }

  void _openFollowList({required bool isFollowers}) {
    if (userData == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowListScreen(
          profileUserId: widget.currentUserId,
          // Kalau lihat profil sendiri, viewer = diri sendiri.
          // Kalau lihat profil lawan tanpa viewerId valid (kasus lama), fallback
          // aman: anggap tidak ada aksi follow/hapus yang bisa dilakukan di sana.
          viewerId: _viewerId ?? widget.currentUserId,
          showFollowers: isFollowers,
          profileName: userData!['full_name'] ?? 'Pengguna',
        ),
      ),
    ).then((_) => _loadUserProfile());
  }

  // ===================== GALERI SERTIFIKAT/PORTOFOLIO =====================

  void _addGalleryPhoto() async {
    if (!_isOwnProfile) return; // Hanya pemilik profil yang boleh menambah.
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (pickedFile == null) return;

    final bytes = await File(pickedFile.path).readAsBytes();
    final base64Str = "data:image/jpeg;base64,${base64Encode(bytes)}";

    var result = await ApiService.addGalleryPhoto(userId: widget.currentUserId, photoBase64: base64Str);
    if (!mounted) return;

    if (result['status'] == 'success') {
      _loadGalleryPhotos();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Gagal menambah foto.')),
      );
    }
  }

  void _deleteGalleryPhoto(int photoId) async {
    if (!_isOwnProfile) return; // Hanya pemilik profil yang boleh menghapus.
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Foto'),
        content: const Text('Yakin ingin menghapus foto ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    var result = await ApiService.deleteGalleryPhoto(photoId: photoId, userId: widget.currentUserId);
    if (!mounted) return;

    if (result['status'] == 'success') {
      setState(() => galleryPhotos.removeWhere((p) => p['id'] == photoId));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Gagal menghapus foto.')),
      );
    }
  }

  void _viewGalleryPhoto(dynamic photo) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.memory(base64Decode(photo['photo_base64'].toString().split(',').last)),
        ),
      ),
    );
  }

  // ===================== SETTINGS / LOGOUT (profil sendiri) =====================

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.feedback_outlined, color: Colors.white70),
                title: const Text('Beri Masukan', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _openFeedbackLink();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _handleLogout();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _openFeedbackLink() async {
    final Uri url = Uri.parse('https://nevanda12.github.io/Nevanda-Portofolio');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka link portofolio.')),
      );
    }
  }

  void _handleLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    await SessionService.clearSession();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? bgPhoto = userData != null ? userData!['background_photo'] : null;
    final double bgHeight = MediaQuery.of(context).size.height * 0.5;

    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      extendBodyBehindAppBar: true,
      bottomNavigationBar: widget.isEditable
          ? AppBottomNav(currentUserId: widget.currentUserId, currentIndex: 3)
          : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Text(
          _isOwnProfile ? 'My Profile' : 'User Profile',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: widget.isEditable
            ? IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                tooltip: 'Pengaturan',
                onPressed: _openSettings,
              )
            : null,
        actions: [
          if (_isOwnProfile)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit Profil',
              onPressed: isLoading ? null : _goToEdit,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : userData == null
              ? const Center(child: Text('Gagal memuat profil.', style: TextStyle(color: Colors.white)))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    // ===== Background HANYA setengah layar bagian atas =====
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: bgHeight,
                      child: bgPhoto != null
                          ? Image.memory(
                              base64Decode(bgPhoto.split(',').last),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFF243B6B), Color(0xFF0B1220)],
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: bgHeight,
                      child: Container(color: Colors.black.withValues(alpha: 0.30)),
                    ),

                    // ===== Konten =====
                    SafeArea(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 8),

                            // Avatar + nama + rating, ditengah, langsung di atas background (tanpa kotak)
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: Colors.grey[900],
                              backgroundImage: userData!['profile_photo'] != null
                                  ? MemoryImage(base64Decode(userData!['profile_photo'].split(',').last))
                                  : null,
                              child: userData!['profile_photo'] == null
                                  ? const Icon(Icons.person, size: 46, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              userData!['full_name'] ?? 'Nama Pengguna',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
                                  color: Colors.black38,
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
                            const SizedBox(height: 14),

                            // Mengikuti / Pengikut
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () => _openFollowList(isFollowers: false),
                                  child: _buildFollowCountText(
                                    userData!['following_count']?.toString() ?? '0',
                                    'Mengikuti',
                                  ),
                                ),
                                const SizedBox(width: 22),
                                GestureDetector(
                                  onTap: () => _openFollowList(isFollowers: true),
                                  child: _buildFollowCountText(
                                    userData!['followers_count']?.toString() ?? '0',
                                    'Pengikut',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Tombol aksi: beda tergantung profil sendiri atau lawan
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: _isOwnProfile
                                  ? _buildEditProfileButton()
                                  : _buildFollowAndChatButtons(),
                            ),
                            const SizedBox(height: 26),

                            // ===== Konten bawah, langsung di atas background gelap polos (tanpa kotak) =====
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                              decoration: const BoxDecoration(color: Color(0xFF05070A)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Statistik ringkas — dibatasi garis biru tipis atas & bawah
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.35)),
                                        bottom: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.35)),
                                      ),
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
                                        _buildStatColumn(
                                          Icons.swap_horiz,
                                          Colors.indigoAccent,
                                          (userData!['skills']['can'] as List).length.toString(),
                                          'Skill',
                                        ),
                                        _buildStatColumn(
                                          Icons.workspace_premium,
                                          Colors.tealAccent,
                                          userData!['total_reviews']?.toString() ?? '0',
                                          'Reviews',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  // Skills I Have
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
                                            return _buildSkillChip(skill, true);
                                          }).toList(),
                                  ),
                                  const SizedBox(height: 24),

                                  // Skill I Want
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
                                            return _buildSkillChip(skill, false);
                                          }).toList(),
                                  ),
                                  const SizedBox(height: 28),
                                  Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                                  const SizedBox(height: 24),

                                  // Sertifikat & Portofolio
                                  _buildGallerySection(),
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

  Widget _buildFollowCountText(String count, String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$count ',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // Tombol untuk profil SENDIRI
  Widget _buildEditProfileButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _goToEdit,
        icon: const Icon(Icons.edit, size: 16, color: Colors.white),
        label: const Text('Edit Profil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // Tombol Ikuti + Chat Sekarang untuk profil ORANG LAIN
  Widget _buildFollowAndChatButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isFollowLoading ? null : _toggleFollow,
            icon: isFollowLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    isFollowing ? Icons.check : Icons.person_add_alt_1,
                    size: 16,
                    color: Colors.white,
                  ),
            label: Text(
              isFollowing ? 'Mengikuti' : 'Ikuti',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isStartingChat ? null : _startChatNow,
            icon: isStartingChat
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.chat_bubble, size: 15, color: Colors.black),
            label: const Text(
              'Chat Sekarang',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
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

  Widget _buildSkillChip(String label, bool isOwned) {
    final iconData = skillIconData(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12182A),
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

  // Galeri foto sertifikat/profesional — hanya foto, tanpa komentar/like.
  // Tombol tambah & hapus HANYA muncul untuk pemilik profil (_isOwnProfile).
  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: Colors.amberAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'Sertifikat & Portofolio',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (_isOwnProfile)
              GestureDetector(
                onTap: _addGalleryPhoto,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.blueAccent, size: 18),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (isLoadingGallery)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ))
        else if (galleryPhotos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _isOwnProfile
                  ? 'Belum ada foto sertifikat. Ketuk + untuk menambahkan.'
                  : 'Belum ada foto sertifikat.',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: galleryPhotos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final photo = galleryPhotos[index];
              return GestureDetector(
                onTap: () => _viewGalleryPhoto(photo),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        base64Decode(photo['photo_base64'].toString().split(',').last),
                        fit: BoxFit.cover,
                      ),
                      // Tombol hapus HANYA untuk pemilik profil.
                      if (_isOwnProfile)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _deleteGalleryPhoto(photo['id']),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}