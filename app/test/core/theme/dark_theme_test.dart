import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/theme/theme_preference.dart';
import 'package:nexo/core/ui/ui.dart';

import '../../fakes/fakes.dart';

/// Modo escuro aprovado no Pen.dev em 04/11/2026
/// (pen.dev/notas/modo-escuro-especificacao.md).
void main() {
  group('NexoColors.dark', () {
    const d = NexoColors.dark;

    test('fundo Neutral/950 e Primary/300', () {
      expect(d.surface, const Color(0xFF14171B));
      expect(d.primary, const Color(0xFFB8CBDC));
      expect(d.secondary, const Color(0xFFC8BED9));
    });

    test('fora do M3: Lowest (elevado) é mais claro que o Surface', () {
      expect(d.surfaceContainerLowest, const Color(0xFF262A31));
      expect(
        d.surfaceContainerLowest.computeLuminance(),
        greaterThan(d.surface.computeLuminance()),
      );
      expect(d.surfaceContainerHigh, const Color(0xFF30353D));
    });

    test('Brand/Mark escuro é #6E92AE, diferente do Primary', () {
      expect(d.brandMark, const Color(0xFF6E92AE));
      expect(d.brandMark, isNot(d.primary));
      expect(NexoColors.light.brandMark, NexoColors.light.primary);
    });

    test('Unread: claro #F7F8F9, escuro #30353D (mais claro que o cartão)', () {
      expect(NexoColors.light.unread, const Color(0xFFF7F8F9));
      expect(d.unread, const Color(0xFF30353D));
      expect(
        d.unread.computeLuminance(),
        greaterThan(d.surfaceContainerLowest.computeLuminance()),
      );
    });

    test('vidro em repouso é mais opaco que sobre conteúdo', () {
      for (final c in [NexoColors.light, d]) {
        expect(c.glassRestFill.a, greaterThan(c.glassFill.a));
      }
    });

    test(
      'StepMarker/Border: some no claro; ≥ 3:1 sobre o cartão no escuro',
      () {
        double contrast(Color a, Color b) {
          final la = a.computeLuminance();
          final lb = b.computeLuminance();
          final (hi, lo) = la > lb ? (la, lb) : (lb, la);
          return (hi + 0.05) / (lo + 0.05);
        }

        expect(NexoColors.light.stepMarkerBorder, const Color(0xFFF4F5F7));
        expect(
          NexoColors.light.stepMarkerBorder,
          NexoColors.light.surfaceContainer,
        );
        expect(d.stepMarkerBorder, const Color(0xFF858B96));
        // Elemento não textual (WCAG 1.4.11): 3:1. O design mede 4,7:1.
        expect(contrast(d.stepMarkerBorder, d.cardDefault), greaterThan(4.5));
      },
    );
  });

  group('NexoTheme.dark', () {
    final theme = NexoTheme.dark();
    final scheme = theme.colorScheme;

    test('ColorScheme escuro definido à mão, com os papéis da lib', () {
      expect(theme.brightness, Brightness.dark);
      expect(scheme.brightness, Brightness.dark);
      expect(scheme.surface, NexoColors.dark.surface);
      expect(
        scheme.surfaceContainerLowest,
        NexoColors.dark.surfaceContainerLowest,
      );
      expect(scheme.primary, NexoColors.dark.primary);
      expect(theme.scaffoldBackgroundColor, NexoColors.dark.surface);
      expect(theme.extension<NexoColors>(), NexoColors.dark);
    });

    test('sombras iguais nos dois temas', () {
      expect(
        theme.extension<NexoElevation>(),
        NexoTheme.light().extension<NexoElevation>(),
      );
    });

    test('texto do tema em OnSurface escuro', () {
      expect(theme.textTheme.bodyMedium!.color, NexoColors.dark.onSurface);
    });

    test('Spacing/2XS (2) e Size/Target (48) nos dois temas', () {
      for (final t in [theme, NexoTheme.light()]) {
        expect(t.extension<NexoSpacing>()!.xxs, 2);
        expect(t.extension<NexoSizes>()!.target, 48);
      }
    });
  });

  group('preferência de tema (Sistema · Claro · Escuro)', () {
    ProviderContainer containerWith(InMemoryLocalFlags flags) {
      final container = ProviderContainer(
        overrides: [...fakeBackend(flags: flags)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('sem escolha, segue o sistema', () {
      final container = containerWith(InMemoryLocalFlags());
      expect(container.read(themePreferenceProvider), ThemeMode.system);
    });

    test('lê a escolha guardada; valor desconhecido volta ao sistema', () {
      expect(
        containerWith(InMemoryLocalFlags(themePreference: 'dark'))
            .read(themePreferenceProvider),
        ThemeMode.dark,
      );
      expect(
        containerWith(InMemoryLocalFlags(themePreference: 'roxo'))
            .read(themePreferenceProvider),
        ThemeMode.system,
      );
    });

    test('escolher troca o tema e grava no aparelho', () async {
      final flags = InMemoryLocalFlags();
      final container = containerWith(flags);
      await container
          .read(themePreferenceProvider.notifier)
          .set(ThemeMode.light);
      expect(container.read(themePreferenceProvider), ThemeMode.light);
      expect(flags.themePreference, 'light');
    });
  });

  group('componentes no tema escuro', () {
    Widget dark(Widget child) => MaterialApp(
      theme: NexoTheme.light(),
      darkTheme: NexoTheme.dark(),
      themeMode: ThemeMode.dark,
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('símbolo da marca usa Brand/Mark escuro', (tester) async {
      await tester.pumpWidget(dark(const NexoLogoSymbol(size: 48)));
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        picture.colorFilter,
        const ColorFilter.mode(Color(0xFF6E92AE), BlendMode.srcIn),
      );
    });
  });
}
