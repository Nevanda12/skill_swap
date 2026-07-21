import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String chatPartnerName;
  final int matchId;
  final int currentUserId;
  final int chatPartnerId;
  final String initialStatus;
  final String? chatPartnerPhoto; // Tambahkan penampung status awal

  const ChatScreen({
    super.key, 
    required this.chatPartnerName,
    required this.matchId,
    required this.currentUserId,
    required this.chatPartnerId,
    this.initialStatus = 'MATCHED',
    this.chatPartnerPhoto, // Default ke MATCHED jika tidak dioper
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool isLoading = true;
  Timer? _chatTimer;
  
 
  bool _hasReviewed = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyReviewed();
    _loadChatHistory();
    
    _chatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _refreshChatHistorySilently();
    });
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }
void _loadChatHistory() async {
    var result = await ApiService.getChatHistory(widget.matchId);
    if (mounted) {
      setState(() {
        isLoading = false;
        if (result['status'] == 'success') {
          List<dynamic> data = result['data'];
          _messages = data.map((msg) {
            return {
              'text': msg['message'],
              'isMe': msg['sender_id'] == widget.currentUserId,
            };
          }).toList();
        }
      });
      
      // TAMBAHAN: Tandai pesan langsung sebagai "Telah Dibaca" ke database
      await ApiService.markMessagesAsRead(
        matchId: widget.matchId,
        userId: widget.currentUserId,
      );
    }
  }

  void _checkIfAlreadyReviewed() async {
    var result = await ApiService.checkReviewStatus(
      matchId: widget.matchId,
      reviewerId: widget.currentUserId,
    );
    
    if (mounted && result['status'] == 'success') {
      setState(() {
        _hasReviewed = result['has_reviewed']; // Timpa status lokal dengan data asli dari database
      });
    }
  }
void _refreshChatHistorySilently() async {
    var result = await ApiService.getChatHistory(widget.matchId);
    if (mounted && result['status'] == 'success') {
      List<dynamic> data = result['data'];
      List<Map<String, dynamic>> updatedMessages = data.map((msg) {
        return {
          'text': msg['message'],
          'isMe': msg['sender_id'] == widget.currentUserId,
        };
      }).toList();

      if (updatedMessages.length != _messages.length) {
        setState(() {
          _messages = updatedMessages;
        });
        
        // TAMBAHAN: Saat ada chat baru masuk dan posisi room lagi aktif dibuka, langsung tandai dibaca
        ApiService.markMessagesAsRead(
          matchId: widget.matchId,
          userId: widget.currentUserId,
        );
      }
    }
  }
  void _sendMessage() async {
    String text = _messageController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _messages.add({'text': text, 'isMe': true});
        _messageController.clear();
      });

      await ApiService.sendChatMessage(
        matchId: widget.matchId,
        senderId: widget.currentUserId,
        message: text,
      );
    }
  }

  // ==========================================
  // FITUR HAPUS & BLOKIR
  // ==========================================
  void _showConfirmDialog(String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Tutup dialog konfirmasi
              onConfirm(); // Jalankan aksi hapus/blokir
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Yakin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _deleteChat() async {
    setState(() => isLoading = true);
    var result = await ApiService.deleteMatch(widget.matchId);
    
    // PENJAGA: Jika halaman keburu ditutup sebelum proses selesai, hentikan eksekusi kode di bawahnya
    if (!mounted) return; 

    if (result['status'] == 'success') {
      Navigator.pop(context); // Keluar dari ruang obrolan
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
    }
  }

  void _blockUser() async {
    setState(() => isLoading = true);
    var result = await ApiService.blockUser(blockerId: widget.currentUserId, blockedId: widget.chatPartnerId);
    
    // PENJAGA: Jika halaman keburu ditutup sebelum proses selesai, hentikan eksekusi kode di bawahnya
    if (!mounted) return;

    if (result['status'] == 'success') {
      Navigator.pop(context); // Keluar dari ruang obrolan
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                // Menggunakan ID target (lawan bicara) untuk membuka profilnya
                builder: (context) => ProfileScreen(currentUserId: widget.chatPartnerId, isEditable: false),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min, // Membatasi area klik hanya sebatas isi konten
            children: [
              CircleAvatar(
              backgroundColor: Colors.grey[700],
              radius: 16,
              // RENDER FOTO JIKA ADA
              backgroundImage: (widget.chatPartnerPhoto != null && widget.chatPartnerPhoto!.isNotEmpty)
                  ? MemoryImage(base64Decode(widget.chatPartnerPhoto!.split(',').last))
                  : null,
              child: (widget.chatPartnerPhoto == null || widget.chatPartnerPhoto!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
              ),
              const SizedBox(width: 12),
              Text(
                widget.chatPartnerName,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.info_outline, color: Colors.grey, size: 16), // Indikator tambahan
            ],
          ),
        ),
        // =======================================================
        // INI DIA TAMBAHANNYA, DI BAWAH TITLE TAPI MASIH DI DALAM APPBAR
        // =======================================================
        actions: [
          PopupMenuButton<String>(
            color: Colors.grey[850],
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'delete') {
                _showConfirmDialog(
                  'Hapus Obrolan', 
                  'Yakin ingin menghapus obrolan ini secara permanen?', 
                  _deleteChat
                );
              } else if (value == 'block') {
                _showConfirmDialog(
                  'Blokir Pengguna', 
                  'Yakin ingin memblokir ${widget.chatPartnerName}? Mereka akan hilang dari daftarmu.', 
                  _blockUser
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Hapus Obrolan', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Text('Blokir Pengguna', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ==== WIDGET WORKFLOW STATE BARU ====
          _buildWorkflowBanner(),
          
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildChatBubble(message['text'], message['isMe']);
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
  // Komponen Tampilan Gamifikasi Leveling Otomatis
  Widget _buildWorkflowBanner() {
    // 1. Hitung total pesan yang ada di dalam ruang obrolan ini
    int chatCount = _messages.length;
    
    String currentLevel = 'CONNECT';
    Color bannerColor = Colors.blueGrey[900]!;
    double progress = 0.0;
    int nextTarget = 10;

    // 2. Logika Penentuan Level Berdasarkan Jumlah Chat
    if (chatCount >= 30) {
      // Level Tertinggi: PARTNER (Lebih dari 30 pesan)
      currentLevel = 'PARTNER';
      bannerColor = Colors.amber[800]!; // Warna emas/kuning
      progress = 1.0; 
      nextTarget = chatCount; 
    } else if (chatCount >= 10) {
      // Level Menengah: COLLABORATOR (10 sampai 29 pesan)
      currentLevel = 'COLLABORATOR';
      bannerColor = Colors.green[700]!; 
      progress = (chatCount - 10) / 20; // 20 adalah sisa target menuju 30
      nextTarget = 30;
    } else {
      // Level Awal: CONNECT (0 sampai 9 pesan)
      currentLevel = 'CONNECT';
      bannerColor = Colors.blue[800]!;
      progress = chatCount / 10;
      nextTarget = 10;
    }

    return Container(
      width: double.infinity,
      color: bannerColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level: $currentLevel',
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              // GANTI BLOK INI:
              chatCount >= 30 
                  ? (_hasReviewed // Cek apakah ulasan sudah dikirim
                      ? const Text('Ulasan Selesai ✅', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                      : ElevatedButton(
                          onPressed: _showReviewDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Beri Nilai Partner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ))
                  : Text(
                      '$chatCount / $nextTarget Messages',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress Bar untuk visualisasi pencapaian
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.black38,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.black,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog() {
    int selectedRating = 5; // Default bintang 5
    TextEditingController reviewController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false, // User tidak bisa asal tap di luar untuk menutup
      builder: (context) {
        return StatefulBuilder( // StatefulBuilder agar dialog bisa update state (ubah bintang)
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'Rate Your Partner 🌟',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Kalian telah mencapai level PARTNER! Bagaimana pengalaman belajarmu dengan ${widget.chatPartnerName}?',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  // Bintang Rating Interaktif
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Tulis ulasanmu di sini...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Nanti Saja', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          
                          // Asumsi ID lawan adalah ID yang BUKAN currentUserId
                          // Dalam implementasi nyata, kamu mungkin butuh pass ID lawan secara eksplisit.
                          // Untuk sekarang, kita anggap ID bisa ditarik jika diperlukan,
                          // Tapi idealnya kamu menambahkan partnerId di constructor ChatScreen.
                          
                          // KARENA KITA BUTUH ID LAWAN: Mari kita buat skenario sementara (misal ID 6 jika kamu 2).
                          // Idealnya, perbarui ChatListScreen agar mengoper partnerId.
                          
                          var result = await ApiService.submitReview(
                            matchId: widget.matchId,
                            reviewerId: widget.currentUserId,
                            reviewedUserId: widget.chatPartnerId,
                            rating: selectedRating,
                            reviewText: reviewController.text.trim(),
                          );

                          if (!context.mounted) return;

                          setDialogState(() => isSubmitting = false);

                          
                            if (result['status'] == 'success') {
                            Navigator.pop(context); // Tutup dialog
                            
                            // HILANGKAN TOMBOL DI BANNER
                            setState(() {
                              _hasReviewed = true; 
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result['message'])),
                            );
                          } else {
                            // Jika API menolak karena sebelumnya sudah pernah kirim ulasan
                            if (result['message'] == "Kamu sudah memberikan ulasan untuk sesi ini.") {
                              Navigator.pop(context);
                              setState(() {
                                _hasReviewed = true; // Sembunyikan tombolnya juga
                              });
                            }
                            
                             ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result['message'])),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Kirim Ulasan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChatBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? Colors.white : Colors.grey[800],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.black : Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}