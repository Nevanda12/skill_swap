import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'dart:convert'; // <-- TAMBAHKAN BARIS INI

class ChatListScreen extends StatefulWidget {
  final int currentUserId;

  const ChatListScreen({super.key, required this.currentUserId});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Messages', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _matches.isEmpty
              ? const Center(child: Text('Belum ada obrolan aktif.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _matches.length,
                  itemBuilder: (context, index) {
                    final match = _matches[index];
                    
                    // Tarik data string base64 dari backend
                    String? base64Photo = match['partner_photo'] ?? match['profile_photo']; 

                    // Tarik jumlah pesan belum dibaca dari API backend
                    int unreadCount = match['unread_count'] ?? 0;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[800],
                        backgroundImage: (base64Photo != null && base64Photo.isNotEmpty)
                            ? MemoryImage(base64Decode(base64Photo.split(',').last.replaceAll(RegExp(r'\s+'), '')))
                            : null,
                        child: (base64Photo == null || base64Photo.isEmpty)
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(match['partner_name'], style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        unreadCount > 0 ? 'Ada pesan baru!' : 'Klik untuk mulai mengobrol...', 
                        style: TextStyle(
                          color: unreadCount > 0 ? Colors.white : Colors.grey, 
                          fontSize: 12,
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        )
                      ),
                      // Tampilkan lencana angka JIKA ADA pesan, jika TIDAK ADA tampilkan ikon panah
                      trailing: unreadCount > 0 
                          ? Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            )
                          : const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatPartnerName: match['partner_name'],
                              matchId: match['match_id'],
                              currentUserId: widget.currentUserId,
                              chatPartnerId: match['partner_id'],
                              chatPartnerPhoto: base64Photo,
                            ),
                          ),
                        ).then((_) {
                          // TAMBAHAN: Segarkan daftar pesan (hilangkan lencana merah) saat kembali dari ruang obrolan
                          _fetchMatches(); 
                        });
                      },
                    );
                  },
                ),
    );
  }
}