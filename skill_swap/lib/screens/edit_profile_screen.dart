import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

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
  bool isSaving = false;

  // Daftar 20+ Keahlian Digital yang Disediakan
  final List<String> _availableSkills = [
    'Flutter', 'Python', 'UI/UX Design', 'Figma', 'Frontend Web',
    'Backend Web', 'React Native', 'Node.js', 'Golang', 'Graphic Design',
    '3D Modeling', 'Video Editing', 'Digital Marketing', 'SEO Optimization',
    'Data Analysis', 'Machine Learning', 'Project Management', 'Copywriting',
    'Cloud Computing', 'Cybersecurity', 'QA Testing'
  ];

  List<String> _selectedCanSkills = [];
  String _selectedWantSkill = '';

  @override
  void initState() {
    super.initState();
    // Tarik data skill saat ini dari database
    List<dynamic> canList = widget.currentData['skills']['can'] ?? [];
    List<dynamic> wantList = widget.currentData['skills']['want'] ?? [];

    _selectedCanSkills = canList.map((e) => e.toString()).toList();
    _selectedWantSkill = wantList.isNotEmpty ? wantList.first.toString() : '';
    
    if (widget.currentData['profile_photo'] != null) {
      _base64Image = widget.currentData['profile_photo'];
    }
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

  void _saveProfile() async {
    if (_selectedWantSkill.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
         content: Text('Tolong pilih 1 skill yang ingin dipelajari (WANT).'),
         backgroundColor: Colors.red,
       ));
       return;
    }

    setState(() { isSaving = true; });

    // 1. Simpan Foto jika diubah
    if (_imageFile != null && _base64Image != null) {
       await ApiService.updateProfilePhoto(userId: widget.userId, photoBase64: _base64Image!);
    }

    // 2. Format Data Skill Sesuai API
    List<Map<String, String>> skillsPayload = [];
    
    for (var s in _selectedCanSkills) {
      skillsPayload.add({"skill_type": "CAN", "skill_name": s});
    }
    skillsPayload.add({"skill_type": "WANT", "skill_name": _selectedWantSkill});

    var result = await ApiService.saveUserSkills(userId: widget.userId, skills: skillsPayload);

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
        title: const Text('EDIT PROFILE', style: TextStyle(color: Colors.white, letterSpacing: 2)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar & Tombol Ubah Foto
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[900],
                      backgroundImage: _imageFile != null 
                          ? FileImage(_imageFile!) as ImageProvider
                          : (_base64Image != null 
                              ? MemoryImage(base64Decode(_base64Image!.split(',').last)) 
                              : null),
                      child: _imageFile == null && _base64Image == null
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.black, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            // Pilihan Skill CAN (Multiple Choice)
            const Text('SKILLS I HAVE (Bisa Pilih Banyak)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSkills.map((skill) {
                bool isSelected = _selectedCanSkills.contains(skill);
                return FilterChip(
                  label: Text(skill),
                  selected: isSelected,
                  selectedColor: Colors.white,
                  checkmarkColor: Colors.black,
                  backgroundColor: Colors.grey[900],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedCanSkills.add(skill);
                      } else {
                        _selectedCanSkills.remove(skill);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            
            // Pilihan Skill WANT (Single Choice)
            const Text('SKILL I WANT (HANYA 1 SKILL)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSkills.map((skill) {
                bool isSelected = _selectedWantSkill == skill;
                return ChoiceChip(
                  label: Text(skill),
                  selected: isSelected,
                  selectedColor: Colors.amber,
                  backgroundColor: Colors.grey[900],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      // Jika ditekan saat sudah terpilih, batalkan pilihan. Jika belum, set ke skill ini.
                      _selectedWantSkill = selected ? skill : '';
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            
            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text('SIMPAN PERUBAHAN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}