import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../data/skill_catalog.dart';
import 'user_search_screen.dart';

class ExploreScreen extends StatefulWidget {
  final Function(String) onCategorySelected;

  const ExploreScreen({super.key, required this.onCategorySelected});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<Map<String, dynamic>> _skillsSummary = [];
  bool _isLoading = true;

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
        // Backend (/api/skills/summary) hanya mengembalikan skill yang SUDAH
        // punya minimal 1 user (COUNT(DISTINCT user_id) ... GROUP BY skill_name).
        // Itu sebabnya sebelumnya cuma 9 kartu yang muncul, padahal skill yang
        // tersedia di profil ada 21 (lihat SkillCatalog.all). Di sini kita
        // gabungkan hasil database dengan seluruh katalog skill, supaya semua
        // skill tetap tampil (yang belum punya user akan menampilkan 0).
        final data = result['status'] == 'success' ? (result['data'] ?? []) : [];
        _skillsSummary = _mergeWithCatalog(data);
      });
    }
  }

  List<Map<String, dynamic>> _mergeWithCatalog(List<dynamic> dbData) {
    // Peta jumlah user per skill, persis seperti dikembalikan database (tidak diubah).
    final Map<String, int> countMap = {
      for (var row in dbData)
        row['skill_name'] as String: (row['total_users'] as num).toInt()
    };

    final merged = SkillCatalog.all.map((skillName) {
      return {
        'skill_name': skillName,
        'total_users': countMap[skillName] ?? 0,
      };
    }).toList();

    // Skill dengan user terbanyak tampil duluan; yang seri (termasuk yang masih 0) diurutkan alfabetis.
    merged.sort((a, b) {
      final countCompare = (b['total_users'] as int).compareTo(a['total_users'] as int);
      if (countCompare != 0) return countCompare;
      return (a['skill_name'] as String).compareTo(b['skill_name'] as String);
    });

    return merged;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Latar belakang transparan agar mewarisi gradasi dari HomeScreen
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Jelajah',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26, letterSpacing: 0.5),
        ),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2CB69D)))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserSearchScreen()),
                      );
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1629),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF1E3A6D).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFF8B9CB6), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Cari nama pengguna...',
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(bottom: 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.78, // Proporsi kotak memanjang ke bawah
                      ),
                      itemCount: _skillsSummary.length,
                      itemBuilder: (context, index) {
                        var skill = _skillsSummary[index];
                        String skillName = skill['skill_name'];
                        int userCount = skill['total_users'];
                        // Nama file aset dibentuk otomatis dari nama skill, contoh:
                        // 'UI/UX Design' -> assets/images/ui_ux_design.png
                        // Tinggal taruh file gambar dengan nama itu di assets/images/.
                        String imagePath = 'assets/images/${SkillCatalog.slug(skillName)}.png';
                       

                        return GestureDetector(
                          onTap: () {
                            widget.onCategorySelected(skillName);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1629), // Warna dark blue sesuai desain
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF1E3A6D).withValues(alpha: 0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                children: [
                                  // Efek gelombang/cahaya biru di pojok kanan bawah
                                  Positioned(
                                    bottom: -40,
                                    right: -40,
                                    child: Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            const Color(0xFF1A73E8).withValues(alpha: 0.15),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 1. Lingkaran latar belakang — KOSONG di tengah, siap diisi logo asetmu.
                                  // Kalau assets/images/<nama_skill>.png belum ada, lingkaran tetap
                                  // tampil rapi tanpa ikon placeholder (tidak ada lagi ikon kotak default).
                                  Positioned(
                                    top: 30,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        width: 86,
                                        height: 86,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF111E36), // Warna lingkaran belakang logo
                                          shape: BoxShape.circle,
                                        ),
                                        child: ClipOval(
                                          child: Image.asset(
                                            imagePath,
                                            height: 44,
                                            width: 44,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 2. Teks Nama Skill & Jumlah User
                                  Positioned(
                                    bottom: 20,
                                    left: 16,
                                    right: 16,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          skillName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1A3563), // Kotak badge biru
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                userCount.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Orang aktif',
                                              style: TextStyle(
                                                color: Color(0xFF8B9CB6), // Abu-abu kebiruan
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
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