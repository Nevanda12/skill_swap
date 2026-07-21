import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'match_screen.dart';
import '../services/api_service.dart';
import 'chat_list_screen.dart';
import 'explore_screen.dart'; // Impor layar jelajah baru
import 'dart:convert';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  final int userId; 

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Arsitektur Navigasi Bawah
  int _selectedIndex = 0; // 0 = Layar Geser (Swipe), 1 = Layar Jelajah (Explore)

  List<dynamic> discoverUsers = [];
  bool isLoading = true;
  String emptyMessage = "";

  int _unreadCount = 0;
  Timer? _notificationTimer;
  String? _selectedFilterSkill;
  
  @override
  void initState() {
    super.initState();
    _loadDiscoveryData();
    _checkNotificationsSilently();
    _notificationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _checkNotificationsSilently();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel(); 
    super.dispose();
  }

  void _checkNotificationsSilently() async {
    var result = await ApiService.checkUnreadMessages(widget.userId);
    if (mounted && result['status'] == 'success') {
      setState(() {
        _unreadCount = result['unread_count'] ?? 0;
      });
    }
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

  void _handleSwipe(bool isRightSwipe, dynamic swipedUser) async {
    int swipedId = swipedUser['id'];
    String swipedName = swipedUser['name'] ?? swipedUser['full_name'] ?? 'Pengguna';
    String swipedSkill = (swipedUser['skills']['can'] as List).isNotEmpty 
        ? (swipedUser['skills']['can'] as List).join(', ') : '-';

    var result = await ApiService.swipeUser(swiperId: widget.userId, swipedId: swipedId, isLiked: isRightSwipe);
    if (!mounted) return;

    if (result['status'] == 'match') {
      int newMatchId = result['match_id'];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchScreen(
            matchedUserName: swipedName, matchedUserSkill: swipedSkill,
            matchId: newMatchId, currentUserId: widget.userId, matchedUserId: swipedId,      
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            if (discoverUsers.isNotEmpty) discoverUsers.removeAt(0);
          });
        }
      });
    } else {
      setState(() {
        if (discoverUsers.isNotEmpty) discoverUsers.removeAt(0);
      });
    }
  }

  // Fungsi untuk mengelola perpindahan Tab Bawah
  void _onItemTapped(int index) {
    if (index == 0 || index == 1) {
      setState(() {
        _selectedIndex = index; // Pindah antara Layar Geser dan Jelajah
      });
    } else if (index == 2) {
      // Buka Layar Obrolan (Tumpuk di atas, menu bawah menghilang sementara)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatListScreen(currentUserId: widget.userId)),
      ).then((_) => _checkNotificationsSilently());
    } else if (index == 3) {
      // Buka Layar Profil (Tumpuk di atas)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen(currentUserId: widget.userId, isEditable: true)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      
      // IndexedStack menumpuk layar agar statusnya tidak hilang saat berpindah tab
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Index 0: Layar Geser (Swipe)
          _buildSwipeScaffold(),
          // Index 1: Layar Jelajah
          ExploreScreen(
            onCategorySelected: (String skillName) {
              setState(() {
                _selectedFilterSkill = skillName;
                _selectedIndex = 0; // Otomatis pindah ke layar geser
              });
              _loadDiscoveryData(); // Muat data skill tersebut
            },
          ),
        ],
      ),
      
      // Navigasi Bawah Utama (4 Menu)
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey[600],
        showSelectedLabels: true,
        showUnselectedLabels: true,
        currentIndex: _selectedIndex, 
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.local_fire_department), label: 'Geser'),
          const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Jelajah'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline),
                if (_unreadCount > 0)
                  Positioned(
                    right: -4, top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
            label: 'Obrolan',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }

  // Komponen khusus untuk layar geser (agar kodenya rapi)
  Widget _buildSwipeScaffold() {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'SKILL SWAP',
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 2,
            fontSize: 18,
          ),
        ),
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : discoverUsers.isEmpty
              ? Center(
                  child: Text(
                    emptyMessage.isNotEmpty ? emptyMessage : 'Tidak ada lagi pengguna di sekitarmu.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
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
                            onDismissed: (direction) {
                              bool isRightSwipe = direction == DismissDirection.startToEnd;
                              _handleSwipe(isRightSwipe, user);
                            },
                            child: card,
                          );
                        }
                        return card;
                      }).toList().reversed.toList(),
                    ),
                  ),
                ),
    );
  }

  Widget _buildCard(dynamic user) {
    String? base64Photo = user['profile_photo'] ?? user['photo'];
    List canList = user['skills']['can'] as List;
    String canSkills = canList.isNotEmpty ? (canList.length > 1 ? '${canList[0]}, +${canList.length - 1} lainnya' : canList.first.toString()) : '-';
    String wantSkills = (user['skills']['want'] as List).isNotEmpty ? (user['skills']['want'] as List).join(', ') : '-';
    String displayName = user['name'] ?? user['full_name'] ?? 'Pengguna';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20), 
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: (base64Photo != null && base64Photo.isNotEmpty)
                  ? Image.memory(base64Decode(base64Photo.split(',').last), fit: BoxFit.cover)
                  : Container(color: Colors.grey[850], child: const Center(child: Icon(Icons.account_box, size: 150, color: Colors.grey))),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.9)],
                  stops: const [0.5, 0.75, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
                          child: Text('Can: $canSkills', style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                          child: Text('Want: $wantSkills', style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}