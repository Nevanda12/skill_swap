import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/home_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/profile_screen.dart';

/// Bottom navigation bar yang dipakai bersama oleh HomeScreen, ChatListScreen,
/// dan ProfileScreen supaya tampilannya konsisten di semua halaman utama.
///
/// - Tab Home & Explore: kalau [onLocalTabChange] diisi (dipakai HomeScreen),
///   perpindahan dilakukan LOKAL (setState, tanpa Navigator) — makanya di
///   Home tetap terasa ringan. Kalau null (dipakai dari ChatList/Profile),
///   akan menavigasi kembali ke HomeScreen dengan tab yang dipilih.
/// - Tab Chat & Profile: menavigasi (pushReplacement) ke layar yang sesuai.
/// - Ikon tab Profile menampilkan foto profil pengguna sendiri (bukan ikon orang).
class AppBottomNav extends StatefulWidget {
  final int currentUserId;
  final int currentIndex; // 0 Home, 1 Explore, 2 Chat, 3 Profile
  final ValueChanged<int>? onLocalTabChange;

  const AppBottomNav({
    super.key,
    required this.currentUserId,
    required this.currentIndex,
    this.onLocalTabChange,
  });

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  int _unreadCount = 0;
  String? _ownPhoto;

  @override
  void initState() {
    super.initState();
    _checkUnread();
    _loadOwnPhoto();
  }

  void _checkUnread() async {
    var result = await ApiService.checkUnreadMessages(widget.currentUserId);
    if (mounted && result['status'] == 'success') {
      setState(() => _unreadCount = result['unread_count'] ?? 0);
    }
  }

  void _loadOwnPhoto() async {
    var result = await ApiService.getUserProfile(widget.currentUserId);
    if (mounted && result['status'] == 'success') {
      setState(() => _ownPhoto = result['data']?['profile_photo']);
    }
  }

  void _onTap(int index) {
    if (index == widget.currentIndex) return;

    if ((index == 0 || index == 1) && widget.onLocalTabChange != null) {
      widget.onLocalTabChange!(index);
      return;
    }

    late Widget target;
    switch (index) {
      case 0:
      case 1:
        target = HomeScreen(userId: widget.currentUserId, initialIndex: index);
        break;
      case 2:
        target = ChatListScreen(currentUserId: widget.currentUserId);
        break;
      default:
        target = ProfileScreen(currentUserId: widget.currentUserId, isEditable: true);
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => target));
  }

  Widget _buildProfileIcon(bool active) {
    ImageProvider? img;
    if (_ownPhoto != null && _ownPhoto!.isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(_ownPhoto!.split(',').last.replaceAll(RegExp(r'\s+'), '')));
      } catch (_) {
        img = null;
      }
    }
    return Container(
      padding: EdgeInsets.all(active ? 1.5 : 0),
      decoration: active
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2CB69D), width: 2),
            )
          : null,
      child: CircleAvatar(
        radius: 12,
        backgroundColor: Colors.grey[800],
        backgroundImage: img,
        child: img == null ? Icon(Icons.person, size: 14, color: Colors.grey[400]) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF051329),
      selectedItemColor: const Color(0xFF2CB69D),
      unselectedItemColor: Colors.grey[500],
      showSelectedLabels: true,
      showUnselectedLabels: true,
      currentIndex: widget.currentIndex,
      type: BottomNavigationBarType.fixed,
      elevation: 10,
      onTap: _onTap,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Explore'),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.chat_bubble_outline),
              if (_unreadCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: _buildProfileIcon(false),
          activeIcon: _buildProfileIcon(true),
          label: 'Profile',
        ),
      ],
    );
  }
}