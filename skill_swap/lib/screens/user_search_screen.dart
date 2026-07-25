import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'profile_screen.dart';

// Halaman pencarian nama user (Explore -> ketuk search bar).
// Berbeda dari Home: hasil tampil sebagai DAFTAR (list), bukan kartu geser,
// dan TETAP menampilkan user yang sudah pernah di-swipe di Home.
class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  int? _sessionUserId;
  List<dynamic> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  void _initSession() async {
    _sessionUserId = await SessionService.getUserId();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(value);
    });
  }

  void _runSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }
    _sessionUserId ??= await SessionService.getUserId();

    setState(() => _isSearching = true);

    var result = await ApiService.searchUsersByName(
      userId: _sessionUserId ?? 0,
      query: query,
    );

    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _hasSearched = true;
      _results = result['status'] == 'success' ? (result['data'] ?? []) : [];
    });
  }

  void _openProfile(int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          currentUserId: userId,
          viewerId: _sessionUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF05070A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1629),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E3A6D).withValues(alpha: 0.4)),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onQueryChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Cari nama pengguna...',
              hintStyle: TextStyle(color: Color(0xFF8B9CB6), fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Color(0xFF8B9CB6), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2CB69D)));
    }

    if (!_hasSearched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Ketik nama untuk mencari pengguna lain.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8B9CB6), fontSize: 14),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Pengguna tidak ditemukan.',
          style: TextStyle(color: Color(0xFF8B9CB6), fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.white.withValues(alpha: 0.06),
        indent: 76,
      ),
      itemBuilder: (context, index) {
        final user = _results[index];
        final String name = user['name'] ?? 'Pengguna';
        final String? photo = user['profile_photo'];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF111E36),
            backgroundImage: (photo != null && photo.isNotEmpty)
                ? MemoryImage(base64Decode(photo.split(',').last))
                : null,
            child: (photo == null || photo.isEmpty)
                ? const Icon(Icons.person, color: Color(0xFF8B9CB6))
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF8B9CB6)),
          onTap: () => _openProfile(user['id']),
        );
      },
    );
  }
}