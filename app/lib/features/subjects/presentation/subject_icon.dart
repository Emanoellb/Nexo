import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Ícone Lucide e nome falado de cada um dos [subjectIcons] gravados.
const subjectIconData = <String, ({IconData icon, String label})>{
  'book-open': (icon: LucideIcons.bookOpen, label: 'Livro'),
  'calculator': (icon: LucideIcons.calculator, label: 'Calculadora'),
  'atom': (icon: LucideIcons.atom, label: 'Átomo'),
  'code': (icon: LucideIcons.code, label: 'Código'),
  'database': (icon: LucideIcons.database, label: 'Banco de dados'),
  'languages': (icon: LucideIcons.languages, label: 'Idiomas'),
  'scale': (icon: LucideIcons.scale, label: 'Balança'),
  'flask-conical': (icon: LucideIcons.flaskConical, label: 'Frasco'),
  'palette': (icon: LucideIcons.palette, label: 'Paleta'),
  'globe': (icon: LucideIcons.globe, label: 'Globo'),
  'landmark': (icon: LucideIcons.landmark, label: 'Prédio histórico'),
  'brain': (icon: LucideIcons.brain, label: 'Cérebro'),
};
