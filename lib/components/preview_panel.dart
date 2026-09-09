import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../constants/theme.dart';

/// Painel flutuante com os atalhos de teste do `/fotos`: trocar de nome,
/// apagar o sorteio e revelar o álbum antes da data.
///
/// Fica fixo na tela, fora do fluxo da página, de propósito — os atalhos
/// precisam estar ao alcance em qualquer etapa, inclusive enquanto o portão
/// do nome ou a animação de sorteio ocupam a tela inteira, que é justamente
/// quando dava vontade de apagar o nome e não tinha por onde.
///
/// Não é `@client`: mora dentro da subárvore já hidratada da página de
/// desafios, então pode receber callbacks normais.
class PreviewPanel extends StatefulComponent {
  const PreviewPanel({
    required this.guestName,
    required this.albumRevealed,
    required this.onChangeName,
    required this.onForgetGuest,
    required this.onToggleAlbum,
    this.onExit,
    super.key,
  });

  /// Nome salvo neste navegador, ou `null` enquanto o convidado ainda não
  /// se identificou.
  final String? guestName;

  /// Se o álbum está aparecendo sem o borrão de antes de `photoRevealDate`.
  final bool albumRevealed;

  /// Esquece só o nome: o sorteio continua guardado, então voltar a digitar
  /// o mesmo nome traz tudo de volta.
  final VoidCallback onChangeName;

  /// Esquece o nome *e* o sorteio deste navegador — recomeço do zero.
  final VoidCallback onForgetGuest;

  final VoidCallback onToggleAlbum;

  /// Desliga o modo prévia. `null` quando o painel veio do `kDebugMode`, em
  /// que não há modo prévia para desligar.
  final VoidCallback? onExit;

  @override
  State<PreviewPanel> createState() => PreviewPanelState();
}

class PreviewPanelState extends State<PreviewPanel> {
  /// Começa fechado: é um painel de teste, não pode tapar a página que está
  /// sendo testada.
  bool _open = false;

  @override
  Component build(BuildContext context) {
    final guestName = component.guestName;

    return div(classes: 'preview-panel', [
      button(
        classes: _open
            ? 'preview-panel-toggle is-open'
            : 'preview-panel-toggle',
        attributes: {
          'type': 'button',
          'aria-expanded': '$_open',
          'aria-label': _open
              ? 'Fechar o painel de prévia'
              : 'Abrir o painel de prévia',
          'title': 'Painel de prévia',
        },
        onClick: () => setState(() => _open = !_open),
        [.text('🛠')],
      ),
      if (_open)
        div(classes: 'preview-panel-card', [
          p(classes: 'preview-panel-title', [.text('Modo prévia')]),
          p(classes: 'preview-panel-name', [
            .text(
              guestName == null
                  ? 'Nenhum nome salvo neste navegador.'
                  : 'Você está como "$guestName".',
            ),
          ]),
          if (guestName != null) ...[
            button(
              classes: 'preview-panel-action',
              attributes: const {'type': 'button'},
              onClick: component.onChangeName,
              [.text('Trocar de nome')],
            ),
            button(
              classes: 'preview-panel-action danger',
              attributes: const {'type': 'button'},
              onClick: component.onForgetGuest,
              [.text('Apagar nome e sorteio')],
            ),
          ],
          button(
            classes: 'preview-panel-action',
            attributes: const {'type': 'button'},
            onClick: component.onToggleAlbum,
            [
              .text(
                component.albumRevealed
                    ? 'Borrar o álbum de novo'
                    : 'Revelar o álbum agora',
              ),
            ],
          ),
          if (component.onExit case final onExit?)
            button(
              classes: 'preview-panel-action',
              attributes: const {'type': 'button'},
              onClick: onExit,
              [.text('Sair do modo prévia')],
            ),
        ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.preview-panel', [
      // Acima do conteúdo e do cabeçalho fixo, mas abaixo da foto aberta em
      // tela cheia da galeria (z-index 49/50) — que é o que se quer olhar
      // quando ela está aberta.
      css('&').styles(
        position: .fixed(top: 12.px, left: 16.px),
        zIndex: ZIndex(30),
        display: .flex,
        flexDirection: .column,
        alignItems: .start,
        gap: .all(8.px),
      ),
      css('.preview-panel-toggle', [
        css('&').styles(
          display: .flex,
          alignItems: .center,
          justifyContent: .center,
          width: 40.px,
          height: 40.px,
          padding: .zero,
          border: .all(style: .dashed, color: AppColors.textMuted, width: 1.px),
          radius: .circular(20.px),
          backgroundColor: AppColors.bgElevated,
          color: AppColors.text,
          fontSize: 18.px,
          cursor: .pointer,
          opacity: 0.65,
          shadow: BoxShadow(
            offsetX: .zero,
            offsetY: 2.px,
            blur: 8.px,
            color: AppColors.shadow,
          ),
          transition: Transition('opacity', duration: 150.ms),
        ),
        css('&:hover').styles(opacity: 1),
        css('&.is-open').styles(opacity: 1),
      ]),
      css('.preview-panel-card', [
        css('&').styles(
          display: .flex,
          flexDirection: .column,
          gap: .all(8.px),
          width: 260.px,
          maxWidth: Unit.expression('calc(100vw - 32px)'),
          padding: .all(16.px),
          backgroundColor: AppColors.bgElevated,
          border: .all(style: .solid, color: AppColors.border, width: 1.px),
          radius: .circular(AppRadius.md),
          shadow: BoxShadow(
            offsetX: .zero,
            offsetY: 4.px,
            blur: 16.px,
            color: AppColors.shadow,
          ),
        ),
        css('.preview-panel-title').styles(
          margin: .zero,
          color: AppColors.accentStrong,
          fontWeight: .w700,
          fontSize: .875.rem,
        ),
        css('.preview-panel-name').styles(
          margin: .zero,
          color: AppColors.textMuted,
          fontSize: .8125.rem,
        ),
        css('.preview-panel-action', [
          css('&').styles(
            padding: .symmetric(vertical: 8.px, horizontal: 12.px),
            border: .all(style: .solid, color: AppColors.border, width: 1.px),
            radius: .circular(AppRadius.md),
            backgroundColor: AppColors.bg,
            color: AppColors.text,
            fontFamily: AppFonts.body,
            fontSize: .8125.rem,
            textAlign: .start,
            cursor: .pointer,
          ),
          css('&:hover').styles(
            backgroundColor: AppColors.bgSoft,
            color: AppColors.accentStrong,
          ),
          css('&.danger').styles(color: AppColors.textMuted),
          css('&.danger:hover').styles(color: AppColors.accentStrong),
        ]),
      ]),
    ]),
  ];
}
