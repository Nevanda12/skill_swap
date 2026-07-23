import 'dart:math';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'package:lottie/lottie.dart';

class MatchScreen extends StatefulWidget {
  final String matchedUserName;
  final String matchedUserSkill;
  final int matchId;
  final int currentUserId;
  final int matchedUserId;

  const MatchScreen({
    super.key,
    required this.matchedUserName,
    required this.matchedUserSkill,
    required this.matchId,
    required this.currentUserId,
    required this.matchedUserId,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  final List<_ConfettiPiece> _pieces = [];

  static const Color accent = Color(0xFF2CB69D);

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    final rnd = Random();
    final colors = [accent, Colors.amberAccent, Colors.white, Colors.lightGreenAccent];
    for (int i = 0; i < 26; i++) {
      _pieces.add(_ConfettiPiece(
        angle: rnd.nextDouble() * 2 * pi,
        distance: 140 + rnd.nextDouble() * 180,
        size: 6 + rnd.nextDouble() * 8,
        color: colors[rnd.nextInt(colors.length)],
        rotationSpeed: (rnd.nextDouble() - 0.5) * 10,
        isRibbon: rnd.nextBool(),
      ));
    }

    // Mainkan animasi begitu layar muncul.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background dari assets, sesuai yang sudah disiapkan.
          Positioned.fill(
            child: Image.asset(
              'assets/images/hijau.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay gelap tipis supaya teks tetap kebaca di atas background.
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),

          // Konten utama
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        children: [
                          TextSpan(text: "It's a ", style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'Match!', style: TextStyle(color: accent)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 15, color: Colors.grey),
                        children: [
                          const TextSpan(text: 'You and '),
                          TextSpan(
                            text: widget.matchedUserName,
                            style: const TextStyle(color: accent, fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' liked each other.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Dua avatar + icon swap di tengah
                    // Dua avatar + icon swap di tengah
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _glowAvatar(
                          background: Colors.grey[850]!, 
                          jsonPath: 'assets/images/otak-swap.json', // Ganti dengan path JSON pertama
                        ),
                        _dottedConnector(),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF08251F),
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.withValues(alpha: 0.6)),
                            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)],
                          ),
                          child: const Icon(Icons.sync_alt, color: accent, size: 22),
                        ),
                        _dottedConnector(),
                        _glowAvatar(
                          background: Colors.white, 
                          jsonPath: 'assets/images/otak-biru.json', // Ganti dengan path JSON kedua
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Kartu skill
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.school, color: accent, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ready to exchange skills?',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(
                                  widget.matchedUserSkill,
                                  style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Tombol Send a Message (gradient hijau)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [accent, Color(0xFF3ED9A6)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    chatPartnerName: widget.matchedUserName,
                                    matchId: widget.matchId,
                                    currentUserId: widget.currentUserId,
                                    chatPartnerId: widget.matchedUserId,
                                  ),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.chat_bubble_outline, color: Colors.black, size: 20),
                                      SizedBox(width: 10),
                                      Text('Send a Message',
                                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.black),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tombol Keep Swapping (outline)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.explore_outlined, color: Colors.white, size: 20),
                                  SizedBox(width: 10),
                                  Text('Keep Swapping',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              Icon(Icons.chevron_right, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
                        children: [
                          TextSpan(text: 'Great connections start here.\n'),
                          TextSpan(text: "Let's "),
                          TextSpan(text: 'learn', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                          TextSpan(text: ' and '),
                          TextSpan(text: 'grow', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                          TextSpan(text: ' together!'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Overlay confetti/pita meledak, diletakkan paling atas & tidak menghalangi tap.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _ConfettiPainter(_pieces, _confettiController.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowAvatar({required Color background, required String jsonPath}) { // Ubah parameter iconColor menjadi jsonPath
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 2)],
      ),
      child: CircleAvatar(
        radius: 42,
        backgroundColor: background,
        // Gunakan ClipOval agar animasi tidak keluar dari batas lingkaran
        child: ClipOval(
          child: Lottie.asset(
            jsonPath,
            width: 60, // Sesuaikan ukuran animasi jika diperlukan
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _dottedConnector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4), shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

/// Deskripsi satu potong confetti/pita: arah ledakan, jarak, ukuran & warna.
class _ConfettiPiece {
  final double angle;
  final double distance;
  final double size;
  final Color color;
  final double rotationSpeed;
  final bool isRibbon;

  _ConfettiPiece({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.rotationSpeed,
    required this.isRibbon,
  });
}

/// Menggambar ledakan confetti dari titik tengah-atas layar, memudar di akhir animasi.
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double t; // 0.0 -> 1.0

  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final origin = Offset(size.width / 2, size.height * 0.32);
    final eased = Curves.easeOut.transform(t.clamp(0.0, 1.0));

    for (final p in pieces) {
      final dx = cos(p.angle) * p.distance * eased;
      final dy = sin(p.angle) * p.distance * eased + 260 * eased * eased; // efek jatuh (gravitasi)
      final pos = origin + Offset(dx, dy);

      double opacity;
      if (t < 0.55) {
        opacity = 1.0;
      } else {
        opacity = (1 - (t - 0.55) / 0.45).clamp(0.0, 1.0);
      }
      if (opacity <= 0) continue;

      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      final rotation = p.rotationSpeed * t * 2 * pi;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rotation);
      if (p.isRibbon) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size * 2.2, height: p.size * 0.7),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}