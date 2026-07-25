import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart'; // Mengimpor API Service[cite: 1]
import 'register_screen.dart'; //[cite: 1]
import 'home_screen.dart'; //[cite: 1]
import 'edit_profile_screen.dart'; // Halaman lengkapi profil untuk akun baru
import 'profile_screen.dart'; // Tujuan setelah selesai lengkapi profil
import 'otp_verification_screen.dart'; // Halaman verifikasi OTP
import '../services/session_service.dart'; // Penyimpan status login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 1. Controller untuk menangkap teks yang diketik user[cite: 1]
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  // State untuk toggle visibilitas password[cite: 1]
  bool _isPasswordVisible = false;

  // Instance untuk proses Google Sign-In
  // clientId ini WAJIB diisi dengan Web Client ID dari Google Cloud Console
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    // serverClientId dipakai agar kita bisa dapat idToken yang valid untuk dikirim ke backend
    serverClientId: '422269025055-747oje514kdtve4e0c781bqthqq530gp.apps.googleusercontent.com',
  );

  // Fungsi Login dengan Google
  void _handleGoogleLogin() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User membatalkan login

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (!mounted) return;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mendapatkan token dari Google.")),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Memverifikasi akun Google..."), duration: Duration(seconds: 1)),
      );

      var result = await ApiService.googleLogin(idToken: idToken);

      if (!mounted) return;

      if (result['status'] == 'success') {
        String name = result['user']['full_name'];
        int userId = result['user']['id'];

        // Simpan sesi supaya user tidak perlu login ulang lain kali
        await SessionService.saveSession(
          userId: userId,
          fullName: name,
          email: result['user']['email'] ?? '',
        );
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Berhasil! Selamat Datang $name")),
        );
        await _goToHomeOrEditProfile(userId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "Login Google gagal!")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi kesalahan saat login Google: $e")),
      );
    }
  }

  // Mengecek apakah profil user masih kosong (akun baru yang belum mengisi skill
  // sama sekali). Jika kosong, arahkan dulu ke Edit Profile sebelum masuk Home.
  Future<void> _goToHomeOrEditProfile(int userId) async {
    var profileResult = await ApiService.getUserProfile(userId);
    if (!mounted) return;

    bool profileEmpty = false;
    Map<String, dynamic>? profileData;
    if (profileResult['status'] == 'success') {
      profileData = profileResult['data'];
      List canSkills = profileData?['skills']?['can'] ?? [];
      List wantSkills = profileData?['skills']?['want'] ?? [];
      profileEmpty = canSkills.isEmpty && wantSkills.isEmpty;
    }

    if (profileEmpty && profileData != null) {
      // Push BIASA (bukan pushReplacement) supaya saat EditProfileScreen di-pop
      // (tombol Simpan / tombol back), ada halaman untuk kembali — kalau tadinya
      // pakai pushReplacement, LoginScreen sudah hilang dari stack dan pop()
      // di EditProfileScreen berujung ke layar hitam kosong.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfileScreen(userId: userId, currentData: profileData!),
        ),
      );
      if (!mounted) return;

      // Sesuai alur simpan profil biasa: arahkan ke halaman Profile dulu,
      // dari situ user bisa pindah ke Home sendiri lewat bottom nav.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(currentUserId: userId, isEditable: true),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(userId: userId)),
    );
  }

  // 2. Fungsi Logika Login (Dipertahankan persis seperti aslinya)[cite: 1]
  void _handleLogin() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan Password tidak boleh kosong!")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sedang memverifikasi data..."), duration: Duration(seconds: 1)),
    );

    var result = await ApiService.loginUser(email: email, password: password);

    if (!mounted) return; 

    if (result['status'] == 'success' || result.containsKey('user')) {
      String name = result['user'] != null ? result['user']['full_name'] : "Pengguna";
      int userId = result['user']['id'];

      // Simpan sesi supaya user tidak perlu login ulang lain kali
      await SessionService.saveSession(
        userId: userId,
        fullName: name,
        email: result['user']['email'] ?? email,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Berhasil! Selamat Datang $name")),
      );

      await _goToHomeOrEditProfile(userId);
    } else if (result['needs_verification'] == true) {
      // Akun belum verifikasi OTP -> arahkan ke halaman verifikasi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Akun belum diverifikasi.")),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OtpVerificationScreen(email: result['email'] ?? email)),
      );
    } else {
      String errorMessage = result['detail'] ?? result['message'] ?? "Login Gagal! Akun tidak cocok.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  // 3. Bersihkan memori saat halaman ditutup[cite: 1]
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040B1A), // Warna dasar gelap
      body: Stack(
        children: [
          // Lapisan dasar gradient gelap
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF081C42), // Biru gelap[cite: 1]
                  Color(0xFF040B1A), // Biru sangat gelap kehitaman[cite: 1]
                ],
              ),
            ),
          ),
          // Lapisan dekoratif: bulatan cahaya lembut agar background tidak polos
          Positioned(
            top: -90,
            left: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.28),
                    const Color(0xFF3B82F6).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -110,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2DD4BF).withValues(alpha: 0.18),
                    const Color(0xFF2DD4BF).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 260,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                    const Color(0xFF1E3A8A).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Lapisan konten
          SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0), //[cite: 1]
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- BAGIAN ATAS: Logo dan Judul Aplikasi ---
                  Image.asset(
                    'assets/images/logo.png',
                    height: 100,
                  ),
                  const SizedBox(height: 14),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(text: 'Skill ', style: TextStyle(color: Colors.white)),
                        TextSpan(text: 'Swap', style: TextStyle(color: Color(0xFF2DD4BF))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Swap skills, grow together.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24.0), //[cite: 1]
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F213F), // Warna card sedikit lebih terang, kontras dari background
                      borderRadius: BorderRadius.circular(20), //[cite: 1]
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 15, //[cite: 1]
                          offset: const Offset(0, 5), //[cite: 1]
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back!',
                          style: TextStyle(
                            fontSize: 22, //[cite: 1]
                            fontWeight: FontWeight.bold, //[cite: 1]
                            color: Colors.white, //[cite: 1]
                          ),
                        ),
                        const SizedBox(height: 6), //[cite: 1]
                        const Text(
                          'Login to continue your journey',
                          style: TextStyle(fontSize: 14, color: Colors.white54), //[cite: 1]
                        ),
                        const SizedBox(height: 32), //[cite: 1]

                        // Form Email
                        const Text(
                          'Email',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), //[cite: 1]
                        ),
                        const SizedBox(height: 8), //[cite: 1]
                        TextField(
                          controller: emailController, //[cite: 1]
                          style: const TextStyle(color: Colors.white), //[cite: 1]
                          keyboardType: TextInputType.emailAddress, //[cite: 1]
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14), //[cite: 1]
                            filled: true, //[cite: 1]
                            fillColor: const Color(0xFF091428), //[cite: 1]
                            // Icon diubah warnanya menyesuaikan gambar (Cyan/Teal)
                            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2DD4BF), size: 20),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16), //[cite: 1]
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), //[cite: 1]
                              borderSide: const BorderSide(color: Colors.white12), //[cite: 1]
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), //[cite: 1]
                              borderSide: const BorderSide(color: Colors.white12), //[cite: 1]
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), //[cite: 1]
                              borderSide: const BorderSide(color: Color(0xFF2DD4BF)), //[cite: 1]
                            ),
                          ),
                        ),
                        const SizedBox(height: 20), //[cite: 1]

                        // Form Password
                        const Text(
                          'Password',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), //[cite: 1]
                        ),
                        const SizedBox(height: 8), //[cite: 1]
                        TextField(
                          controller: passwordController, //[cite: 1]
                          obscureText: !_isPasswordVisible, //[cite: 1]
                          style: const TextStyle(color: Colors.white), //[cite: 1]
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14), //[cite: 1]
                            filled: true, //[cite: 1]
                            fillColor: const Color(0xFF091428), //[cite: 1]
                            // Icon diubah warnanya menyesuaikan gambar (Cyan/Teal)
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF2DD4BF), size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off, //[cite: 1]
                                color: const Color(0xFF2DD4BF), // Disesuaikan dengan tema cyan
                                size: 20, //[cite: 1]
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible; //[cite: 1]
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16), //[cite: 1]
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), //[cite: 1]
                              borderSide: const BorderSide(color: Colors.white12), //[cite: 1]
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), //[cite: 1]
                              borderSide: const BorderSide(color: Colors.white12), //[cite: 1]
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), //[cite: 1]
                              borderSide: const BorderSide(color: Color(0xFF2DD4BF)), //[cite: 1]
                            ),
                          ),
                        ),
                        
                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight, //[cite: 1]
                          child: TextButton(
                            onPressed: () {
                              // Aksi forgot password[cite: 1]
                            },
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(color: Color(0xFF3B82F6), fontSize: 13), //[cite: 1]
                            ),
                          ),
                        ),
                        const SizedBox(height: 12), //[cite: 1]

                        // Tombol Login Gradient
                        Container(
                          width: double.infinity, //[cite: 1]
                          height: 50, //[cite: 1]
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF2DD4BF)], // Biru ke Teal[cite: 1]
                            ),
                            borderRadius: BorderRadius.circular(12), //[cite: 1]
                          ),
                          child: ElevatedButton(
                            onPressed: _handleLogin, //[cite: 1]
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent, //[cite: 1]
                              shadowColor: Colors.transparent, //[cite: 1]
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12), //[cite: 1]
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center, //[cite: 1]
                              children: [
                                Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Colors.white, //[cite: 1]
                                    fontSize: 16, //[cite: 1]
                                    fontWeight: FontWeight.bold, //[cite: 1]
                                  ),
                                ),
                                SizedBox(width: 8), //[cite: 1]
                                
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Divider "OR"
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('OR', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            ),
                            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Tombol Login with Google
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _handleGoogleLogin,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFF091428),
                              side: const BorderSide(color: Colors.white12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: Image.network(
                              'https://www.google.com/favicon.ico',
                              height: 18,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.g_mobiledata, color: Colors.white, size: 22),
                            ),
                            label: const Text(
                              'Login with Google',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28), //[cite: 1]

                        // Sign up text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center, //[cite: 1]
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: Colors.white70, fontSize: 13), //[cite: 1]
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()), //[cite: 1]
                                );
                              },
                              child: const Text(
                                'Sign up',
                                style: TextStyle(
                                  color: Color(0xFF3B82F6), //[cite: 1]
                                  fontWeight: FontWeight.bold, //[cite: 1]
                                  fontSize: 13, //[cite: 1]
                                ),
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
          ),
        ],
      ),
    );
  }
}