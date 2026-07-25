import 'package:flutter/material.dart';
import 'login_screen.dart'; // Pastikan path ini benar sesuai struktur foldermu
import 'home_screen.dart';
import '../services/session_service.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // true selama proses pengecekan sesi login berlangsung
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  // Cek apakah ada sesi login tersimpan di HP. Kalau ada, langsung
  // lompat ke HomeScreen tanpa menampilkan tombol "Get Started".
  Future<void> _checkExistingSession() async {
    final userId = await SessionService.getUserId();

    if (!mounted) return;

    if (userId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(userId: userId)),
      );
    } else {
      setState(() => _checkingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Selama masih mengecek sesi, tampilkan layar kosong bergradasi
    // (menghindari kedipan/flash tampilan splash sebelum pindah ke Home)
    if (_checkingSession) {
      return const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFF041C44), Color(0xFF0A58CA)],
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      // Hapus backgroundColor hitam, ganti dengan body ber-gradient
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xFF041C44), // Biru sangat gelap di bawah
              Color(0xFF0A58CA), // Biru terang di atas
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Menyebar elemen dari atas ke bawah
              children: [
                // BAGIAN ATAS: Logo dan Teks
                Column(
                  children: [
                    // 1. Logo Aplikasi (Pastikan path file ini benar di pubspec.yaml)
                    Image.asset(
                      'assets/images/logo.png', // Atau .png transparan yang kamu buat
                      height: 100,
                    ),
                    const SizedBox(height: 16),
                    
                    // 2. Teks Skill Swap 2 Warna
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'Skill ',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'Swap',
                            style: TextStyle(color: Color(0xFF4ADE80)), // Hijau cerah / Teal
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // 3. Subtitle
                    const Text(
                      'Swap skills, Grow together.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),

                // BAGIAN TENGAH: Ilustrasi Orang Mengobrol
                // Silakan download ilustrasi dari undraw.co atau freepik.com
                // Simpan di folder assets/images/ dengan nama illustration.png
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Lottie.asset(
                      'assets/images/team.json', // Ganti dengan gambar ilustrasimu
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // BAGIAN BAWAH: Tombol dan Teks Login
                Column(
                  children: [
                    // Tombol Get Started
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigasi ke layar Login
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1CB58F), // Warna hijau tombol
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Teks I already have an account
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'I already have an account',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}