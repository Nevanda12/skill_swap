import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

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
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[800],
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(match['partner_name'], style: const TextStyle(color: Colors.white)),
                      subtitle: const Text('Klik untuk mulai mengobrol...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatPartnerName: match['partner_name'],
                              matchId: match['match_id'],
                              currentUserId: widget.currentUserId,
                              chatPartnerId: match['partner_id'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}