import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';
import 'profile_screen.dart';

// Halaman daftar Followers ATAU Following milik seorang user (bisa profil sendiri
// atau profil user lain — keduanya boleh dilihat siapa saja).
class FollowListScreen extends StatefulWidget {
  final int profileUserId; // pemilik daftar follower/following yang sedang ditampilkan
  final int viewerId;      // ID user yang sedang login (yang membuka halaman ini)
  final bool showFollowers; // true = tampilkan Followers, false = tampilkan Following
  final String profileName;

  const FollowListScreen({
    super.key,
    required this.profileUserId,
    required this.viewerId,
    required this.showFollowers,
    required this.profileName,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<dynamic> people = [];
  bool isLoading = true;

  // Apakah daftar yang sedang dilihat ini milik akun kita sendiri?
  bool get _isOwnList => widget.viewerId == widget.profileUserId;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  void _loadList() async {
    setState(() => isLoading = true);
    var result = widget.showFollowers
        ? await ApiService.getFollowers(widget.profileUserId, viewerId: widget.viewerId)
        : await ApiService.getFollowing(widget.profileUserId, viewerId: widget.viewerId);

    if (mounted) {
      setState(() {
        isLoading = false;
        if (result['status'] == 'success') {
          people = result['data'] ?? [];
        }
      });
    }
  }

  // Dipakai saat melihat daftar SENDIRI:
  // - Di tab Followers -> tombol "Hapus" (menghapus follower dari akun kita)
  // - Di tab Following -> tombol "Berhenti" (unfollow orang tersebut)
  void _removeFromOwnList(dynamic person) async {
    Map<String, dynamic> result;
    if (widget.showFollowers) {
      result = await ApiService.removeFollower(
        userId: widget.profileUserId,
        followerId: person['id'],
      );
    } else {
      result = await ApiService.unfollowUser(
        followerId: widget.profileUserId,
        followingId: person['id'],
      );
    }

    if (!mounted) return;
    if (result['status'] == 'success') {
      setState(() => people.removeWhere((p) => p['id'] == person['id']));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Gagal memproses permintaan.')),
      );
    }
  }

  // Dipakai saat melihat daftar milik USER LAIN: toggle follow/unfollow kita
  // sendiri terhadap orang di dalam daftar tersebut.
  void _toggleFollowPerson(dynamic person) async {
    bool isFollowingThisPerson = person['is_following'] == true;
    var result = isFollowingThisPerson
        ? await ApiService.unfollowUser(followerId: widget.viewerId, followingId: person['id'])
        : await ApiService.followUser(followerId: widget.viewerId, followingId: person['id']);

    if (!mounted) return;
    if (result['status'] == 'success') {
      setState(() => person['is_following'] = !isFollowingThisPerson);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Gagal memproses permintaan.')),
      );
    }
  }

  void _openPersonProfile(dynamic person) {
    if (person['id'] == widget.viewerId) return; // sudah profil sendiri
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          currentUserId: person['id'],
          viewerId: widget.viewerId,
          isEditable: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.showFollowers ? 'Pengikut' : 'Mengikuti',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : people.isEmpty
              ? Center(
                  child: Text(
                    widget.showFollowers ? 'Belum ada pengikut.' : 'Belum mengikuti siapa pun.',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: people.length,
                  itemBuilder: (context, index) => _buildPersonTile(people[index]),
                ),
    );
  }

  Widget _buildPersonTile(dynamic person) {
    String? photo = person['profile_photo'];
    bool isSelf = person['id'] == widget.viewerId;
    bool isFollowingThisPerson = person['is_following'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _openPersonProfile(person),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[900],
              backgroundImage: (photo != null && photo.isNotEmpty)
                  ? MemoryImage(base64Decode(photo.split(',').last))
                  : null,
              child: (photo == null || photo.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 22)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _openPersonProfile(person),
              child: Text(
                person['full_name'] ?? 'Pengguna',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Tombol aksi berbeda tergantung daftar milik siapa yang sedang dilihat.
          if (!isSelf && _isOwnList)
            TextButton(
              onPressed: () => _removeFromOwnList(person),
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[850],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                widget.showFollowers ? 'Hapus' : 'Berhenti',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          else if (!isSelf && !_isOwnList)
            OutlinedButton(
              onPressed: () => _toggleFollowPerson(person),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                isFollowingThisPerson ? 'Mengikuti' : 'Ikuti',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}