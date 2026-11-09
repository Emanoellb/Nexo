import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import 'nexo_card.dart';

/// `Content/List` em cartão (Card/Default, Shape/LG, borda) com divisores
/// (OutlineVariant, recuo LG), como os blocos do Início e as seções de
/// Tarefas.
///
/// Saída e volta de item (transições §8.1, aprovadas em 08/11/2026): um
/// filho **com chave** que some da lista fecha a altura e esmaece nos
/// primeiros 60% (Short · Exit), com os de baixo subindo; um que aparece
/// (ex.: "Desfazer") abre na mesma posição e esmaece nos últimos 60%
/// (Medium · Enter). Vários de uma vez saem juntos. Com "reduzir
/// movimento", na hora. Filhos sem chave (vazio, "Adicionar …") são
/// tratados pela posição e não animam.
class NexoCardList extends StatefulWidget {
  const NexoCardList({super.key, required this.children});

  final List<Widget> children;

  @override
  State<NexoCardList> createState() => _NexoCardListState();
}

class _Entry {
  _Entry(this.key, this.child, {required this.keyed});

  final Key key;

  /// O filho tinha chave própria (só esses animam).
  final bool keyed;
  Widget child;

  /// `null`: parado e presente.
  AnimationController? controller;
  bool exiting = false;
}

class _NexoCardListState extends State<NexoCardList>
    with TickerProviderStateMixin {
  late List<_Entry> _entries = [
    for (final (i, child) in widget.children.indexed) _entryFor(child, i),
  ];

  static _Entry _entryFor(Widget child, int index) => _Entry(
    child.key ?? ValueKey<Object>(('nexo-card-list', index)),
    child,
    keyed: child.key != null,
  );

  AnimationController _controller({required double value}) {
    final motion = context.motion;
    return AnimationController(
      vsync: this,
      duration: motion.medium,
      reverseDuration: motion.short,
      value: value,
    );
  }

  @override
  void didUpdateWidget(NexoCardList old) {
    super.didUpdateWidget(old);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final next = [
      for (final (i, child) in widget.children.indexed) _entryFor(child, i),
    ];
    final nextKeys = {for (final e in next) e.key};
    final current = {
      for (final e in _entries)
        if (!e.exiting) e.key: e,
    };

    // Os que ficam (com o filho novo) ou entram, na ordem nova.
    final merged = <_Entry>[];
    for (final fresh in next) {
      final staying = current[fresh.key];
      if (staying != null) {
        staying.child = fresh.child;
        merged.add(staying);
        continue;
      }
      if (fresh.keyed && !reduce) {
        final controller = _controller(value: 0);
        fresh.controller = controller;
        controller.forward().whenCompleteOrCancel(() => _settle(fresh));
      }
      merged.add(fresh);
    }

    // Os que saíram ficam no lugar deles até fechar, logo depois do vizinho
    // de cima que continua na lista.
    for (final (i, gone) in _entries.indexed) {
      final leaving = gone.exiting || !nextKeys.contains(gone.key);
      if (!leaving) continue;
      if (!gone.exiting) {
        if (!gone.keyed || reduce) {
          gone.controller?.dispose();
          continue;
        }
        gone.exiting = true;
        final controller = gone.controller ??= _controller(value: 1);
        controller.reverse().whenCompleteOrCancel(() {
          if (!mounted) return;
          setState(() => _entries.remove(gone));
          controller.dispose();
        });
      }
      _insertAfterPrevious(merged, gone, i);
    }
    _entries = merged;
  }

  void _insertAfterPrevious(List<_Entry> merged, _Entry gone, int oldIndex) {
    for (var j = oldIndex - 1; j >= 0; j--) {
      final at = merged.indexOf(_entries[j]);
      if (at >= 0) {
        merged.insert(at + 1, gone);
        return;
      }
    }
    merged.insert(0, gone);
  }

  void _settle(_Entry entry) {
    if (!mounted || entry.exiting) return;
    setState(() {
      entry.controller?.dispose();
      entry.controller = null;
    });
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final motion = context.motion;
    return NexoCard(
      padding: EdgeInsets.zero,
      radius: context.shape.lg,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, entry) in _entries.indexed)
            KeyedSubtree(
              key: entry.key,
              child: _animated(
                entry,
                motion,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (i > 0)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spacing.lg,
                        ),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: c.outlineVariant,
                        ),
                      ),
                    entry.child,
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A mesma árvore com ou sem animação (trocar o pai recriaria o estado do
  /// item).
  Widget _animated(_Entry entry, NexoMotion motion, Widget child) {
    final Animation<double> presence =
        entry.controller ?? kAlwaysCompleteAnimation;
    final size = CurvedAnimation(
      parent: presence,
      curve: motion.enter,
      reverseCurve: motion.exit.flipped,
    );
    // Esmaece nos 60% em que a altura está maior: entra no fim, sai no
    // começo.
    final opacity = CurvedAnimation(
      parent: presence,
      curve: const Interval(0.4, 1),
    );
    return IgnorePointer(
      ignoring: entry.exiting,
      child: ExcludeSemantics(
        excluding: entry.exiting,
        child: SizeTransition(
          sizeFactor: size,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: opacity, child: child),
        ),
      ),
    );
  }
}
