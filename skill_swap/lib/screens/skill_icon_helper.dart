import 'package:flutter/material.dart';

/// Simple data holder for a skill's icon + accent color.
class SkillIconData {
  final IconData icon;
  final Color color;
  const SkillIconData(this.icon, this.color);
}

/// Maps a skill name (as used in `_availableSkills`) to an icon + color
/// so skill chips can show a small colored icon instead of plain text.
/// Add new cases here whenever a new skill is added to the available list.
SkillIconData skillIconData(String skill) {
  switch (skill) {
    case 'Flutter':
      return const SkillIconData(Icons.flutter_dash, Colors.lightBlueAccent);
    case 'Python':
      return const SkillIconData(Icons.code, Colors.yellowAccent);
    case 'UI/UX Design':
      return const SkillIconData(Icons.brush, Colors.pinkAccent);
    case 'Figma':
      return const SkillIconData(Icons.design_services, Colors.deepPurpleAccent);
    case 'Frontend Web':
      return const SkillIconData(Icons.code, Colors.cyanAccent);
    case 'Backend Web':
      return const SkillIconData(Icons.dns, Colors.greenAccent);
    case 'React Native':
      return const SkillIconData(Icons.phone_android, Colors.lightBlueAccent);
    case 'Node.js':
      return const SkillIconData(Icons.hub, Colors.lightGreenAccent);
    case 'Golang':
      return const SkillIconData(Icons.bolt, Colors.cyanAccent);
    case 'Graphic Design':
      return const SkillIconData(Icons.palette, Colors.orangeAccent);
    case '3D Modeling':
      return const SkillIconData(Icons.view_in_ar, Colors.deepPurpleAccent);
    case 'Video Editing':
      return const SkillIconData(Icons.movie, Colors.redAccent);
    case 'Digital Marketing':
      return const SkillIconData(Icons.campaign, Colors.orangeAccent);
    case 'SEO Optimization':
      return const SkillIconData(Icons.search, Colors.greenAccent);
    case 'Data Analysis':
      return const SkillIconData(Icons.bar_chart, Colors.purpleAccent);
    case 'Machine Learning':
      return const SkillIconData(Icons.psychology, Colors.tealAccent);
    case 'Project Management':
      return const SkillIconData(Icons.assignment, Colors.indigoAccent);
    case 'Copywriting':
      return const SkillIconData(Icons.edit_note, Colors.amberAccent);
    case 'Cloud Computing':
      return const SkillIconData(Icons.cloud, Colors.blueAccent);
    case 'Cybersecurity':
      return const SkillIconData(Icons.security, Colors.redAccent);
    case 'QA Testing':
      return const SkillIconData(Icons.bug_report, Colors.greenAccent);
    default:
      return const SkillIconData(Icons.star, Colors.white70);
  }
}