import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../application/profile_actions.dart';

/// O que a pessoa escreveu no Feedback.
typedef FeedbackDraft = ({FeedbackKind kind, String message});

/// "Enviar feedback" (decisão do usuário, 19/11/2026): Bug ou Sugestão e a
/// mensagem. "Continuar no e-mail" devolve o rascunho; o Perfil abre o app
/// de e-mail com tudo preenchido (a pessoa revisa e envia). O Nexo não
/// guarda nada.
Future<FeedbackDraft?> showFeedbackSheet(BuildContext context) =>
    showNexoBottomSheet<FeedbackDraft>(
      context,
      title: 'Enviar feedback',
      builder: (_) => const _FeedbackForm(),
    );

class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm();

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  final _message = TextEditingController();
  var _kind = FeedbackKind.bug;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Escreva a mensagem.');
      return;
    }
    Navigator.of(context).pop<FeedbackDraft>((kind: _kind, message: text));
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NexoSegmented<FeedbackKind>(
            segments: const [
              (value: FeedbackKind.bug, label: 'Bug'),
              (value: FeedbackKind.suggestion, label: 'Sugestão'),
            ],
            selected: _kind,
            onChanged: (kind) => setState(() => _kind = kind),
          ),
          SizedBox(height: spacing.md),
          NexoTextField(
            label: 'Mensagem',
            controller: _message,
            hintText: _kind == FeedbackKind.bug
                ? 'O que aconteceu e o que você esperava.'
                : 'O que você gostaria de ver no Nexo.',
            helperText: 'Enviamos a versão do Nexo e a do Android.',
            errorText: _error,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [
              LengthLimitingTextInputFormatter(NexoSupport.feedbackMaxLength),
            ],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          SizedBox(height: spacing.lg),
          NexoButton.primary(
            label: 'Continuar no e-mail',
            expand: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
