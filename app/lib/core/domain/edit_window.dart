import 'local_date.dart';

/// Janela para criar, editar ou finalizar sessões e dias (RF11, RF14):
/// de hoje até 7 dias para trás. Datas futuras ficam fora.
///
/// As regras do Firestore aceitam até 9 dias (folga de fuso); o app aplica 7.
const int editWindowDays = 7;

bool isWithinEditWindow(LocalDate day, {required LocalDate today}) {
  final age = day.daysUntil(today);
  return age >= 0 && age <= editWindowDays;
}
