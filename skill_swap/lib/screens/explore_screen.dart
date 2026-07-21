import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ExploreScreen extends StatefulWidget {
  final Function(String) onCategorySelected;

  const ExploreScreen({super.key, required this.onCategorySelected});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<dynamic> _skillsSummary = [];
  bool _isLoading = true;

  // Pemetaan rute gambar lokal (assets). Sesuaikan nama file gambarmu nanti di sini.
  final Map<String, String> _skillImages = {
    'Flutter': 'assets/images/flutter.png',
    'Python': 'assets/images/python.png',
    'UI/UX Design': 'assets/images/uiux.png',
    // Nanti kamu bisa tambahkan nama skill lain dan path gambarnya di sini
  };

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  void _fetchSummary() async {
    var result = await ApiService.getSkillsSummary();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['status'] == 'success') {
          _skillsSummary = result['data'] ?? [];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Jelajah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cari seseorang yang punya tujuan sama',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8, // Agar kotak sedikit memanjang ke bawah
                      ),
                      itemCount: _skillsSummary.length,
                      itemBuilder: (context, index) {
                        var skill = _skillsSummary[index];
                        String skillName = skill['skill_name'];
                        int userCount = skill['total_users'];
                        String imagePath = _skillImages[skillName] ?? 'assets/images/default.png';

                        return GestureDetector(
                          onTap: () {
                            // Kirim nama skill kembali ke beranda saat diklik
                            widget.onCategorySelected(skillName);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              children: [
                                // 1. Gambar Asset di tengah
                                Positioned(
                                  top: 20,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Image.asset(
                                      imagePath,
                                      height: 80,
                                      // Jika gambar gagal dimuat (belum ada), tampilkan ikon ini
                                      errorBuilder: (context, error, stackTrace) => 
                                          const Icon(Icons.category, size: 80, color: Colors.white24),
                                    ),
                                  ),
                                ),
                                // 2. Teks Nama Skill & Jumlah User
                                Positioned(
                                  bottom: 16,
                                  left: 16,
                                  right: 16,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          skillName,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        userCount.toString(),
                                        style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
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
    );
  }
}