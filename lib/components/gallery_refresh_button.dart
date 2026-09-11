import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../constants/theme.dart';

/// Botão flutuante que pede a versão mais nova do álbum de fotos sob
/// pedido — usado tanto em `/fotos` quanto em `/album`, sempre fixo no canto
/// da tela para o convidado buscar as fotos novas de onde estiver na
/// página, sem voltar até o topo do álbum.
class GalleryRefreshButton extends StatelessComponent {
  const GalleryRefreshButton({
    required this.onRefresh,
    required this.refreshing,
    required this.failed,
    super.key,
  });

  final VoidCallback onRefresh;
  final bool refreshing;
  final bool failed;

  @override
  Component build(BuildContext context) {
    return button(
      classes: [
        'gallery-refresh',
        if (refreshing) 'is-refreshing',
        if (failed) 'has-failed',
      ].join(' '),
      attributes: {
        'type': 'button',
        'aria-label': 'Atualizar o álbum de fotos',
        'title': failed
            ? 'Não deu para atualizar agora. Tente de novo.'
            : 'Ver as fotos que os outros convidados mandaram',
        if (refreshing) 'disabled': '',
      },
      onClick: onRefresh,
      [
        span(classes: 'gallery-refresh-icon', [.text('↻')]),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.gallery-refresh', [
      css('&').styles(
        position: .fixed(bottom: 24.px, right: 24.px),
        zIndex: ZIndex(20),
        display: .flex,
        alignItems: .center,
        justifyContent: .center,
        width: 48.px,
        height: 48.px,
        padding: .zero,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(24.px),
        backgroundColor: AppColors.bgElevated,
        color: AppColors.accentStrong,
        fontSize: 22.px,
        cursor: .pointer,
        shadow: BoxShadow(
          offsetX: .zero,
          offsetY: 4.px,
          blur: 16.px,
          color: AppColors.shadow,
        ),
        transition: Transition('transform', duration: 150.ms),
      ),
      css('&:hover').styles(transform: .scale(1.08)),
      css('&:disabled').styles(cursor: .progress),
      css('&.has-failed').styles(color: AppColors.textMuted),
      css('&.is-refreshing .gallery-refresh-icon').styles(
        animation: const Animation(
          name: 'gallery-refresh-spin',
          duration: Duration(milliseconds: 900),
          curve: .linear,
          count: 9999,
        ),
      ),
    ]),
    css('.gallery-refresh-icon').styles(display: .block),
    css.keyframes('gallery-refresh-spin', {
      'from': Styles(transform: .rotate(0.deg)),
      'to': Styles(transform: .rotate(360.deg)),
    }),
  ];
}
