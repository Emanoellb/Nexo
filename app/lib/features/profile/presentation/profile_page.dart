import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../app/shell/nexo_shell.dart';
import '../../../core/data/device_actions.dart';
import '../../../core/data/local_flags.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/theme/theme_preference.dart';
import '../../../core/ui/ui.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/domain/auth_user.dart';
import '../../focus/application/focus_system.dart';
import '../../progress/application/achievements_providers.dart';
import '../../progress/domain/level.dart';
import '../application/profile_actions.dart';
import 'about_sheet.dart';
import 'achievement_sheet.dart';

/// O Aviso da manhã fica escondido até o agendamento existir (decisão do
/// usuário, 10/11/2026: nada que não funcione no fim da 3c; o agendamento é
/// da Etapa 5). A preferência `users.morningSummary` continua no modelo.
const morningSummaryVisible = false;

/// "5 tarefas" / "1 tarefa".
String _tasksText(int n) => n == 1 ? '1 tarefa' : '$n tarefas';

/// Perfil (aprovado em 07/11/2026, `pen.dev/notas/perfil-especificacao.md`,
/// topo opção B): abre pelo avatar do topo das abas (eixo X), sem barra de
/// abas. Blocos: Topo · Progresso · Medalhas (3 × 3) · Preferências ·
/// Suporte · Conta · versão. As preferências têm efeito na hora.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  ProfileActions get _actions => ref.read(profileActionsProvider);

  Future<void> _pickMorningTime(MorningSummary summary) async {
    final parts = summary.time.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
      helpText: 'Horário do aviso da manhã',
    );
    if (picked == null || !mounted) return;
    final time =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    await _actions.setMorningSummary(summary.copyWith(time: time));
  }

  /// "Ligar o Não perturbe ao focar": ligar pede o acesso do sistema, se
  /// ainda não foi dado (uma vez só).
  Future<void> _setDndOnFocus(bool on) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final flags = ref.read(localFlagsProvider);
    if (on) {
      final system = ref.read(focusSystemProvider);
      if (!await system.dndAccessGranted() && !await system.openDndSettings()) {
        return;
      }
      await flags.setDndAllowed(uid);
    }
    await flags.setDndOnFocus(uid, on);
    if (mounted) setState(() {});
  }

  Future<void> _contact({required bool email}) async {
    final device = ref.read(deviceActionsProvider);
    final opened = email
        ? await device.openEmail(
            NexoSupport.email,
            subject: NexoSupport.supportSubject,
          )
        : await device.openDialer(NexoSupport.phoneDial);
    if (opened || !mounted) return;
    showNexoSnackbar(
      context,
      message: email
          ? 'Nenhum app de e-mail encontrado. Escreva para '
                '${NexoSupport.email}.'
          : 'Nenhum discador encontrado neste aparelho.',
      tone: NexoSnackbarTone.info,
    );
  }

  /// "Pedir cópia dos dados": abre o app de e-mail com a mensagem pronta. O
  /// Nexo não envia nada sozinho nem guarda o pedido.
  Future<void> _requestDataCopy() async {
    final opened = await ref
        .read(deviceActionsProvider)
        .openEmail(
          NexoSupport.email,
          subject: NexoSupport.dataCopySubject,
          body: NexoSupport.dataCopyBody,
        );
    if (opened || !mounted) return;
    showNexoSnackbar(
      context,
      message:
          'Nenhum app de e-mail encontrado. Escreva para ${NexoSupport.email} '
          'com o assunto “${NexoSupport.dataCopySubject}”.',
      tone: NexoSnackbarTone.info,
    );
  }

  /// Alterar senha enviando agora (a linha fica desativada).
  bool _sendingReset = false;

  /// "Alterar senha": o mesmo e-mail do "Esqueci a senha", direto, sem tela
  /// nem confirmação (a senha só muda se a pessoa abrir o link).
  Future<void> _sendPasswordReset(String email) async {
    setState(() => _sendingReset = true);
    String message;
    var tone = NexoSnackbarTone.info;
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      message = 'Enviamos um link para $email.';
      tone = NexoSnackbarTone.success;
    } on AuthFailure catch (failure) {
      message = switch (failure.code) {
        AuthFailureCode.network =>
          'Sem conexão com a internet. Verifique e tente de novo.',
        AuthFailureCode.tooManyRequests =>
          'Muitas tentativas. Tente de novo mais tarde.',
        _ => 'Não conseguimos enviar o link agora. Tente de novo.',
      };
    }
    if (!mounted) return;
    setState(() => _sendingReset = false);
    showNexoSnackbar(context, message: message, tone: tone);
  }

  /// "Sobre o Nexo": o painel com o nome, a versão e "Oferecido por"; dali,
  /// as licenças.
  void _openAbout(String? version) =>
      showAboutNexoSheet(context, version: version);

  Future<void> _signOut() async {
    final confirmed = await showNexoDialog(
      context,
      icon: LucideIcons.logOut,
      title: 'Sair da conta?',
      message:
          'Seus dados ficam salvos na sua conta. Para voltar, é só entrar '
          'de novo.',
      confirmLabel: 'Sair',
    );
    if (confirmed) await _actions.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final profile = ref.watch(userProfileProvider).value;
    final user = ref.watch(authStateProvider).value;
    final email = user?.email ?? '';
    final signedInWithGoogle = user?.signedInWithGoogle ?? false;
    final medals = ref.watch(achievementsViewProvider);
    final uid = ref.watch(currentUidProvider);
    final flags = ref.watch(localFlagsProvider);
    final system = ref.watch(focusSystemProvider);
    final version = ref.watch(appVersionProvider).value;

    final bar = NexoTopAppBar(title: 'Perfil', onBack: () => context.pop());
    if (profile == null) {
      return Scaffold(appBar: bar, body: const SizedBox.expand());
    }

    Widget section(String title, {String? trailing}) => Padding(
      padding: EdgeInsets.only(top: spacing.xl, bottom: spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: textTheme.titleMedium!.copyWith(color: c.onSurface),
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: textTheme.labelSmall!.copyWith(color: c.onSurfaceVariant),
            ),
        ],
      ),
    );
    Widget divider() => Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.md),
      child: Divider(height: 1, thickness: 1, color: c.outlineVariant),
    );
    Widget note(String text) => Padding(
      padding: EdgeInsets.only(top: spacing.sm),
      child: Text(
        text,
        style: textTheme.labelSmall!.copyWith(color: c.onSurfaceVariant),
      ),
    );

    final points = profile.points;
    final earned = medals?.where((m) => m.earned).length ?? 0;
    final summary = profile.morningSummary;
    final dndOnFocus = uid != null && flags.dndOnFocus(uid);

    return Scaffold(
      appBar: bar,
      // Uma página só, de tamanho modesto: tudo montado (o leitor de tela e
      // a rolagem até um bloco funcionam sem construir sob demanda).
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.sm,
          spacing.lg,
          MediaQuery.paddingOf(context).bottom + spacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Topo (opção B): a linha inteira abre "Editar perfil".
            NexoCard(
              onTap: () => context.push(AppRoutes.editProfile),
              child: Semantics(
                button: true,
                label: '${profile.displayName}, $email. Editar perfil',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.primaryContainer,
                      ),
                      child: Text(
                        initialsOf(profile.displayName),
                        style: textTheme.titleMedium!.copyWith(
                          color: c.onPrimaryContainer,
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            style: textTheme.titleMedium!.copyWith(
                              color: c.onSurface,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: textTheme.bodySmall!.copyWith(
                                color: c.onSurfaceVariant,
                              ),
                            ),
                          SizedBox(height: spacing.xs),
                          Text(
                            'Editar perfil',
                            style: context
                                .textStyle(NexoTextStyles.labelMediumEmphasis)
                                .copyWith(color: c.primary),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 20,
                      color: c.iconSecondary,
                    ),
                  ],
                ),
              ),
            ),

            section('Progresso'),
            NexoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NexoLevelProgress(
                    level: NexoLevel.levelFor(points),
                    pointsIntoLevel: NexoLevel.pointsIntoLevel(points),
                    pointsPerLevel: NexoLevel.pointsPerLevel,
                  ),
                  note(
                    'Tarefa concluída: 1 ponto · dia cumprido: 3 a 7 pontos.',
                  ),
                ],
              ),
            ),

            section('Medalhas', trailing: '$earned de ${medals?.length ?? 9}'),
            NexoCard(
              child: medals == null
                  ? const SizedBox(height: 96)
                  : Column(
                      children: [
                        for (var row = 0; row < medals.length; row += 3)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final m in medals.skip(row).take(3))
                                Expanded(
                                  child: NexoAchievement(
                                    key: ValueKey(m.def.id),
                                    title: m.def.title,
                                    icon: m.def.icon,
                                    earned: m.earned,
                                    onTap: () =>
                                        showAchievementSheet(context, m),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
            ),

            section('Preferências'),
            NexoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tema',
                    style: textTheme.bodyLarge!.copyWith(color: c.onSurface),
                  ),
                  SizedBox(height: spacing.sm),
                  NexoSegmented<ThemeMode>(
                    segments: const [
                      (value: ThemeMode.system, label: 'Sistema'),
                      (value: ThemeMode.light, label: 'Claro'),
                      (value: ThemeMode.dark, label: 'Escuro'),
                    ],
                    selected: ref.watch(themePreferenceProvider),
                    onChanged: (mode) =>
                        ref.read(themePreferenceProvider.notifier).set(mode),
                  ),
                  if (morningSummaryVisible) divider(),
                  if (morningSummaryVisible)
                    NexoSwitch(
                      label: 'Aviso da manhã',
                      helper: summary.enabled
                          ? 'Todo dia às ${summary.time}, com os planos e tarefas '
                                'do dia.'
                          : 'Desligado.',
                      value: summary.enabled,
                      onChanged: (on) => _actions.setMorningSummary(
                        summary.copyWith(enabled: on),
                      ),
                    ),
                  if (morningSummaryVisible && summary.enabled) ...[
                    SizedBox(height: spacing.md),
                    NexoSelectField(
                      label: 'Horário',
                      trailingIcon: LucideIcons.clock3,
                      value: summary.time,
                      placeholder: '08:00',
                      onTap: (_) => _pickMorningTime(summary),
                    ),
                  ],
                  if (system.supportsDnd) ...[
                    divider(),
                    NexoSwitch(
                      label: 'Ligar o Não perturbe ao focar',
                      helper: 'Silencia o celular em toda sessão de foco.',
                      value: dndOnFocus,
                      onChanged: _setDndOnFocus,
                    ),
                  ],
                  divider(),
                  NexoSwitch(
                    label: 'Reduzir transparência',
                    helper:
                        'Deixa a barra de abas sólida, sem efeito de vidro.',
                    value: ref.watch(reduceTransparencyProvider),
                    onChanged: (on) =>
                        ref.read(reduceTransparencyProvider.notifier).set(on),
                  ),
                  divider(),
                  // O rótulo visível fica fora do NexoStepper (o dele é só
                  // para o leitor de tela), como no "Tema".
                  ExcludeSemantics(
                    child: Text(
                      'Limite de tarefas por dia',
                      style: textTheme.bodyLarge!.copyWith(color: c.onSurface),
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  NexoStepper(
                    label: 'Limite de tarefas por dia',
                    valueText: _tasksText(profile.overloadThreshold),
                    helper:
                        'Acima disso, a Agenda avisa que o dia está carregado. '
                        'De 1 a 20.',
                    decrementTooltip: 'Diminuir o limite',
                    incrementTooltip: 'Aumentar o limite',
                    onDecrement:
                        profile.overloadThreshold >
                            UserProfile.minOverloadThreshold
                        ? () => _actions.setOverloadThreshold(
                            profile.overloadThreshold - 1,
                          )
                        : null,
                    onIncrement:
                        profile.overloadThreshold <
                            UserProfile.maxOverloadThreshold
                        ? () => _actions.setOverloadThreshold(
                            profile.overloadThreshold + 1,
                          )
                        : null,
                  ),
                ],
              ),
            ),

            section('Suporte'),
            NexoCardList(
              children: [
                NexoListItem(
                  icon: LucideIcons.mail,
                  title: 'E-mail',
                  supporting: NexoSupport.email,
                  trailing: Icon(
                    LucideIcons.externalLink,
                    size: 20,
                    color: c.iconSecondary,
                  ),
                  onTap: () => _contact(email: true),
                ),
                if (NexoSupport.phoneVisible)
                  NexoListItem(
                    icon: LucideIcons.phone,
                    title: 'Telefone',
                    supporting: NexoSupport.phoneText,
                    trailing: Icon(
                      LucideIcons.externalLink,
                      size: 20,
                      color: c.iconSecondary,
                    ),
                    onTap: () => _contact(email: false),
                  ),
              ],
            ),
            note(
              'Dúvidas, problemas ou correção de dados (como a data de '
              'nascimento).',
            ),

            section('Conta'),
            NexoCardList(
              children: [
                // Termos e Política abrem dentro do app: chevron.
                NexoListItem(
                  icon: LucideIcons.fileText,
                  title: 'Termos de uso',
                  onTap: () => context.push(AppRoutes.terms),
                ),
                NexoListItem(
                  icon: LucideIcons.shield,
                  title: 'Política de privacidade',
                  onTap: () => context.push(AppRoutes.privacy),
                ),
                NexoListItem(
                  icon: LucideIcons.download,
                  title: 'Pedir cópia dos dados',
                  supporting: 'Pelo e-mail. Respondemos em até 15 dias.',
                  semanticsLabel:
                      'Pedir cópia dos dados, pelo e-mail, abre o app de '
                      'e-mail',
                  trailing: Icon(
                    LucideIcons.externalLink,
                    size: 20,
                    color: c.iconSecondary,
                  ),
                  onTap: _requestDataCopy,
                ),
                // Só para contas de e-mail e senha (a do Google é do Google).
                if (!signedInWithGoogle && email.isNotEmpty)
                  NexoListItem(
                    icon: LucideIcons.keyRound,
                    title: 'Alterar senha',
                    supporting: 'Enviamos um link para o seu e-mail.',
                    semanticsLabel:
                        'Alterar senha, envia um link para o seu e-mail',
                    showChevron: false,
                    onTap: _sendingReset
                        ? null
                        : () => _sendPasswordReset(email),
                  ),
                NexoListItem(
                  icon: LucideIcons.logOut,
                  title: 'Sair',
                  showChevron: false,
                  onTap: _signOut,
                ),
                NexoListItem(
                  icon: LucideIcons.trash2,
                  title: 'Excluir conta',
                  destructive: true,
                  onTap: () => context.push(AppRoutes.deleteAccount),
                ),
              ],
            ),
            // "Sobre o Nexo · versão X" abre o painel Sobre o Nexo.
            Padding(
              padding: EdgeInsets.only(top: spacing.lg),
              child: Center(
                child: Semantics(
                  button: true,
                  label: version == null
                      ? 'Sobre o Nexo'
                      : 'Sobre o Nexo, versão $version',
                  excludeSemantics: true,
                  onTap: () => _openAbout(version),
                  child: NexoTappable(
                    onTap: () => _openAbout(version),
                    borderRadius: BorderRadius.circular(context.shape.sm),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: context.sizes.target,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: spacing.md),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            version == null
                                ? 'Sobre o Nexo'
                                : 'Sobre o Nexo · versão $version',
                            textAlign: TextAlign.center,
                            style: textTheme.labelSmall!.copyWith(
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
