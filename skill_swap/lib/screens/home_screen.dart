import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'match_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 1. Data Dummy Pengguna Lain
  List<Map<String, dynamic>> dummyUsers = [
    {
      'name': 'Alex',
      'age': 22,
      'can': 'Flutter Development',
      'want': 'UI/UX Design'
    },
    {
      'name': 'Budi',
      'age': 24,
      'can': 'Python & FastAPI',
      'want': 'Mobile App Dev'
    },
    {
      'name': 'Citra',
      'age': 21,
      'can': 'UI/UX Design',
      'want': 'Database MySQL'
    },
  ];

  // 2. Fungsi Logika Swipe (Kanan/Kiri)
  void _handleSwipe(bool isRightSwipe, Map<String, dynamic> swipedUser) {
    setState(() {
      dummyUsers.removeAt(0); // Hapus kartu dari daftar
    });

    // Simulasi Algoritma Match
    if (isRightSwipe && swipedUser['name'] == 'Alex') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchScreen(
            matchedUserName: swipedUser['name'],
            matchedUserSkill: swipedUser['can'],
          ),
        ),
      );
    }
  }

  // Fungsi trigger untuk tombol manual di bawah
  void _swipeCardFromButton(bool isRightSwipe) {
    if (dummyUsers.isNotEmpty) {
      _handleSwipe(isRightSwipe, dummyUsers[0]);
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // 3. Area Tumpukan Kartu
            Expanded(
              child: dummyUsers.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada lagi pengguna di sekitarmu.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : Stack(
                      children: dummyUsers.asMap().entries.map((entry) {
                        int index = entry.key;
                        var user = entry.value;
                        bool isFrontCard = index == 0;

                        Widget card = _buildCard(user);

                        if (isFrontCard) {
                          return Dismissible(
                            key: Key(user['name']),
                            direction: DismissDirection.horizontal,
                            // Memicu fungsi match saat kartu di-swipe pakai jari
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
                    onPressed: () => _swipeCardFromButton(false), // Swipe Kiri = false
                  ),
                ),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.black, size: 28),
                    onPressed: () => _swipeCardFromButton(true), // Swipe Kanan = true
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

  // 5. Desain Kartu
  Widget _buildCard(Map<String, dynamic> user) {
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
                    '${user['name']}, ${user['age']}',
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
                          'Can: ${user['can']}',
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
                          'Want: ${user['want']}',
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