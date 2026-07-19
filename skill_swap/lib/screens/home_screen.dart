import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'match_screen.dart';
import '../services/api_service.dart'; // Wajib diimpor untuk memanggil API

class HomeScreen extends StatefulWidget {
  final int userId; // Menampung ID user yang sedang login

  // Konstruktor diubah agar wajib menerima userId dari halaman Login
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 1. Data Asli dari Database
  List<dynamic> discoverUsers = [];
  bool isLoading = true; // Indikator loading saat mengambil data
  String emptyMessage = "";

  @override
  void initState() {
    super.initState();
    // Panggil fungsi tarik data saat halaman pertama kali dibuka
    _loadDiscoveryData();
  }

  // Fungsi untuk menarik data dari FastAPI
  void _loadDiscoveryData() async {
    var result = await ApiService.discoverUsers(widget.userId);
    
    if (mounted) {
      setState(() {
        isLoading = false;
        if (result['status'] == 'success') {
          discoverUsers = result['data'] ?? [];
        } else {
          emptyMessage = result['message'] ?? "Belum ada kecocokan skill saat ini.";
        }
      });
    }
  }

void _handleSwipe(bool isRightSwipe, dynamic swipedUser) async {
    int swipedId = swipedUser['id'];
    String swipedName = swipedUser['name'] ?? swipedUser['full_name'] ?? 'Pengguna';
    String swipedSkill = (swipedUser['skills']['can'] as List).isNotEmpty 
        ? (swipedUser['skills']['can'] as List).join(', ') 
        : '-';

    // 1. Kirim data swipe ke server FastAPI terlebih dahulu
    var result = await ApiService.swipeUser(
      swiperId: widget.userId,
      swipedId: swipedId,
      isLiked: isRightSwipe,
    );

    if (!mounted) return;

    // 2. Jika sukses dan terjadi match, arahkan ke widget kelas MatchScreen
    if (result['status'] == 'success' && result['is_match'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchScreen(
            matchedUserName: swipedName,
            matchedUserSkill: swipedSkill,
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
      // Jika tidak match, cukup hapus kartu dari tampilan beranda
      setState(() {
        if (discoverUsers.isNotEmpty) discoverUsers.removeAt(0);
      });
    }
  }

  // Fungsi trigger untuk tombol manual di bawah
  void _swipeCardFromButton(bool isRightSwipe) {
    if (discoverUsers.isNotEmpty) {
      _handleSwipe(isRightSwipe, discoverUsers[0]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'SKILL SWAP',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      // Tampilkan indikator loading jika data masih ditarik dari server
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // 3. Area Tumpukan Kartu
                  Expanded(
                    child: discoverUsers.isEmpty
                        ? Center(
                            child: Text(
                              emptyMessage.isNotEmpty ? emptyMessage : 'Tidak ada lagi pengguna di sekitarmu.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : Stack(
                            children: discoverUsers.asMap().entries.map((entry) {
                              int index = entry.key;
                              var user = entry.value;
                              bool isFrontCard = index == 0;

                              Widget card = _buildCard(user);

                              if (isFrontCard) {
                                return Dismissible(
                                  // Gunakan ID user sebagai key agar unik
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
                  
                  const SizedBox(height: 24),
                  
                  // 4. Tombol Kontrol Bawah
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[900],
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 28),
                          onPressed: () => _swipeCardFromButton(false),
                        ),
                      ),
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.black, size: 28),
                          onPressed: () => _swipeCardFromButton(true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // 5. Desain Kartu (Telah disesuaikan dengan format JSON dari API)
  Widget _buildCard(dynamic user) {
    // Mengekstrak daftar skill dari API
    String canSkills = (user['skills']['can'] as List).isNotEmpty 
        ? (user['skills']['can'] as List).join(', ') 
        : '-';
    String wantSkills = (user['skills']['want'] as List).isNotEmpty 
        ? (user['skills']['want'] as List).join(', ') 
        : '-';
    String displayName = user['name'] ?? user['full_name'] ?? 'Pengguna';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Container(
              color: Colors.grey[850],
              child: const Center(
                child: Icon(Icons.account_box, size: 150, color: Colors.grey),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Can: $canSkills',
                          style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Want: $wantSkills',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
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
}