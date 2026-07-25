import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui'; // Ditambahkan untuk efek BackdropFilter (kaca)
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final int currentUserId;

  const ChatListScreen({super.key, required this.currentUserId});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // Palet warna utama: putih bersih + sedikit aksen biru & emas (selaras dengan ChatScreen)
  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color partnerGold = Color(0xFFF29C11);
  static const Color bgColor = Color(0xFFF8F9FA);

  // Ambang batas jumlah pesan agar dianggap level "Partner".
  // Nilai ini sengaja disamakan dengan _levelInfoForCount() di ChatScreen.
  static const int _partnerThreshold = 30;

  List<dynamic> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  void _fetchMatches() async {
    var result = await ApiService.getActiveMatches(widget.currentUserId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['status'] == 'success') {
          _matches = result['data'] ?? [];
        }
      });
    }
  }

  bool _isPartnerLevel(dynamic match) {
    final count = match['message_count'] ?? 0;
    return count is int ? count >= _partnerThreshold : (count as num).toInt() >= _partnerThreshold;
  }

  ImageProvider? _decodePhoto(String? base64Photo) {
    if (base64Photo == null || base64Photo.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(base64Photo.split(',').last.replaceAll(RegExp(r'\s+'), '')));
    } catch (_) {
      return null;
    }
  }

  // Format waktu pesan terakhir: jam:menit (hari ini), nama hari (minggu ini), atau tanggal lengkap
  String _formatLastMessageTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDay = DateTime(dt.year, dt.month, dt.day);
      final dayDiff = today.difference(messageDay).inDays;

      if (dayDiff == 0) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (dayDiff == 1) {
        return 'Kemarin';
      } else if (dayDiff < 7) {
        const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
        return days[dt.weekday - 1];
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final partners = _matches.where(_isPartnerLevel).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      bottomNavigationBar: AppBottomNav(
        currentUserId: widget.currentUserId,
        currentIndex: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : _matches.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: primaryBlue,
                  onRefresh: () async => _fetchMatches(),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (partners.isNotEmpty) ...[
                        _buildPartnerCarousel(partners),
                        Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                      ],
                      for (int i = 0; i < _matches.length; i++) ...[
                        _buildChatTile(_matches[i]),
                        if (i != _matches.length - 1)
                          Divider(height: 1, thickness: 1, indent: 78, color: Colors.grey[200]),
                      ],
                    ],
                  ),
                ),
    );
  }

  // AppBar dengan tombol back hitam, judul "Message" biru, dan logo di kanan
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 20,
      title: const Text(
        'Message',
        style: TextStyle(
          color: primaryBlue,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Image.asset(
            'assets/images/logo.png',
            width: 34,
            height: 34,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Belum ada obrolan aktif.',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Baris "Partner" menggunakan efek biru transparan seperti kaca
  Widget _buildPartnerCarousel(List partners) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // Efek blur kaca
        child: Container(
          decoration: BoxDecoration(
            color: primaryBlue.withValues(alpha: 0.1), // Warna biru transparan
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.only(top: 16, bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, size: 16, color: partnerGold),
                    const SizedBox(width: 6),
                    Text(
                      'Partner',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 84,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: partners.length,
                  itemBuilder: (context, index) {
                    final match = partners[index];
                    final photo = match['partner_photo'] ?? match['profile_photo'];
                    final name = (match['partner_name'] ?? '') as String;
                    final decoded = _decodePhoto(photo);

                    return GestureDetector(
                      onTap: () => _openChat(match),
                      child: Container(
                        width: 64,
                        margin: const EdgeInsets.only(right: 14),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [partnerGold, Color(0xFFFFD873)],
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundColor: Colors.grey[100],
                                backgroundImage: decoded,
                                child: decoded == null
                                    ? const Icon(Icons.person, color: Colors.grey, size: 20)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Satu baris daftar chat: foto, nama, preview pesan terakhir, waktu, dan badge unread
  Widget _buildChatTile(dynamic match) {
    final photo = match['partner_photo'] ?? match['profile_photo'];
    final decoded = _decodePhoto(photo);
    final unreadCount = (match['unread_count'] ?? 0) as int;
    final lastMessage = match['last_message'] as String?;
    final lastTime = _formatLastMessageTime(match['last_message_time'] as String?);
    final hasUnread = unreadCount > 0;

    return InkWell(
      onTap: () => _openChat(match),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey[100],
              backgroundImage: decoded,
              child: decoded == null ? const Icon(Icons.person, color: Colors.grey) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match['partner_name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (lastTime.isNotEmpty)
                        Text(
                          lastTime,
                          style: TextStyle(
                            color: hasUnread ? primaryBlue : Colors.grey[400],
                            fontSize: 11,
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (lastMessage == null || lastMessage.isEmpty)
                              ? 'Klik untuk mulai mengobrol...'
                              : lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread ? Colors.black87 : Colors.grey[500],
                            fontSize: 13,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
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

  void _openChat(dynamic match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatPartnerName: match['partner_name'],
          matchId: match['match_id'],
          currentUserId: widget.currentUserId,
          chatPartnerId: match['partner_id'],
          chatPartnerPhoto: match['partner_photo'] ?? match['profile_photo'],
          initialStatus: match['status'] ?? 'MATCHED',
        ),
      ),
    ).then((_) {
      // Segarkan daftar (hilangkan badge unread, update preview) saat kembali dari ruang obrolan
      _fetchMatches();
    });
  }
}