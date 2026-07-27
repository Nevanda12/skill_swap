import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String chatPartnerName;
  final int matchId;
  final int currentUserId;
  final int chatPartnerId;
  final String initialStatus;
  final String? chatPartnerPhoto;

  const ChatScreen({
    super.key,
    required this.chatPartnerName,
    required this.matchId,
    required this.currentUserId,
    required this.chatPartnerId,
    this.initialStatus = 'MATCHED',
    this.chatPartnerPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _showEmojiPicker = false;
  List<Map<String, dynamic>> _messages = [];
  bool isLoading = true;
  Timer? _chatTimer;
  bool _hasReviewed = false;

  // Kontrol animasi gelombang air pada indikator level (berjalan terus)
  late final AnimationController _waveController;
  // Key untuk melacak posisi ikon level di layar (untuk animasi percikan)
  final GlobalKey _levelIconKey = GlobalKey();
  // Menyimpan level terakhir untuk mendeteksi kenaikan level
  String? _lastLevelText;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

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
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Info level (warna, ikon, teks, persentase isi) berdasarkan jumlah chat.
  // Logika ambang batas & rumus fillPercentage TIDAK diubah dari versi asli.
  Map<String, dynamic> _levelInfoForCount(int count) {
    if (count >= 30) {
      return {
        'text': 'Partner',
        'color': const Color(0xFFF29C11),
        'icon': Icons.emoji_events_rounded,
        'fill': 1.0,
      };
    } else if (count >= 10) {
      return {
        'text': 'Collaborate',
        'color': const Color(0xFF26B49A),
        'icon': Icons.groups_rounded,
        'fill': (count - 10) / 20.0,
      };
    } else {
      return {
        'text': 'Explorer',
        'color': const Color(0xFF1A73E8),
        'icon': Icons.explore_outlined,
        'fill': count / 10.0,
      };
    }
  }

  // Dipanggil setiap kali _messages berubah untuk mendeteksi kenaikan level
  // dan memicu animasi percikan / perayaan Partner. silent=true dipakai saat
  // load pertama kali agar tidak memicu animasi palsu.
  void _onMessagesUpdated({bool silent = false}) {
    final info = _levelInfoForCount(_messages.length);
    final newLevelText = info['text'] as String;

    if (!silent && _lastLevelText != null && newLevelText != _lastLevelText) {
      _showLevelUpSparkle(info['color'] as Color);
      if (newLevelText == 'Partner') {
        _showPartnerCelebration();
      }
    }
    _lastLevelText = newLevelText;
  }

  // Animasi percikan kembang api kecil di sekitar ikon level saat naik level
  void _showLevelUpSparkle(Color color) {
    if (!mounted) return;
    final renderBox = _levelIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final center = position + Offset(size.width / 2, size.height / 2);

    late OverlayEntry entry;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    entry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            return IgnorePointer(
              child: Stack(
                children: List.generate(8, (i) {
                  final angle = (i / 8) * 2 * pi;
                  final dist = 30 * Curves.easeOut.transform(t);
                  return Positioned(
                    left: center.dx + cos(angle) * dist - 4,
                    top: center.dy + sin(angle) * dist - 4,
                    child: Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Icon(
                        Icons.auto_awesome,
                        color: color,
                        size: 8 + 4 * (1 - t),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(entry);
    controller.forward().whenComplete(() {
      entry.remove();
      controller.dispose();
    });
  }

  // Animasi dramatis di tengah layar saat level Partner tercapai
  void _showPartnerCelebration() {
    if (!mounted) return;
    late OverlayEntry entry;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    entry = OverlayEntry(
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            double opacity;
            if (t < 0.15) {
              opacity = t / 0.15;
            } else if (t > 0.8) {
              opacity = (1 - t) / 0.2;
            } else {
              opacity = 1.0;
            }
            opacity = opacity.clamp(0.0, 1.0);
            final scale = t < 0.25
                ? Curves.elasticOut.transform(t / 0.25).clamp(0.0, 1.2)
                : 1.0;

            return IgnorePointer(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(color: Colors.black.withValues(alpha: 0.25 * opacity)),
                  ),
                  ...List.generate(10, (i) {
                    final angle = (i / 10) * 2 * pi;
                    final dist = 130 * Curves.easeOut.transform(t.clamp(0.0, 1.0));
                    return Positioned(
                      left: screenSize.width / 2 + cos(angle) * dist - 6,
                      top: screenSize.height / 2 + sin(angle) * dist - 6,
                      child: Opacity(
                        opacity: (1 - t).clamp(0.0, 1.0),
                        child: const Icon(Icons.star_rounded, color: Color(0xFFF29C11), size: 14),
                      ),
                    );
                  }),
                  Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: Lottie.asset(
                            'assets/images/badge.json',
                            repeat: false,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(entry);
    controller.forward().whenComplete(() {
      entry.remove();
      controller.dispose();
    });
  }

  String _formatTime(String? dateString) {
    if (dateString == null) {
      final now = DateTime.now();
      return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    try {
      DateTime parsed = DateTime.parse(dateString).toLocal();
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      final now = DateTime.now();
      return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
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
              'time': _formatTime(msg['created_at']),
            };
          }).toList();
        }
      });
      _onMessagesUpdated(silent: true);
      _scrollToBottom();

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
        _hasReviewed = result['has_reviewed'];
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
          'time': _formatTime(msg['created_at']),
        };
      }).toList();

      if (updatedMessages.length != _messages.length) {
        setState(() {
          _messages = updatedMessages;
        });
        _onMessagesUpdated();
        _scrollToBottom();

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
        _messages.add({
          'text': text, 
          'isMe': true,
          'time': _formatTime(null)
        });
        _messageController.clear();
      });
      _onMessagesUpdated();
      _scrollToBottom();

      await ApiService.sendChatMessage(
        matchId: widget.matchId,
        senderId: widget.currentUserId,
        message: text,
      );
    }
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _messageFocusNode.requestFocus();
    } else {
      _messageFocusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  void _showConfirmDialog(String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
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
    
    if (!mounted) return; 

    if (result['status'] == 'success') {
      Navigator.pop(context);
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
    }
  }

  void _blockUser() async {
    setState(() => isLoading = true);
    var result = await ApiService.blockUser(blockerId: widget.currentUserId, blockedId: widget.chatPartnerId);
    
    if (!mounted) return;

    if (result['status'] == 'success') {
      Navigator.pop(context);
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(currentUserId: widget.chatPartnerId, isEditable: false),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[200],
                radius: 18,
                backgroundImage: (widget.chatPartnerPhoto != null && widget.chatPartnerPhoto!.isNotEmpty)
                    ? MemoryImage(base64Decode(widget.chatPartnerPhoto!.split(',').last))
                    : null,
                child: (widget.chatPartnerPhoto == null || widget.chatPartnerPhoto!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.grey, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.chatPartnerName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Tampil jika level partner tercapai & belum direview
                        if (_messages.length >= 30 && !_hasReviewed) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showReviewDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF1A73E8), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.star_border_rounded, size: 13, color: Color(0xFF1A73E8)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Beri Penilaian',
                                    style: TextStyle(color: Color(0xFF1A73E8), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Text(
                      'Online',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            color: const Color(0xFF1E293B),
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onSelected: (value) {
              if (value == 'delete') {
                _showConfirmDialog('Hapus Obrolan', 'Yakin ingin menghapus obrolan ini secara permanen?', _deleteChat);
              } else if (value == 'block') {
                _showConfirmDialog('Blokir Pengguna', 'Yakin ingin memblokir ${widget.chatPartnerName}? Mereka akan hilang dari daftarmu.', _blockUser);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'delete', child: Text('Hapus Obrolan', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'block', child: Text('Blokir Pengguna', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildChatBubble(message['text'], message['isMe'], message['time']);
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // Desain progres level: lingkaran terisi air beranimasi (gelombang berjalan terus),
  // dengan ikon & label berwarna sesuai level. Rumus fillPercentage & ambang batas
  // level TIDAK diubah dari versi asli — hanya cara menampilkannya yang beranimasi.
  Widget _buildLevelProgress() {
    int count = _messages.length;
    final info = _levelInfoForCount(count);
    final double fillPercentage = info['fill'] as double;
    final Color levelColor = info['color'] as Color;
    final String levelText = info['text'] as String;
    final IconData levelIcon = info['icon'] as IconData;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: _levelIconKey,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: levelColor.withValues(alpha: 0.5), width: 2),
            color: Colors.white,
          ),
          child: ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(color: Colors.transparent),
                // Air yang naik & bergelombang secara halus mengikuti progres chat
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: fillPercentage.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedFill, _) {
                      return AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _WaterWavePainter(
                              fillLevel: animatedFill,
                              waveOffset: _waveController.value,
                              color: levelColor,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Icon(
                  levelIcon,
                  size: 14,
                  color: fillPercentage >= 0.55 ? Colors.white : levelColor,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          levelText,
          style: TextStyle(
            fontSize: 8,
            color: levelColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1220),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Panggil fungsi widget indikator level baru di sini
                _buildLevelProgress(),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _messageFocusNode,
                            style: const TextStyle(color: Colors.white),
                            onTap: () {
                              if (_showEmojiPicker) {
                                setState(() => _showEmojiPicker = false);
                              }
                            },
                            decoration: const InputDecoration(
                              hintText: 'Ketik pesan...',
                              hintStyle: TextStyle(color: Colors.white38),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: _toggleEmojiPicker,
                            child: Icon(
                              _showEmojiPicker
                                  ? Icons.keyboard_alt_outlined
                                  : Icons.emoji_emotions_outlined,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Icon(Icons.send_outlined, color: Colors.grey[600], size: 28),
                ),
              ],
            ),
          ),
          Offstage(
            offstage: !_showEmojiPicker,
            child: SizedBox(
              height: 280,
              child: EmojiPicker(
                textEditingController: _messageController,
                onEmojiSelected: (category, emoji) {
                  // textEditingController sudah menyisipkan emoji secara
                  // otomatis, callback ini dibiarkan kosong.
                },
                config: Config(
                  height: 280,
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor: const Color(0xFF0B1220),
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    backgroundColor: Color(0xFF1E293B),
                    buttonColor: Color(0xFF1E293B),
                  ),
                  categoryViewConfig: const CategoryViewConfig(
                    backgroundColor: Color(0xFF0B1220),
                    iconColorSelected: Color(0xFF1A73E8),
                    indicatorColor: Color(0xFF1A73E8),
                  ),
                  searchViewConfig: const SearchViewConfig(
                    backgroundColor: Color(0xFF0B1220),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Label rating dinamis sesuai jumlah bintang yang dipilih
  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Sangat Buruk';
      case 2:
        return 'Buruk';
      case 3:
        return 'Cukup';
      case 4:
        return 'Baik';
      case 5:
        return 'Sangat Baik';
      default:
        return '';
    }
  }

  // Desain dialog "Beri Penilaian" mengikuti tampilan kartu vertikal pada referensi
  void _showReviewDialog() {
    int selectedRating = 5;
    TextEditingController reviewController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Badge bintang di bagian atas
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1A73E8).withValues(alpha: 0.08),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFF1A73E8),
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Beri Penilaian',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bagaimana pengalamanmu bertukar skill bersama ${widget.chatPartnerName}?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedRating = index + 1;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                index < selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                                color: const Color(0xFFF29C11),
                                size: 34,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _ratingLabel(selectedRating),
                        style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: reviewController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Tulis ulasanmu di sini...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Kotak informasi: ulasan bersifat publik (kebalikan dari desain acuan)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.public, size: 18, color: Color(0xFF1A73E8)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Ulasan ini akan dipublikasikan',
                                    style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Ulasanmu akan dapat dilihat oleh pengguna lain di Skill Swap.',
                                    style: TextStyle(color: Colors.black54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFEEEEEE)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Batal', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      setDialogState(() => isSubmitting = true);

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
                                        Navigator.pop(context);
                                        setState(() {
                                          _hasReviewed = true;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(result['message'])),
                                        );
                                      } else {
                                        if (result['message'] == "Kamu sudah memberikan ulasan untuk sesi ini.") {
                                          Navigator.pop(context);
                                          setState(() {
                                            _hasReviewed = true;
                                          });
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(result['message'])),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A73E8),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Kirim Penilaian', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatBubble(String text, bool isMe, String time) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF1A73E8) : const Color(0xFF1E293B),
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
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            time,
            style: const TextStyle(
              color: Colors.black38,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

// Menggambar "air" yang bergelombang mengisi lingkaran indikator level.
// fillLevel: 0.0 - 1.0 (seberapa penuh), waveOffset: 0.0 - 1.0 (fase animasi berjalan)
class _WaterWavePainter extends CustomPainter {
  final double fillLevel;
  final double waveOffset;
  final Color color;

  _WaterWavePainter({
    required this.fillLevel,
    required this.waveOffset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fillLevel <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const waveHeight = 1.6;
    final baseY = size.height * (1 - fillLevel);

    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, baseY);
    for (double x = 0; x <= size.width; x += 1) {
      final y = baseY + sin((x / size.width * 2 * pi) + (waveOffset * 2 * pi)) * waveHeight;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaterWavePainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel ||
        oldDelegate.waveOffset != waveOffset ||
        oldDelegate.color != color;
  }
}