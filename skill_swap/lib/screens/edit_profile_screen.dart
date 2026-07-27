import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'skill_icon_helper.dart';
import '../data/skill_catalog.dart';

class EditProfileScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> currentData;

  const EditProfileScreen({super.key, required this.userId, required this.currentData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  File? _imageFile;
  String? _base64Image;

  // Latar belakang custom dari galeri
  File? _backgroundImageFile;
  String? _base64Background;

  bool isSaving = false;
  late final TextEditingController _nameController;

  final List<String> _availableSkills = SkillCatalog.all;

  List<String> _selectedCanSkills = [];
  String _selectedWantSkill = '';

  @override
  void initState() {
    super.initState();
    List<dynamic> canList = widget.currentData['skills']['can'] ?? [];
    List<dynamic> wantList = widget.currentData['skills']['want'] ?? [];

    _selectedCanSkills = canList.map((e) => e.toString()).toList();
    _selectedWantSkill = wantList.isNotEmpty ? wantList.first.toString() : '';

    if (widget.currentData['profile_photo'] != null) {
      _base64Image = widget.currentData['profile_photo'];
    }
    if (widget.currentData['background_photo'] != null) {
      _base64Background = widget.currentData['background_photo'];
    }
    _nameController = TextEditingController(text: widget.currentData['full_name'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      final bytes = await _imageFile!.readAsBytes();
      _base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
    }
  }

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);

    if (pickedFile != null) {
      setState(() {
        _backgroundImageFile = File(pickedFile.path);
      });
      final bytes = await _backgroundImageFile!.readAsBytes();
      _base64Background = "data:image/jpeg;base64,${base64Encode(bytes)}";
    }
  }

  void _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
         content: Text('Nama tidak boleh kosong.'),
         backgroundColor: Colors.red,
       ));
       return;
    }

    if (_selectedWantSkill.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
         content: Text('Tolong pilih 1 skill yang ingin dipelajari (WANT).'),
         backgroundColor: Colors.red,
       ));
       return;
    }

    setState(() { isSaving = true; });

    await ApiService.updateFullName(userId: widget.userId, fullName: _nameController.text.trim());

    if (_imageFile != null && _base64Image != null) {
       await ApiService.updateProfilePhoto(userId: widget.userId, photoBase64: _base64Image!);
    }

    // NOTE: ApiService.updateBackgroundPhoto belum ada di api_service.dart kamu.
    // Tambahkan method ini di ApiService (mirip persis updateProfilePhoto, cuma beda
    // nama kolom di backend, misal 'background_photo'):
    //
    //   static Future<Map<String, dynamic>> updateBackgroundPhoto({
    //     required int userId,
    //     required String photoBase64,
    //   }) async {
    //     final response = await http.post(
    //       Uri.parse('$baseUrl/update_background.php'), // sesuaikan endpoint kamu
    //       body: {'user_id': userId.toString(), 'background_photo': photoBase64},
    //     );
    //     return jsonDecode(response.body);
    //   }
    //
    if (_backgroundImageFile != null && _base64Background != null) {
       await ApiService.updateBackgroundPhoto(userId: widget.userId, photoBase64: _base64Background!);
    }

    List<Map<String, String>> skillsPayload = [];
    for (var s in _selectedCanSkills) {
      skillsPayload.add({"skill_type": "CAN", "skill_name": s});
    }
    skillsPayload.add({"skill_type": "WANT", "skill_name": _selectedWantSkill});

    var result = await ApiService.saveUserSkills(
        userId: widget.userId,
        skills: skillsPayload,
    );

    if (!mounted) return;
    setState(() { isSaving = false; });

    if (result['status'] == 'success') {
       Navigator.pop(context, true);
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil diperbarui!')));
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.grey[900],
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!) as ImageProvider
                            : (_base64Image != null
                                ? MemoryImage(base64Decode(_base64Image!.split(',').last))
                                : null),
                        child: _imageFile == null && _base64Image == null
                            ? const Icon(Icons.person, size: 55, color: Colors.white)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('Full Name', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Masukkan nama lengkap',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blueAccent),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ===== Latar Belakang Profil (custom dari galeri) =====

              // ===== Latar Belakang Profil (custom dari galeri) =====
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('Latar Belakang Profil', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickBackgroundImage,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                    image: _backgroundImageFile != null
                        ? DecorationImage(image: FileImage(_backgroundImageFile!), fit: BoxFit.cover)
                        : (_base64Background != null
                            ? DecorationImage(image: MemoryImage(base64Decode(_base64Background!.split(',').last)), fit: BoxFit.cover)
                            : null),
                  ),
                  child: (_backgroundImageFile == null && _base64Background == null)
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image, color: Colors.white54, size: 32),
                              SizedBox(height: 8),
                              Text('Ketuk untuk pilih dari galeri', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Ganti', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('Skills I Have (Max 6)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSkills.map((skill) {
                  bool isSelected = _selectedCanSkills.contains(skill);
                  final iconData = skillIconData(skill);
                  return FilterChip(
                    avatar: Icon(iconData.icon, color: isSelected ? Colors.black : iconData.color, size: 16),
                    label: Text(skill),
                    selected: isSelected,
                    selectedColor: Colors.blueAccent,
                    checkmarkColor: Colors.black,
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          // Logika pembatasan maksimal 6 skill
                          if (_selectedCanSkills.length >= 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Maksimal hanya 6 skill yang bisa dipilih.'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              )
                            );
                          } else {
                            _selectedCanSkills.add(skill);
                          }
                        } else {
                          _selectedCanSkills.remove(skill);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.tealAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('Skill I Want (Hanya 1 Skill)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSkills.map((skill) {
                  bool isSelected = _selectedWantSkill == skill;
                  final iconData = skillIconData(skill);
                  return ChoiceChip(
                    avatar: Icon(iconData.icon, color: isSelected ? Colors.black : iconData.color, size: 16),
                    label: Text(skill),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2CB69D),
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.3)),
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedWantSkill = selected ? skill : '';
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSaving
                          ? [Colors.grey, Colors.grey]
                          : [Colors.blueAccent, Colors.tealAccent],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isSaving ? null : _saveProfile,
                      child: Center(
                        child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, color: Colors.black, size: 18),
                                  SizedBox(width: 8),
                                  Text('Simpan Perubahan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}