import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../constants/photo_challenges.dart';
import '../constants/theme.dart';
import '../utils/guest_challenge_draw.dart';
import '../utils/guest_name.dart';
import '../utils/photo_challenges_api.dart';
import 'loading_indicator.dart';

/// Portão de identidade do convidado (FR-2, FR-3, FR-4).
///
/// Enquanto nenhum nome estiver salvo no navegador, mostra um formulário
/// pedindo o nome. Depois de salvo (ou se já existia), constrói [builder]
/// com o nome conhecido.
///
/// Não é `@client`: só é usado dentro da subárvore de um componente `@client`
/// já existente (ex.: a página de desafios de foto), então não precisa de
/// seu próprio ponto de hidratação — e pode receber um callback normal como
/// [builder], já que não cruza a fronteira servidor/cliente sozinho.
class GuestNameGate extends StatefulComponent {
  const GuestNameGate({required this.builder, super.key});

  final Component Function(BuildContext context, String guestName) builder;

  @override
  State<GuestNameGate> createState() => GuestNameGateState();
}

/// Em qual etapa da identificação o convidado está.
enum _GateStep {
  /// Digitando o nome.
  input,

  /// Consultando a planilha para ver se esse nome já sorteou desafios.
  checking,

  /// Nome já tem sorteio: perguntando se é a mesma pessoa.
  confirm,

  /// Convidado disse que não é a mesma pessoa do sorteio existente.
  rejected,
}

class GuestNameGateState extends State<GuestNameGate> {
  final _api = const PhotoChallengesApi();

  String? guestName;
  String nameInput = '';
  _GateStep _step = _GateStep.input;
  String? _pendingName;
  List<PhotoChallenge> _existingChallenges = const [];

  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    guestName = readGuestName();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Confirma [name] como o convidado atual: salva e libera o [builder].
  void _acceptName(String name) {
    writeGuestName(name);
    setState(() => guestName = name);
  }

  /// Checa na planilha se [normalized] já tem desafios sorteados (FR-8)
  /// antes de assumir esse nome — pode ser outra pessoa com o mesmo nome.
  Future<void> _submit() async {
    final normalized = normalizeGuestName(nameInput);
    if (!isGuestNameLongEnough(normalized)) return;

    setState(() => _step = _GateStep.checking);
    final existing = await _api.checkExisting(normalized);
    if (_disposed) return;

    if (existing == null || existing.isEmpty) {
      // Sem sorteio prévio (ou não deu pra checar): segue direto, para não
      // travar o convidado por causa de uma falha de rede.
      _acceptName(normalized);
      return;
    }

    setState(() {
      _pendingName = normalized;
      _existingChallenges = existing;
      _step = _GateStep.confirm;
    });
  }

  void _confirmSamePerson() {
    final name = _pendingName;
    if (name == null) return;
    // O sorteio já existia (é por isso que estamos aqui): marcar como
    // revelado neste navegador também, para a página de desafios não repetir
    // a animação de sorteio de um resultado que o convidado já viu antes.
    writeGuestChallengeDraw(
      name,
      _existingChallenges,
      const {},
      revealed: {for (final challenge in _existingChallenges) challenge.text},
    );
    _acceptName(name);
  }

  void _rejectSamePerson() {
    setState(() => _step = _GateStep.rejected);
  }

  void _tryAnotherName() {
    setState(() {
      _step = _GateStep.input;
      nameInput = '';
      _pendingName = null;
      _existingChallenges = const [];
    });
  }

  @override
  Component build(BuildContext context) {
    if (guestName case final name?) {
      return component.builder(context, name);
    }

    // No HTML gerado no build (fora da web, sempre sem nome — vem antes da
    // hidratação), não dá pra saber ainda se o convidado já tem nome salvo.
    // Mostrar o formulário nesse instante piscaria a pergunta do nome para
    // quem já respondeu antes; um loading neutro espera a hidratação decidir.
    if (!kIsWeb) {
      return const LoadingIndicator('Carregando…');
    }

    return div(classes: 'guest-name-gate', [
      switch (_step) {
        _GateStep.input => _buildInputCard(),
        _GateStep.checking => const LoadingIndicator('Verificando nome…'),
        _GateStep.confirm => _buildConfirmCard(),
        _GateStep.rejected => _buildRejectedCard(),
      },
    ]);
  }

  Component _buildInputCard() {
    return div(classes: 'guest-name-card', [
      h2([.text('Antes de começar…')]),
      p([
        .text(
          'Como você se chama? Vamos usar seu nome para marcar quem tirou '
          'cada foto no álbum.',
        ),
      ]),
      input<String>(
        type: InputType.text,
        value: nameInput,
        attributes: {'placeholder': 'Seu nome'},
        onInput: (value) => setState(() => nameInput = value),
        events: {
          'keydown': (event) {
            final key = (event as web.KeyboardEvent).key;
            if (key == 'Enter') _submit();
          },
        },
      ),
      button(
        onClick: _submit,
        attributes: {
          if (!isGuestNameLongEnough(normalizeGuestName(nameInput)))
            'disabled': '',
        },
        [.text('Continuar')],
      ),
    ]);
  }

  Component _buildConfirmCard() {
    return div(classes: 'guest-name-card', [
      h2([.text('É você mesmo?')]),
      p([
        .text(
          'Já tem um sorteio de desafios para "$_pendingName". Se foi você '
          'quem sorteou, os desafios eram estes:',
        ),
      ]),
      ul(classes: 'guest-name-existing-challenges', [
        for (final challenge in _existingChallenges)
          li([.text(challenge.text)]),
      ]),
      div(classes: 'guest-name-confirm-actions', [
        button(
          onClick: _confirmSamePerson,
          [.text('Sim, sou eu')],
        ),
        button(
          classes: 'guest-name-secondary',
          onClick: _rejectSamePerson,
          [.text('Não, sou outra pessoa')],
        ),
      ]),
    ]);
  }

  Component _buildRejectedCard() {
    return div(classes: 'guest-name-card', [
      h2([.text('Esse nome já foi usado')]),
      p([
        .text(
          'Tente um nome diferente (por exemplo, com o sobrenome) para não '
          'misturar seus desafios com os de quem já sorteou. Também avise '
          'os noivos sobre esse encontro de nomes.',
        ),
      ]),
      button(onClick: _tryAnotherName, [.text('Tentar outro nome')]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.guest-name-gate').styles(
      display: .flex,
      justifyContent: .center,
      alignItems: .center,
      minHeight: 60.vh,
      padding: .all(24.px),
    ),
    css('.guest-name-card', [
      css('&').styles(
        display: .flex,
        flexDirection: .column,
        gap: .all(16.px),
        maxWidth: 420.px,
        width: 100.percent,
        padding: .all(32.px),
        textAlign: .center,
        backgroundColor: AppColors.bgElevated,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.lg),
      ),
      css('h2').styles(color: AppColors.accentStrong),
      css('p').styles(color: AppColors.textMuted, margin: .zero),
      css('input').styles(
        padding: .symmetric(vertical: 10.px, horizontal: 16.px),
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
        backgroundColor: AppColors.bg,
        color: AppColors.text,
        fontFamily: AppFonts.body,
      ),
      css('button', [
        css('&').styles(
          padding: .symmetric(vertical: 10.px, horizontal: 20.px),
          border: .unset,
          radius: .circular(AppRadius.md),
          backgroundColor: AppColors.accent,
          color: Colors.white,
          fontWeight: .w600,
          cursor: .pointer,
        ),
        css('&:hover').styles(backgroundColor: AppColors.accentStrong),
        css('&:disabled').styles(
          backgroundColor: AppColors.border,
          color: AppColors.textMuted,
          cursor: .notAllowed,
        ),
        css('&.guest-name-secondary').styles(
          backgroundColor: Colors.transparent,
          color: AppColors.textMuted,
          border: .all(style: .solid, color: AppColors.border, width: 1.px),
        ),
        css('&.guest-name-secondary:hover').styles(
          backgroundColor: AppColors.bg,
          color: AppColors.text,
        ),
      ]),
      css('.guest-name-existing-challenges').styles(
        display: .flex,
        flexDirection: .column,
        gap: .all(6.px),
        margin: .zero,
        padding: .zero,
        listStyle: .none,
        textAlign: .left,
      ),
      css('.guest-name-existing-challenges li').styles(
        padding: .symmetric(vertical: 8.px, horizontal: 12.px),
        backgroundColor: AppColors.bg,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
        color: AppColors.text,
        fontSize: .875.rem,
      ),
      css('.guest-name-confirm-actions').styles(
        display: .flex,
        flexDirection: .column,
        gap: .all(10.px),
      ),
    ]),
  ];
}
