import 'package:flutter/material.dart';

const Map<String, IconData> kClassIcons = {
  // Icons used in Home UI
  'devices': Icons.devices,
  'table_chart': Icons.table_chart_outlined,
  'memory': Icons.memory,
  // Common class/subject icons
  'menu_book': Icons.menu_book_outlined,
  'science': Icons.science_outlined,
  'code': Icons.code,
  'calculate': Icons.calculate_outlined,
  'history_edu': Icons.history_edu,
  'language': Icons.language,
  'palette': Icons.palette_outlined,
  'music_note': Icons.music_note_outlined,
};

const String kDefaultClassIcon = 'menu_book';

IconData classIconFor(String? iconName) {
  if (iconName == null) return kClassIcons[kDefaultClassIcon]!;
  return kClassIcons[iconName] ?? kClassIcons[kDefaultClassIcon]!;
}
