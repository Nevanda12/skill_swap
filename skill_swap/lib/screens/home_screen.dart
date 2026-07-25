import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
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

  // Margin di sekeliling kartu supaya sudut membulat besarnya (lihat _buildCard) terlihat.
  static const double _cardMarginTop = 0;
  static const double _cardMarginSide = 4;

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
      // Body diperpanjang sampai ke belakang AppBar (transparan) supaya kartu
      // benar-benar memenuhi layar dari ujung ke ujung, dengan judul & tombol
      // yang "mengambang" di atasnya.
      extendBodyBehindAppBar: true,
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: const AssetImage('assets/images/logi.jpeg'),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2CB69D)))
          : discoverUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Lottie.asset(
                        'assets/images/planet.json',
                        width: 200,
                        height: 200,
                      ),
                      Text(
                        emptyMessage.isNotEmpty ? emptyMessage : 'Tidak ada lagi pengguna.',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                      // Kartu diberi sedikit margin di semua sisi supaya sudut membulat
                      // besarnya (lihat _buildCard) terlihat jelas, bukan lagi edge-to-edge.
                      Positioned(
                        top: _cardMarginTop,
                        left: _cardMarginSide,
                        right: _cardMarginSide,
                        bottom: _cardMarginSide,
                        child: Stack(
                          children: discoverUsers.asMap().entries.map((entry) {
                            int index = entry.key;
                            var user = entry.value;
                            bool isFrontCard = index == 0;
                            Widget card = _buildCard(user);
                            if (isFrontCard) {
                              // Kartu depan bisa digeser BEBAS ke segala arah (naik, turun,
                              // miring) — hasil akhirnya tetap cuma dibuang kiri (Skip)
                              // atau kanan (Connect), ditentukan dari geseran horizontal.
                              return _DraggableCard(
                                key: Key(user['id'].toString()),
                                onDragUpdate: (progress) {
                                  _swipeProgressNotifier.value = progress.abs();
                                  _swipeDirectionNotifier.value = progress > 0.02
                                      ? DismissDirection.startToEnd
                                      : (progress < -0.02 ? DismissDirection.endToStart : null);
                                },
                                onSwipeLeft: () {
                                  _swipeProgressNotifier.value = 0.0;
                                  _swipeDirectionNotifier.value = null;
                                  _handleDismiss(false, user);
                                },
                                onSwipeRight: () {
                                  _swipeProgressNotifier.value = 0.0;
                                  _swipeDirectionNotifier.value = null;
                                  _handleDismiss(true, user);
                                },
                                child: card,
                              );
                            }
                            return card;
                          }).toList().reversed.toList(),
                        ),
                      ),
                      // Tombol Skip & Connect "mengambang" di atas kartu, mepet ke bagian
                      // paling bawah supaya tidak menghabiskan ruang tampilan kartu.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                                          width: 64,
                                          height: 64,
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
                                              color: Colors.redAccent, size: 32),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(width: 50),
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
                                          width: 64,
                                          height: 64,
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
                                              color: Color(0xFF2CB69D), size: 32),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
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

    // Kartu diberi sudut membulat besar (bentuk "kotak tumpul") dan margin tipis
    // di sekeliling (diatur dari _buildSwipeScaffold), bukan lagi kotak tajam
    // edge-to-edge. Tanpa border/box shadow supaya tetap ringan saat digeser.
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
      width: double.infinity,
      height: double.infinity,
      // Warna dasar kartu memakai gradasi hitam, supaya "lahan kosong" di
      // atas & bawah foto menyatu rapi.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F4C81),
            Color(0xFF051329),
          ],
        ),
      ),
      child: Builder(
        builder: (context) {
          // Foto dibuat SETINGGI & SEBESAR mungkin, menempel dari paling atas
          // kartu (belakang judul) sampai hampir ke bawah kartu — bukan
          // kotak kecil lagi. Warna biru cuma tersisa sedikit sekali di
          // paling bawah, sebagai tempat tombol Skip/Connect mengambang.
          const double topLand = 0; // ⬅️ ganti angka ini untuk menambah ruang biru di atas foto
          const double bottomLand = 80; // sisa lahan biru tipis di paling bawah
          final double photoBottom = bottomLand;
          const double bottomFadeHeight = 110; // zona gradasi gelap tempat nama/Can/Want berada
          const double topFadeExtra = 120; // ⬅️ ganti angka ini untuk atur tinggi gradasi ATAS

          return Stack(
            children: [
              // Foto, full-bleed dari paling atas kartu sampai hampir ke bawah.
              Positioned(
                top: topLand,
                left: 0,
                right: 0,
                bottom: photoBottom,
                child: (base64Photo != null && base64Photo.isNotEmpty)
                    ? Image.memory(
                        base64Decode(base64Photo.split(',').last),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Container(
                        color: const Color(0xFF1E2024),
                        child: const Center(
                            child: Icon(Icons.person,
                                size: 100, color: Colors.grey))),
              ),
              // Gradasi gelap tipis di paling atas foto, supaya judul "Skill
              // Swap" & badge Online tetap terbaca di atas foto.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).padding.top + kToolbarHeight + topFadeExtra,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF051329).withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Gradasi gelap di bagian BAWAH foto, tempat nama/Can/Want/rating
              // menjadi overlay supaya tetap terbaca, sekaligus menyatu ke lahan
              // biru tipis di bawahnya.
              Positioned(
                bottom: photoBottom,
                left: 0,
                right: 0,
                height: bottomFadeHeight,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF051329).withValues(alpha: 0.85),
                          const Color(0xFF051329).withValues(alpha: 0.97),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // Blok nama, skill can/want, dan rating — overlay di bagian
              // bawah foto (dibantu gradasi gelap), pas di atas lahan biru
              // tipis paling bawah tempat tombol mengambang.
              Positioned(
                left: 24,
                right: 24,
                bottom: bottomLand + 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFE9A8), Color(0xFFD4AF37)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.55),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(rating,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                                          color: Colors.white,
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
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}

// Kartu depan bisa digeser BEBAS ke segala arah (kiri, kanan, atas, bawah,
// bahkan diagonal) mengikuti jari — tidak dikunci ke satu sumbu seperti
// Dismissible bawaan Flutter. Begitu jari dilepas:
//  - kalau geseran horizontal cukup jauh -> kartu "terbang" keluar layar
//    ke kiri (Skip) atau kanan (Connect), lalu callback dipanggil.
//  - kalau belum cukup jauh -> kartu kembali ke posisi tengah (snap back).
// Gerakan vertikal / diagonal murni untuk kesan bebas & natural saja, tidak
// pernah menentukan hasil akhirnya sendiri.
class _DraggableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final ValueChanged<double>? onDragUpdate; // progress -1.0 (kiri penuh) .. 1.0 (kanan penuh)

  const _DraggableCard({
    super.key,
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.onDragUpdate,
  });

  @override
  State<_DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<_DraggableCard> with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  late final AnimationController _controller;
  Animation<Offset>? _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _controller.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
    double screenWidth = MediaQuery.of(context).size.width;
    double progress = (_dragOffset.dx / (screenWidth * 0.45)).clamp(-1.0, 1.0);
    widget.onDragUpdate?.call(progress);
  }

  void _onPanEnd(DragEndDetails details) {
    double screenWidth = MediaQuery.of(context).size.width;
    double threshold = screenWidth * 0.28;

    if (_dragOffset.dx.abs() > threshold) {
      _flyAway(isRight: _dragOffset.dx > 0);
    } else {
      _snapBack();
    }
  }

  void _animateTo(Offset end, {VoidCallback? onComplete}) {
    final Offset start = _dragOffset;
    _animation = Tween<Offset>(begin: start, end: end)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic))
      ..addListener(() {
        setState(() => _dragOffset = _animation!.value);
      });
    _controller
      ..reset()
      ..forward().whenComplete(() {
        if (onComplete != null) onComplete();
      });
  }

  void _flyAway({required bool isRight}) {
    double screenWidth = MediaQuery.of(context).size.width;
    Offset end = Offset(isRight ? screenWidth * 1.4 : -screenWidth * 1.4, _dragOffset.dy);
    _animateTo(end, onComplete: () {
      if (isRight) {
        widget.onSwipeRight();
      } else {
        widget.onSwipeLeft();
      }
    });
  }

  void _snapBack() {
    widget.onDragUpdate?.call(0.0);
    _animateTo(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double angle = (_dragOffset.dx / screenWidth) * 0.5; // sedikit miring saat digeser, seperti Tinder

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: angle,
          child: widget.child,
        ),
      ),
    );
  }
}