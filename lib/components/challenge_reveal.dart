import 'dart:async';
import 'dart:math';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../constants/photo_challenges.dart';
import '../constants/theme.dart';

/// Animação de "sorteio" dos 3 desafios (FR-10).
///
/// Os desafios reais em [challenges] já estão definidos antes da animação
/// começar — os slots são revelados um de cada vez, de cima pra baixo: o
/// slot atual fica trocando por textos aleatórios da lista completa por
/// alguns instantes, dando a impressão de estar sorteando, até "cair" no
/// texto verdadeiro; então há uma pausa antes do próximo slot começar. Ao
/// terminar o último, chama [onFinished].
///
/// Não é `@client`: só é montado dentro da subárvore de um componente
/// `@client` já existente, então pode receber [challenges] e [onFinished]
/// como estão, sem precisar de tipos serializáveis.
class ChallengeReveal extends StatefulComponent {
  const ChallengeReveal({
    required this.challenges,
    required this.onFinished,
    super.key,
  });

  final List<PhotoChallenge> challenges;
  final VoidCallback onFinished;

  @override
  State<ChallengeReveal> createState() => ChallengeRevealState();
}

class ChallengeRevealState extends State<ChallengeReveal> {
  static const _shuffleDuration = Duration(seconds: 2);
  static const _tickInterval = Duration(milliseconds: 80);
  static const _pauseDuration = Duration(seconds: 2);
  static const _fadeOutDuration = Duration(milliseconds: 300);

  final _random = Random();
  late List<String> _displayedTexts;
  late List<bool> _settled;
  int _currentIndex = 0;
  bool _fadingOut = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _displayedTexts = List.filled(component.challenges.length, '');
    _settled = List.filled(component.challenges.length, false);
    _startShuffle(_currentIndex);
  }

  void _startShuffle(int index) {
    final stopwatch = Stopwatch()..start();

    _ticker = Timer.periodic(_tickInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (stopwatch.elapsed >= _shuffleDuration) {
        timer.cancel();
        setState(() {
          _settled[index] = true;
          _displayedTexts[index] = component.challenges[index].text;
        });
        _afterSettle(index);
        return;
      }
      setState(() {
        _displayedTexts[index] =
            allPhotoChallenges[_random.nextInt(allPhotoChallenges.length)].text;
      });
    });
  }

  void _afterSettle(int index) {
    final nextIndex = index + 1;
    _ticker = Timer(_pauseDuration, () {
      if (!mounted) return;
      if (nextIndex >= component.challenges.length) {
        _fadeOutAndFinish();
        return;
      }
      _currentIndex = nextIndex;
      _startShuffle(nextIndex);
    });
  }

  /// Some com a tela suavemente antes de chamar [ChallengeReveal.onFinished]
  /// — evita o corte seco pra próxima parte do fluxo.
  void _fadeOutAndFinish() {
    setState(() => _fadingOut = true);
    _ticker = Timer(_fadeOutDuration, () {
      if (!mounted) return;
      component.onFinished();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return div(
      classes: _fadingOut ? 'challenge-reveal fading-out' : 'challenge-reveal',
      [
        h2(classes: 'section-title', [.text('Sorteando seus desafios…')]),
        div(classes: 'challenge-slots', [
          for (var i = 0; i < _displayedTexts.length; i++)
            div(
              classes: _settled[i]
                  ? 'challenge-slot settled'
                  : 'challenge-slot',
              [.text(i <= _currentIndex ? _displayedTexts[i] : '')],
            ),
        ]),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.challenge-reveal', [
      css('&').styles(
        display: .flex,
        flexDirection: .column,
        alignItems: .center,
        gap: .all(24.px),
        padding: .all(24.px),
        textAlign: .center,
        opacity: 1,
        transform: .translate(y: .zero),
        transition: Transition.combine([
          Transition('opacity', duration: _fadeOutDuration),
          Transition('transform', duration: _fadeOutDuration),
        ]),
      ),
      css('&.fading-out').styles(
        opacity: 0,
        transform: .translate(y: (-8).px),
      ),
    ]),
    css('.challenge-slots').styles(
      display: .flex,
      flexDirection: .column,
      gap: .all(12.px),
      width: 100.percent,
      maxWidth: 480.px,
    ),
    css('.challenge-slot', [
      css('&').styles(
        padding: .symmetric(vertical: 16.px, horizontal: 20.px),
        backgroundColor: AppColors.bgElevated,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
        color: AppColors.textMuted,
      ),
      css('&.settled').styles(
        color: AppColors.accentStrong,
        border: .all(
          style: .solid,
          color: AppColors.accentStrong,
          width: 1.px,
        ),
      ),
    ]),
  ];
}
