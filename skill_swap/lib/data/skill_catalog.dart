// Daftar induk (master list) semua skill yang tersedia di aplikasi.
// Dipakai bersama oleh EditProfileScreen (pilihan skill "Can/Want") dan
// ExploreScreen (kartu kategori), supaya keduanya selalu sinkron —
// skill baru cukup ditambahkan di SATU tempat ini saja.
class SkillCatalog {
  static const List<String> all = [
    'Flutter', 'Python', 'UI/UX Design', 'Figma', 'Frontend Web',
    'Backend Web', 'React Native', 'Node.js', 'Golang', 'Graphic Design',
    '3D Modeling', 'Video Editing', 'Digital Marketing', 'SEO Optimization',
    'Data Analysis', 'Machine Learning', 'Project Management', 'Copywriting',
    'Cloud Computing', 'Cybersecurity', 'QA Testing'
  ];

  // Ubah nama skill menjadi nama file aset yang konsisten,
  // contoh: 'UI/UX Design' -> 'ui_ux_design', 'Node.js' -> 'node_js'.
  // Simpan logo tiap skill di assets/images/<hasil_slug>.png
  static String slug(String skillName) {
    return skillName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}