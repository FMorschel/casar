import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../constants/theme.dart';

/// Indicador de carregamento genérico: um spinner girando ao lado de uma
/// mensagem, para estados de espera que devem parecer "carregando" em vez
/// de texto parado ou de uma tela errada piscando antes da hidratação.
class LoadingIndicator extends StatelessComponent {
  const LoadingIndicator(this.message, {super.key});

  final String message;

  @override
  Component build(BuildContext context) {
    return div(classes: 'loading-indicator', [
      span(classes: 'loading-indicator-spinner', []),
      .text(message),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.loading-indicator').styles(
      display: .flex,
      alignItems: .center,
      justifyContent: .center,
      gap: .all(10.px),
      color: AppColors.textMuted,
      padding: .all(32.px),
    ),
    css('.loading-indicator-spinner').styles(
      display: .block,
      width: 16.px,
      height: 16.px,
      flex: Flex(grow: 0, shrink: 0, basis: 16.px),
      // Anel cinza com um lado colorido: girando, vira o spinner.
      border: .only(
        top: BorderSide(
          style: .solid,
          color: AppColors.accentStrong,
          width: 2.px,
        ),
        right: BorderSide(style: .solid, color: AppColors.border, width: 2.px),
        bottom: BorderSide(
          style: .solid,
          color: AppColors.border,
          width: 2.px,
        ),
        left: BorderSide(style: .solid, color: AppColors.border, width: 2.px),
      ),
      radius: .circular(50.percent),
      animation: const Animation(
        name: 'loading-indicator-spin',
        duration: Duration(milliseconds: 700),
        curve: .linear,
        count: 9999,
      ),
    ),
    css.keyframes('loading-indicator-spin', {
      'from': Styles(transform: .rotate(0.deg)),
      'to': Styles(transform: .rotate(360.deg)),
    }),
  ];
}
