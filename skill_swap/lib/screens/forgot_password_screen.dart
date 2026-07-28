import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false; // false = tahap masukin email, true = tahap masukin OTP + password baru

  static const Color bgColor = Color(0xFF0B1220);
  static const Color fieldColor = Color(0xFF1E293B);
  static const Color primaryBlue = Color(0xFF3B82F6);

  void _sendOtp() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnack('Email tidak boleh kosong.');
      return;
    }
    setState(() => _isLoading = true);
    var result = await ApiService.forgotPassword(email: _emailController.text.trim());
    setState(() => _isLoading = false);

    if (result['status'] == 'success') {
      _showSnack(result['message'] ?? 'Kode OTP sudah dikirim.');
      setState(() => _otpSent = true);
    } else {
      _showSnack(result['message'] ?? 'Gagal mengirim OTP.');
    }
  }

  void _submitNewPassword() async {
    if (_otpController.text.trim().isEmpty || _newPasswordController.text.trim().isEmpty) {
      _showSnack('Kode OTP dan password baru wajib diisi.');
      return;
    }
    setState(() => _isLoading = true);
    var result = await ApiService.resetPassword(
      email: _emailController.text.trim(),
      otpCode: _otpController.text.trim(),
      newPassword: _newPasswordController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (result['status'] == 'success') {
      _showSnack(result['message'] ?? 'Password berhasil diubah.');
      if (mounted) Navigator.pop(context);
    } else {
      _showSnack(result['message'] ?? 'Gagal mengubah password.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: fieldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Lupa Password', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _otpSent
                    ? 'Masukkan kode OTP yang dikirim ke email kamu, lalu buat password baru.'
                    : 'Masukkan email akun kamu, kami akan kirimkan kode OTP untuk reset password.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                enabled: !_otpSent,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: _fieldDecoration('Email'),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _otpController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration('Kode OTP'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPasswordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: _fieldDecoration('Password Baru'),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_otpSent ? _submitNewPassword : _sendOtp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _otpSent ? 'Ubah Password' : 'Kirim Kode OTP',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: const Text('Kirim ulang kode OTP', style: TextStyle(color: primaryBlue)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}