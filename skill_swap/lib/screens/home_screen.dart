import 'package:flutter/material.dart';
import 'match_screen.dart';
import '../services/api_service.dart';
import 'explore_screen.dart';
import '../widgets/app_bottom_nav.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  final int userId;
  // Tab yang aktif saat HomeScreen pertama dibuka (0 = Home, 1 = Explore).
  // Dipakai saat kembali dari ChatList/Profile lewat bottom nav.
  final int initialIndex;

  const HomeScreen({super.key, required this.userId, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<dynamic> discoverUsers = [];
  bool isLoading = true;
  String emptyMessage = "";
  String? _selectedFilterSkill;

  // ValueNotifier dipakai (bukan setState biasa) supaya animasi skala tombol
  // Skip/Connect saat menggeser TIDAK men-trigger rebuild seluruh HomeScreen
  // (termasuk tumpukan kartu & bottom nav) di setiap frame drag. Ini yang
  // sebelumnya bikin gestur geser terasa berat/patah-patah.
  final ValueNotifier<double> _swipeProgressNotifier = ValueNotifier(0.0);
  final ValueNotifier<DismissDirection?> _swipeDirectionNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadDiscoveryData();
  }

  @override
  void dispose() {
    _swipeProgressNotifier.dispose();
    _swipeDirectionNotifier.dispose();
    super.dispose();
  }

  void _loadDiscoveryData() async {
    setState(() => isLoading = true);
    var result = await ApiService.discoverUsers(
      widget.userId,
      filterSkill: _selectedFilterSkill,
    );
    if (mounted) {
      setState(() {
        isLoading = false;
        if (result['status'] == 'success') {
          discoverUsers = result['data'] ?? [];
        } else {
          discoverUsers = [];
          emptyMessage = result['message'] ?? "Belum ada kecocokan skill saat ini.";
        }
      });
    }
  }

  // Dipanggil saat kartu digeser (gesture) MAUPUN saat tombol Skip/Connect ditekan.
  // Menghapus kartu dari list secara SYNCHRONOUS dulu, sebelum ada proses async apa pun.
  // Ini penting: kalau penghapusan menunggu hasil API dulu, Dismissible yang sudah
  // di-dismiss masih akan dirender ulang saat setState lain terpanggil duluan,
  // dan itu memicu error "A dismissed Dismissible widget is still part of the tree".
  void _handleDismiss(bool isRightSwipe, dynamic swipedUser) {
    setState(() {
      if (discoverUsers.isNotEmpty) discoverUsers.removeAt(0);
    });
    _sendSwipeResult(isRightSwipe, swipedUser);
  }

  // Bagian async: kirim hasil swipe ke API & tangani jika terjadi match.
  // Tidak lagi menyentuh discoverUsers karena kartunya sudah dihapus duluan di atas.
  void _sendSwipeResult(bool isRightSwipe, dynamic swipedUser) async {
    int swipedId = swipedUser['id'];
    String swipedName = swipedUser['name'] ?? swipedUser['full_name'] ?? 'Pengguna';
    String swipedSkill = (swipedUser['skills']['can'] as List).isNotEmpty
        ? (swipedUser['skills']['can'] as List).join(', ')
        : '-';

    var result = await ApiService.swipeUser(
        swiperId: widget.userId, swipedId: swipedId, isLiked: isRightSwipe);
    if (!mounted) return;

    if (result['status'] == 'match') {
      int newMatchId = result['match_id'];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchScreen(
            matchedUserName: swipedName,
            matchedUserSkill: swipedSkill,
            matchId: newMatchId,
            currentUserId: widget.userId,
            matchedUserId: swipedId,
          ),
        ),
      );
    }
  }

  void _triggerManualSwipe(bool isRightSwipe) {
    if (discoverUsers.isEmpty) return;
    var user = discoverUsers[0];
    _handleDismiss(isRightSwipe, user);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Menambahkan background gradasi biru untuk keseluruhan Scaffold
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F4C81), // Biru cerah di atas
            Color(0xFF051329), // Biru sangat gelap di bawah
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Diubah menjadi transparan agar gradasi terlihat
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildSwipeScaffold(),
            ExploreScreen(
              onCategorySelected: (String skillName) {
                setState(() {
                  _selectedFilterSkill = skillName;
                  _selectedIndex = 0;
                });
                _loadDiscoveryData();
              },
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          currentUserId: widget.userId,
          currentIndex: _selectedIndex,
          onLocalTabChange: (i) => setState(() => _selectedIndex = i),
        ),
      ),
    );
  }

  Widget _buildSwipeScaffold() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            children: [
              TextSpan(text: 'Skill ', style: TextStyle(color: Colors.white)), // Diubah ke putih agar terlihat di background gelap
              TextSpan(text: 'Swap', style: TextStyle(color: Color(0xFF2CB69D))),
            ],
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2CB69D)))
          : discoverUsers.isEmpty
              ? Center(
                  child: Text(
                    emptyMessage.isNotEmpty ? emptyMessage : 'Tidak ada lagi pengguna.',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      // Kartu dibuat full-bleed (tanpa padding di sekeliling) supaya foto
                      // memenuhi layar seperti di Tinder, bukan kotak dengan bingkai/margin.
                      Expanded(
                        child: Stack(
                          children: discoverUsers.asMap().entries.map((entry) {
                            int index = entry.key;
                            var user = entry.value;
                            bool isFrontCard = index == 0;
                            Widget card = _buildCard(user);
                            if (isFrontCard) {
                              return Dismissible(
                                key: Key(user['id'].toString()),
                                direction: DismissDirection.horizontal,
                                onUpdate: (details) {
                                  // Update lewat ValueNotifier, BUKAN setState —
                                  // supaya cuma tombol Skip/Connect yang rebuild,
                                  // bukan seluruh tumpukan kartu.
                                  _swipeProgressNotifier.value = details.progress;
                                  _swipeDirectionNotifier.value = details.direction;
                                },
                                onDismissed: (direction) {
                                  _swipeProgressNotifier.value = 0.0;
                                  _swipeDirectionNotifier.value = null;
                                  bool isRightSwipe =
                                      direction == DismissDirection.startToEnd;
                                  _handleDismiss(isRightSwipe, user);
                                },
                                child: card,
                              );
                            }
                            return card;
                          }).toList().reversed.toList(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                ValueListenableBuilder<double>(
                                  valueListenable: _swipeProgressNotifier,
                                  builder: (context, progress, _) {
                                    return ValueListenableBuilder<DismissDirection?>(
                                      valueListenable: _swipeDirectionNotifier,
                                      builder: (context, direction, _) {
                                        double skipScale = (direction == DismissDirection.endToStart)
                                            ? 1.0 + (progress * 0.4)
                                            : 1.0;
                                        return Transform.scale(
                                          scale: skipScale,
                                          child: GestureDetector(
                                            onTap: () => _triggerManualSwipe(false),
                                            child: Container(
                                              width: 70,
                                              height: 70,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0A1931), // Warna gelap senada
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.redAccent.withValues(alpha: 0.3), // Border tipis untuk detail
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.redAccent.withValues(alpha: 0.3), // Efek glow pinggir
                                                    spreadRadius: 2,
                                                    blurRadius: 20,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(Icons.close,
                                                  color: Colors.redAccent, size: 35),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                const Text('Skip',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                              ],
                            ),
                            const SizedBox(width: 50),
                            Column(
                              children: [
                                ValueListenableBuilder<double>(
                                  valueListenable: _swipeProgressNotifier,
                                  builder: (context, progress, _) {
                                    return ValueListenableBuilder<DismissDirection?>(
                                      valueListenable: _swipeDirectionNotifier,
                                      builder: (context, direction, _) {
                                        double connectScale = (direction == DismissDirection.startToEnd)
                                            ? 1.0 + (progress * 0.4)
                                            : 1.0;
                                        return Transform.scale(
                                          scale: connectScale,
                                          child: GestureDetector(
                                            onTap: () => _triggerManualSwipe(true),
                                            child: Container(
                                              width: 70,
                                              height: 70,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0A1931), // Warna gelap senada
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: const Color(0xFF2CB69D).withValues(alpha: 0.3), // Border tipis untuk detail
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF2CB69D).withValues(alpha: 0.3), // Efek glow pinggir
                                                    spreadRadius: 2,
                                                    blurRadius: 20,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(Icons.handshake,
                                                  color: Color(0xFF2CB69D), size: 35),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                const Text('Connect',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCard(dynamic user) {
    String? base64Photo = user['profile_photo'] ?? user['photo'];
    List canList = user['skills']['can'] as List;
    String canSkills = canList.isNotEmpty
        ? (canList.length > 1
            ? '${canList[0]}  +${canList.length - 1} lainnya'
            : canList.first.toString())
        : '-';
    String wantSkills = (user['skills']['want'] as List).isNotEmpty
        ? (user['skills']['want'] as List).join(', ')
        : '-';
    String displayName = user['name'] ?? user['full_name'] ?? 'Pengguna';
    String rating = user['average_rating']?.toString() ?? '0.0';

    // Kartu dibuat FULL-BLEED seperti Tinder: tanpa border, tanpa box shadow,
    // tanpa sudut membulat — foto benar-benar memenuhi layar edge-to-edge.
    // Border & shadow sebelumnya juga menambah beban render di setiap frame
    // drag, jadi menghapusnya turut membantu gestur terasa lebih ringan.
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF15171A),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: (base64Photo != null && base64Photo.isNotEmpty)
                ? Image.memory(base64Decode(base64Photo.split(',').last),
                    fit: BoxFit.cover)
                : Container(
                    color: const Color(0xFF1E2024),
                    child: const Center(
                        child: Icon(Icons.person,
                            size: 100, color: Colors.grey))),
          ),
          Container(
            decoration: BoxDecoration(
              // Mengubah gradasi di atas foto menjadi warna biru pekat (seperti filter menutupi gambar)
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.withValues(alpha: 0.1),
                  const Color(0xFF0F4C81).withValues(alpha: 0.4),
                  const Color(0xFF051329).withValues(alpha: 0.95)
                ],
                stops: const [0.2, 0.6, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1931).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.greenAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('Online',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Icon(Icons.verified, color: Colors.blue, size: 24),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: const Color(0xFF0A1931).withValues(alpha: 0.6),
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome,
                                color: Color(0xFF2CB69D), size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text('Can: $canSkills',
                                  style: const TextStyle(
                                      color: Colors.white, // Ubah ke putih
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.track_changes,
                                color: Color(0xFF2CB69D), size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text('Want: $wantSkills',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(rating,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}