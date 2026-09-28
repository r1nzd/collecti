import 'package:flutter/material.dart';
import 'write/write_page.dart';
import 'present/present_page.dart';
import 'table/table_page.dart';
import 'clip/clip_page.dart';
import 'canvas/canvas_page.dart';
import 'design/design_page.dart';

enum CollectiModule {
  write('Write', 'awce', Icons.description_outlined, Icons.description),
  present('Present', 'apce', Icons.slideshow_outlined, Icons.slideshow),
  table('Table', 'atce', Icons.table_chart_outlined, Icons.table_chart),
  clip('Clip', 'arce', Icons.movie_outlined, Icons.movie),
  canvas('Canvas', 'acce', Icons.brush_outlined, Icons.brush),
  design('Design', 'adce', Icons.design_services_outlined, Icons.design_services);

  const CollectiModule(this.label, this.extension, this.icon, this.selectedIcon);
  final String label;
  final String extension;
  final IconData icon;
  final IconData selectedIcon;

  Widget get page => switch (this) {
        write => const WritePage(),
        present => const PresentPage(),
        table => const TablePage(),
        clip => const ClipPage(),
        canvas => const CanvasPage(),
        design => const DesignPage(),
      };
}
