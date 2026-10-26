// Imagens de referência dos componentes base (fase 3), um arquivo por grupo.
// Gerar ou atualizar: flutter test --update-goldens test/goldens
// As imagens foram geradas no Windows; em outro sistema a fonte pode variar
// alguns pixels.
@Tags(['golden'])
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';

import '../helpers/nexo_test_app.dart';

const _sheetKey = ValueKey('sheet');
const _pressedKey = ValueKey('pressed');

/// Folha com uma linha por estado: rótulo pequeno + componente.
Widget _sheet(List<(String, Widget)> rows) {
  return Builder(
    builder: (context) {
      final c = context.nexoColors;
      return RepaintBoundary(
        key: _sheetKey,
        child: ColoredBox(
          color: c.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (label, child) in rows) ...[
                  Text(
                    label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall!
                        .copyWith(color: c.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Align(alignment: Alignment.centerLeft, child: child),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _pumpSheet(
  WidgetTester tester,
  List<(String, Widget)> rows, {
  double height = 900,
  bool hasSvg = false,
}) async {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NexoTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(
          disableAnimations: true,
          size: Size(390, 900),
        ),
        child: Scaffold(body: SingleChildScrollView(child: _sheet(rows))),
      ),
    ),
  );
  // Os SVG (logo e "G") carregam de forma assíncrona e precisam de tempo
  // real. Só nas folhas com SVG: depois do runAsync, as animações do
  // ambiente de teste (ex.: borda de foco do TextField) param de avançar.
  if (hasSvg) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  }
  await tester.pumpAndSettle();
}

/// Mantém o dedo pressionado sobre o widget marcado com [_pressedKey].
Future<TestGesture> _press(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(_pressedKey)),
    kind: PointerDeviceKind.touch,
  );
  // O toque só é reconhecido depois de kPressTimeout (100 ms) e o destaque
  // ainda tem um fade de entrada. Espera os dois antes da captura.
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump(const Duration(milliseconds: 400));
  return gesture;
}

void main() {
  setUpAll(loadNexoFonts);
  setUp(() {
    useKeyboardFocusHighlight();
    // Cursor sem piscar: deixa a imagem estável e o pumpAndSettle terminar.
    EditableText.debugDeterministicCursor = true;
  });
  tearDown(() => EditableText.debugDeterministicCursor = false);
  tearDown(resetFocusHighlight);

  void noop() {}

  Future<void> buttonVariant(
    WidgetTester tester,
    String name,
    Widget Function({
      Key? key,
      VoidCallback? onPressed,
      bool loading,
      FocusNode? focusNode,
    })
    build,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pumpSheet(
      tester,
      [
        ('Default', build(onPressed: noop)),
        ('Pressed', build(key: _pressedKey, onPressed: noop)),
        ('Focused', build(onPressed: noop, focusNode: focus)),
        ('Disabled', build(onPressed: null)),
        ('Loading', build(onPressed: noop, loading: true)),
      ],
      height: 480,
      hasSvg: name == 'google',
    );
    focus.requestFocus();
    // Espera a transição da borda de foco terminar (cursor fixo no setUp).
    await tester.pumpAndSettle();
    final gesture = await _press(tester);
    await expectLater(
      find.byKey(_sheetKey),
      matchesGoldenFile('goldens/button_$name.png'),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('botão primary', (tester) async {
    await buttonVariant(
      tester,
      'primary',
      ({key, onPressed, loading = false, focusNode}) => NexoButton.primary(
        key: key,
        label: 'Salvar',
        leadingIcon: LucideIcons.plus,
        onPressed: onPressed,
        loading: loading,
        focusNode: focusNode,
      ),
    );
  });

  testWidgets('botão secondary', (tester) async {
    await buttonVariant(
      tester,
      'secondary',
      ({key, onPressed, loading = false, focusNode}) => NexoButton.secondary(
        key: key,
        label: 'Cancelar',
        onPressed: onPressed,
        loading: loading,
        focusNode: focusNode,
      ),
    );
  });

  testWidgets('botão tertiary', (tester) async {
    await buttonVariant(
      tester,
      'tertiary',
      ({key, onPressed, loading = false, focusNode}) => NexoButton.tertiary(
        key: key,
        label: 'Ver todas',
        onPressed: onPressed,
        loading: loading,
        focusNode: focusNode,
      ),
    );
  });

  testWidgets('botão Google', (tester) async {
    await buttonVariant(
      tester,
      'google',
      ({key, onPressed, loading = false, focusNode}) => NexoGoogleButton(
        key: key,
        onPressed: onPressed,
        loading: loading,
        focusNode: focusNode,
      ),
    );
  });

  testWidgets('campos de texto', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pumpSheet(tester, [
      (
        'Default',
        const NexoTextField(label: 'E-mail', hintText: 'voce@email.com'),
      ),
      (
        'Focused',
        NexoTextField(
          label: 'E-mail',
          hintText: 'voce@email.com',
          focusNode: focus,
        ),
      ),
      (
        'Filled',
        NexoTextField(
          label: 'Como quer ser chamado',
          controller: TextEditingController(text: 'Ana'),
        ),
      ),
      (
        'Senha com regra',
        NexoTextField(
          label: 'Senha',
          obscurable: true,
          controller: TextEditingController(text: 'Senha#2026'),
          helperText:
              'Mínimo de 8 caracteres, com letra maiúscula, letra minúscula, '
              'número e caractere especial.',
        ),
      ),
      (
        'Error',
        const NexoTextField(label: 'Senha', errorText: 'Crie uma senha.'),
      ),
      (
        'Disabled',
        const NexoTextField(
          label: 'E-mail',
          hintText: 'voce@email.com',
          enabled: false,
        ),
      ),
      (
        'ReadOnly',
        NexoTextField(
          label: 'E-mail',
          readOnly: true,
          controller: TextEditingController(text: 'ana.souza@email.com'),
        ),
      ),
    ], height: 820);
    focus.requestFocus();
    // Espera a transição da borda de foco terminar (cursor fixo no setUp).
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(_sheetKey),
      matchesGoldenFile('goldens/text_fields.png'),
    );
  });

  testWidgets('checkbox', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pumpSheet(tester, [
      (
        'Unchecked',
        NexoCheckbox(value: false, labelText: 'Lembretes', onChanged: (_) {}),
      ),
      (
        'Checked',
        NexoCheckbox(value: true, labelText: 'Lembretes', onChanged: (_) {}),
      ),
      (
        'Indeterminate',
        NexoCheckbox(value: null, labelText: 'Lembretes', onChanged: (_) {}),
      ),
      (
        'Com apoio',
        NexoCheckbox(
          value: false,
          labelText: 'Lembretes',
          helperText: 'Receber aviso antes do prazo.',
          onChanged: (_) {},
        ),
      ),
      (
        'Disabled',
        const NexoCheckbox(
          value: false,
          labelText: 'Lembretes',
          onChanged: null,
        ),
      ),
      (
        'Focused',
        NexoCheckbox(
          value: false,
          labelText: 'Lembretes',
          onChanged: (_) {},
          focusNode: focus,
        ),
      ),
    ], height: 560);
    focus.requestFocus();
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(_sheetKey),
      matchesGoldenFile('goldens/checkbox.png'),
    );
  });

  testWidgets('navegação e marca', (tester) async {
    await _pumpSheet(
      tester,
      [
        (
          'TopAppBar',
          SizedBox(
            width: 358,
            height: 56,
            child: NexoTopAppBar(title: 'Criar conta', onBack: noop),
          ),
        ),
        ('PageControl 3 · passo 1', const NexoPageControl(count: 3, index: 0)),
        ('PageControl 5 · passo 3', const NexoPageControl(count: 5, index: 2)),
        ('Logo · símbolo 48', const NexoLogoSymbol(size: 48)),
      ],
      height: 420,
      hasSvg: true,
    );
    await expectLater(
      find.byKey(_sheetKey),
      matchesGoldenFile('goldens/navigation_brand.png'),
    );
  });

  testWidgets('feedback', (tester) async {
    await _pumpSheet(tester, [
      (
        'Snackbar · sucesso + ação',
        NexoSnackbar(
          message: 'Tarefa concluída',
          tone: NexoSnackbarTone.success,
          actionLabel: 'Desfazer',
          onAction: noop,
        ),
      ),
      (
        'Snackbar · aviso + fechar',
        NexoSnackbar(
          message: 'E-mail reenviado',
          tone: NexoSnackbarTone.info,
          onClose: noop,
        ),
      ),
      (
        'Alert · info',
        const NexoAlert(
          tone: NexoAlertTone.info,
          title: 'Sincronização pausada',
          message: 'Suas alterações ficam salvas no aparelho.',
        ),
      ),
      (
        'Alert · sucesso',
        const NexoAlert(tone: NexoAlertTone.success, message: 'Conta criada.'),
      ),
      (
        'Alert · aviso + ação',
        NexoAlert(
          tone: NexoAlertTone.warning,
          title: 'Muitas tentativas',
          message: 'Aguarde alguns minutos e tente de novo.',
          actionLabel: 'Esqueci minha senha',
          onAction: noop,
        ),
      ),
      (
        'Alert · erro',
        const NexoAlert(
          tone: NexoAlertTone.error,
          title: 'Sem conexão',
          message: 'Confira sua internet e tente de novo.',
        ),
      ),
    ], height: 900);
    await expectLater(
      find.byKey(_sheetKey),
      matchesGoldenFile('goldens/feedback.png'),
    );
  });
}
