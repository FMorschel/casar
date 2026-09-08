import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../constants/theme.dart';

/// Aviso passageiro fixo no rodapé da tela.
///
/// Usado sempre que a página está conversando com a planilha/Drive (Apps
/// Script) fora do aparelho do convidado, para ele não achar que travou.
/// Normalmente montado dentro de um [ToastStack], que cuida do
/// posicionamento — veja lá.
class Toast extends StatelessComponent {
  const Toast({
    required this.message,
    this.isError = false,
    this.showSpinner = false,
    super.key,
  });

  final String message;
  final bool isError;
  final bool showSpinner;

  @override
  Component build(BuildContext context) {
    return div(
      classes: isError ? 'app-toast is-error' : 'app-toast',
      attributes: const {'role': 'status', 'aria-live': 'polite'},
      [
        if (showSpinner) span(classes: 'app-toast-spinner', []),
        .text(message),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.app-toast', [
      css('&').styles(
        display: .flex,
        alignItems: .center,
        gap: .all(10.px),
        maxWidth: 320.px,
        padding: .symmetric(vertical: 12.px, horizontal: 16.px),
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
        backgroundColor: AppColors.bgElevated,
        color: AppColors.text,
        fontSize: 14.px,
        shadow: BoxShadow(
          offsetX: .zero,
          offsetY: 4.px,
          blur: 16.px,
          color: AppColors.shadow,
        ),
        animation: const Animation(
          name: 'app-toast-in',
          duration: Duration(milliseconds: 200),
          curve: .easeOut,
        ),
      ),
      css('&.is-error').styles(color: AppColors.accentStrong),
    ]),
    css('.app-toast-spinner').styles(
      display: .block,
      width: 14.px,
      height: 14.px,
      flex: Flex(grow: 0, shrink: 0, basis: 14.px),
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
        name: 'app-toast-spin',
        duration: Duration(milliseconds: 700),
        curve: .linear,
        count: 9999,
      ),
    ),
    css.keyframes('app-toast-in', {
      'from': Styles(opacity: 0, transform: .translate(y: 8.px)),
      'to': Styles(opacity: 1, transform: .translate(y: .zero)),
    }),
    css.keyframes('app-toast-spin', {
      'from': Styles(transform: .rotate(0.deg)),
      'to': Styles(transform: .rotate(360.deg)),
    }),
  ];
}

/// Empilha vários [Toast] no rodapé da tela — o mais novo ancorado no lugar
/// onde o único toast de antes ficava, e os anteriores empurrados para cima,
/// para um aviso passageiro não sumir por baixo de outro antes do convidado
/// conseguir ler os dois.
class ToastStack extends StatelessComponent {
  const ToastStack({required this.toasts, super.key});

  final List<Toast> toasts;

  @override
  Component build(BuildContext context) {
    return div(classes: 'app-toast-stack', toasts);
  }

  @css
  static List<StyleRule> get styles => [
    css('.app-toast-stack').styles(
      position: .fixed(bottom: 28.px, left: 24.px),
      zIndex: ZIndex(20),
      display: .flex,
      flexDirection: .columnReverse,
      alignItems: .start,
      gap: .all(10.px),
    ),
  ];
}
