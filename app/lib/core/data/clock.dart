import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Relógio do app. Os testes trocam por um horário fixo.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
