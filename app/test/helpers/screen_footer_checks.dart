import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/ui/ui.dart';

/// Rodapé de tela cheia ([NexoScreenFooter]) com o botão [footerButton]
/// (visível na tela [page]):
/// 1. uma Snackbar aparece acima do rodapé, sem cobrir o botão;
/// 2. com o teclado aberto (300 dp), o botão continua inteiro e acima dele.
Future<void> expectFooterClearOfSnackbarAndKeyboard(
  WidgetTester tester, {
  required Finder page,
  required Finder footerButton,
}) async {
  expect(find.byType(NexoScreenFooter), findsOneWidget);
  showNexoSnackbar(tester.element(page), message: 'Aviso de teste.');
  await tester.pumpAndSettle();
  expect(
    tester.getRect(find.byType(SnackBar)).bottom,
    lessThanOrEqualTo(tester.getRect(footerButton).top),
  );
  ScaffoldMessenger.of(tester.element(page)).removeCurrentSnackBar();
  await tester.pumpAndSettle();

  final ratio = tester.view.devicePixelRatio;
  tester.view.viewInsets = FakeViewPadding(bottom: 300 * ratio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpAndSettle();
  final screen = tester.view.physicalSize.height / ratio;
  final button = tester.getRect(footerButton);
  expect(button.bottom, lessThanOrEqualTo(screen - 300));
  expect(button.top, greaterThan(0));
  tester.view.resetViewInsets();
  await tester.pumpAndSettle();
}
