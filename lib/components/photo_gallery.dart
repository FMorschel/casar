import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../constants/photo_challenges.dart';
import '../constants/theme.dart';
import '../constants/wedding_data.dart';
import '../utils/text_formatting.dart';

/// Um retângulo na tela (`getBoundingClientRect`), só com o que a animação
/// de abrir/fechar o álbum precisa.
typedef _ScreenRect = ({double top, double left, double width, double height});

/// Etapas de abrir e fechar um card do álbum. São quatro (e não um simples
/// "aberto/fechado") porque o card só pode ser animado depois de montado e
/// medido: é a foto que decide o tamanho dele.
enum _ExpandPhase {
  /// Montado e invisível, só para ser medido.
  measuring,

  /// Encolhido em cima do card da grade, ainda sem transição.
  snapped,

  /// Solto no tamanho próprio — é aqui que a transição roda.
  grown,

  /// Voltando para o card da grade, sumindo junto.
  closing,
}

/// Galeria compartilhada das fotos confirmadas (FR-16, FR-17, FR-18, FR-19).
///
/// As fotos ficam borradas (só um teaser) até [photoRevealDate]; depois disso
/// aparecem nítidas. A checagem é só no cliente, com `DateTime.now()`.
///
/// Não é `@client`: só é montada dentro da subárvore de um componente
/// `@client` já existente ([PhotoChallengesFlow]), então pode ter estado
/// próprio (o card em tela cheia) sem precisar de tipos serializáveis.
class PhotoGallery extends StatefulComponent {
  const PhotoGallery({
    required this.photos,
    this.forceRevealed = false,
    super.key,
  });

  final List<GalleryPhoto> photos;

  /// Atalho de dev (`kDebugMode`) para ver o álbum revelado sem esperar
  /// [photoRevealDate] chegar de verdade.
  final bool forceRevealed;

  @override
  State<PhotoGallery> createState() => PhotoGalleryState();
}

class PhotoGalleryState extends State<PhotoGallery> {
  static const _transitionDuration = Duration(milliseconds: 300);
  static const _expandedId = 'photo-gallery-expanded';

  GalleryPhoto? _expandedPhoto;
  int? _expandedIndex;
  _ExpandPhase _phase = _ExpandPhase.measuring;

  /// Retângulo do card na grade: o "de onde" ele cresce e o "para onde" ele
  /// volta. Medido de novo ao fechar, porque a grade pode ter rolado ou
  /// mudado enquanto o card estava aberto.
  _ScreenRect? _cardRect;

  /// Retângulo do card já expandido, do jeito que o CSS o dimensiona (ele se
  /// ajusta à foto, não à tela). Só dá para saber medindo depois de montado,
  /// e é a partir dele que a conta do [_flipTransform] sai.
  _ScreenRect? _expandedRect;

  Timer? _phaseTimer;
  Timer? _closeTimer;

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _closeTimer?.cancel();
    super.dispose();
  }

  static String _cardId(int index) => 'photo-gallery-card-$index';

  _ScreenRect _toRect(web.DOMRect rect) =>
      (top: rect.top, left: rect.left, width: rect.width, height: rect.height);

  _ScreenRect? _rectOf(String id) {
    final element = web.document.getElementById(id);
    return element == null ? null : _toRect(element.getBoundingClientRect());
  }

  void _expand(GalleryPhoto photo, int index) {
    _phaseTimer?.cancel();
    _closeTimer?.cancel();
    setState(() {
      _expandedPhoto = photo;
      _expandedIndex = index;
      _cardRect = _rectOf(_cardId(index));
      _expandedRect = null;
      // O card nasce invisível só para ser medido: o tamanho dele depende da
      // foto, então nem o CSS nem esta classe sabem qual é antes de montar.
      _phase = _ExpandPhase.measuring;
    });
    _phaseTimer = Timer(Duration.zero, _snapOntoCard);
  }

  /// Com o card expandido já montado (e medido), encolhe ele por cima do card
  /// da grade, sem transição, e no tique seguinte solta para crescer.
  void _snapOntoCard() {
    _phaseTimer = null;
    if (!mounted) return;
    final expanded = _rectOf(_expandedId);
    setState(() {
      _expandedRect = expanded;
      // Sem uma das medidas não dá para animar: aparece já no lugar.
      _phase = expanded == null || _cardRect == null
          ? _ExpandPhase.grown
          : _ExpandPhase.snapped;
    });
    if (_phase != _ExpandPhase.snapped) return;
    _phaseTimer = Timer(Duration.zero, () {
      _phaseTimer = null;
      if (!mounted) return;
      setState(() => _phase = _ExpandPhase.grown);
    });
  }

  void _close() {
    if (_expandedPhoto == null || _phase == _ExpandPhase.closing) return;
    _phaseTimer?.cancel();
    final index = _expandedIndex;
    setState(() {
      if (index != null) _cardRect = _rectOf(_cardId(index)) ?? _cardRect;
      _phase = _ExpandPhase.closing;
    });
    _closeTimer = Timer(_transitionDuration, () {
      _closeTimer = null;
      if (!mounted) return;
      setState(() {
        _expandedPhoto = null;
        _expandedIndex = null;
        _cardRect = null;
        _expandedRect = null;
        _phase = _ExpandPhase.measuring;
      });
    });
  }

  /// Transforma a caixa [box] para parecer, visualmente, com [target] — mesma
  /// posição e mesmo tamanho, sem mexer no layout de verdade. Assume
  /// `transform-origin: 0 0` no elemento.
  String _flipTransform(_ScreenRect box, _ScreenRect target) {
    final scaleX = box.width == 0 ? 1.0 : target.width / box.width;
    final scaleY = box.height == 0 ? 1.0 : target.height / box.height;
    final dx = target.left - box.left;
    final dy = target.top - box.top;
    return 'translate(${dx}px, ${dy}px) scale($scaleX, $scaleY)';
  }

  @override
  Component build(BuildContext context) {
    final revealed =
        component.forceRevealed || DateTime.now().isAfter(photoRevealDate);
    final photos = [...component.photos]
      ..sort(
        (p1, p2) => p2.takenAt.compareTo(p1.takenAt),
      );

    return div(classes: 'photo-gallery', [
      h2(classes: 'section-title', [.text('Álbum dos Desafios')]),
      p(classes: 'photo-gallery-subtitle', [
        .text(
          revealed
              ? 'As fotos de todo mundo, sem segredo!'
              : 'Prévia borrada — as fotos ficam nítidas a partir do dia '
                    'seguinte ao casamento.',
        ),
      ]),
      if (photos.isEmpty)
        p(classes: 'photo-gallery-empty', [
          .text('Ainda não tem nenhuma foto no álbum. Seja o primeiro!'),
        ])
      else
        div(
          classes: 'photo-gallery-grid',
          [
            for (final (index, photo) in photos.indexed)
              _photoCard(photo, index, revealed: revealed),
          ],
        ),
      // Cópia do card tocado, por cima da grade e crescendo até o tamanho
      // que a foto pedir. É uma cópia (e não o card original crescendo) para
      // a grade atrás não se remontar sem o card que saiu dela.
      if (_expandedPhoto case final photo?) ...[
        div(
          classes: 'photo-gallery-backdrop',
          styles: _phaseStyles(fadesIn: true),
          events: events(onClick: _close),
          const [],
        ),
        _photoCard(
          photo,
          _expandedIndex ?? 0,
          revealed: revealed,
          expanded: true,
        ),
      ],
    ]);
  }

  /// Estilos que levam o card expandido (e o fundo escuro) de uma etapa de
  /// [_ExpandPhase] para a próxima. O `transform` é sempre escrito, mesmo
  /// quando é `none`: sem isso o navegador não vê a propriedade mudar entre
  /// uma renderização e a próxima, e a transição nunca dispara.
  Styles _phaseStyles({bool fadesIn = false}) {
    final ms = _transitionDuration.inMilliseconds;
    final box = _expandedRect;
    final card = _cardRect;
    final flip = box == null || card == null
        ? 'none'
        : _flipTransform(box, card);

    return switch (_phase) {
      _ExpandPhase.measuring => Styles(
        opacity: fadesIn ? 0 : null,
        raw: {
          'transform': 'none',
          'transition': 'none',
          if (!fadesIn) 'visibility': 'hidden',
        },
      ),
      _ExpandPhase.snapped => Styles(
        opacity: fadesIn ? 0 : null,
        raw: {'transform': flip, 'transition': 'none'},
      ),
      _ExpandPhase.grown => Styles(
        opacity: fadesIn ? 1 : null,
        raw: {
          'transform': 'none',
          'transition': 'transform ${ms}ms ease, opacity ${ms}ms ease',
        },
      ),
      _ExpandPhase.closing => Styles(
        opacity: 0,
        raw: {
          'transform': fadesIn ? 'none' : flip,
          'transition': 'transform ${ms}ms ease, opacity ${ms}ms ease',
        },
      ),
    };
  }

  /// Fonte da foto do card.
  ///
  /// Antes da revelação o card mostra a foto embaçada (`blur(14px)`), então
  /// não faz sentido baixar a versão de tela cheia: o borrão esconde a
  /// diferença e uma miniatura pequena deixa o álbum muito mais leve
  /// justamente na noite da festa, quando todo mundo abre a página junto.
  ///
  /// Só mexe no sufixo `=w<N>` do CDN do Google; a foto local do modo
  /// degradado (FR-15) é um `data:` e passa direto, sem alteração.
  String _imageSrc(GalleryPhoto photo, {required bool revealed}) {
    if (revealed) return photo.photoUrl;
    return photo.photoUrl.replaceFirst(RegExp(r'=w\d+$'), '=w80');
  }

  /// O card da foto: o mesmo componente na grade e aberto ([expanded]), para
  /// o que cresce ser o card inteiro — fundo, foto, desafio, autor e horário
  /// — e não só a foto.
  ///
  /// Aberto ele sai do fluxo da grade (`position: fixed`) e se dimensiona
  /// pela foto; a conta do [_flipTransform] o encolhe de volta, por um
  /// quadro, exatamente sobre o card original, e daí ele cresce.
  Component _photoCard(
    GalleryPhoto photo,
    int index, {
    required bool revealed,
    bool expanded = false,
  }) {
    return div(
      // Cada card tem o id da posição dele na grade; o aberto tem o seu, para
      // ser medido sem esbarrar no card de onde saiu.
      id: expanded ? _expandedId : _cardId(index),
      classes: expanded ? 'photo-gallery-card expanded' : 'photo-gallery-card',
      attributes: expanded
          ? const {'role': 'dialog', 'aria-modal': 'true'}
          : null,
      styles: expanded ? _phaseStyles() : null,
      events: events(
        onClick: expanded ? _close : () => _expand(photo, index),
      ),
      [
        img(
          src: _imageSrc(photo, revealed: revealed),
          alt: photo.challengeText,
          classes: revealed
              ? 'photo-gallery-image'
              : 'photo-gallery-image blurred',
          // O álbum inteiro carregaria de uma vez sem isso, e o CDN do Google
          // responde 429 quando um cliente pede fotos demais junto — com
          // `lazy` só as que estão perto da tela são buscadas.
          attributes: const {'loading': 'lazy', 'decoding': 'async'},
        ),
        p(classes: 'photo-gallery-challenge', [.text(photo.challengeText)]),
        p(classes: 'photo-gallery-author', [
          .text('tirada por ${photo.authorName}'),
        ]),
        p(classes: 'photo-gallery-taken-at', [
          .text(formatPhotoTakenAt(photo.takenAt)),
        ]),
        if (expanded)
          button(
            classes: 'photo-gallery-card-close',
            attributes: const {
              'type': 'button',
              'aria-label': 'Fechar foto',
            },
            onClick: _close,
            [.text('×')],
          ),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.photo-gallery', [
      // A largura precisa vir do pai: sem ela o álbum é dimensionado pela
      // grade (várias colunas de 200px), estoura a tela do celular e leva os
      // cards e a legenda para fora dela.
      css('&').styles(
        display: .flex,
        flexDirection: .column,
        alignItems: .center,
        gap: .all(16.px),
        width: 100.percent,
      ),
      css('.section-title').styles(
        textAlign: .center,
        fontSize: 2.rem,
        color: AppColors.accentStrong,
      ),
      css('.photo-gallery-subtitle').styles(
        textAlign: .center,
        color: AppColors.textMuted,
        maxWidth: 480.px,
      ),
      css('.photo-gallery-empty').styles(color: AppColors.textMuted),
      css('.photo-gallery-grid').styles(
        display: .grid,
        gap: .all(20.px),
        width: 100.percent,
        maxWidth: 1000.px,
        raw: {
          // `min(200px, 100%)`: numa tela mais estreita que uma coluna, a
          // coluna encolhe junto em vez de a grade transbordar.
          'grid-template-columns':
              'repeat(auto-fill, minmax(min(200px, 100%), 1fr))',
        },
      ),
      css('.photo-gallery-card', [
        css('&').styles(
          display: .flex,
          flexDirection: .column,
          gap: .all(8.px),
          padding: .all(12.px),
          backgroundColor: AppColors.bgElevated,
          border: .all(style: .solid, color: AppColors.border, width: 1.px),
          radius: .circular(AppRadius.md),
          cursor: .pointer,
        ),
        // Aberto é o card inteiro que cresce — o mesmo fundo, foto e textos
        // da grade, só que grandes. Ele se ajusta à foto (`fit-content`), e
        // não à janela: a foto cresce até esbarrar na altura ou na largura
        // disponível, e o card para junto com ela, sem sobra de fundo dos
        // lados. `inset: 0` + `margin: auto` centraliza sem `transform` — o
        // `transform` é da animação (ver `_flipTransform`), que também conta
        // com o `transform-origin` no canto superior esquerdo.
        css('&.expanded').styles(
          position: .fixed(
            top: .zero,
            left: .zero,
            right: .zero,
            bottom: .zero,
          ),
          zIndex: ZIndex(50),
          alignItems: .center,
          gap: .all(12.px),
          padding: .all(16.px),
          overflow: .hidden,
          raw: {
            'margin': 'auto',
            'width': 'fit-content',
            'height': 'fit-content',
            'max-width': '100vw',
            'max-height': '100vh',
            // Piso de largura: uma foto que não carregou não tem tamanho
            // nenhum, e sem isso o card viraria uma tira de poucos pixels.
            'min-width': 'min(280px, 100vw)',
            'transform-origin': '0 0',
          },
        ),
        // A foto cresce no tamanho natural dela até bater no limite da tela
        // (descontando o espaço dos textos embaixo), sem cortar nada.
        css('&.expanded .photo-gallery-image').styles(
          raw: {
            'width': 'auto',
            'height': 'auto',
            'max-width': 'calc(100vw - 32px)',
            'max-height': 'calc(100vh - 160px)',
            'object-fit': 'contain',
            'flex': '0 0 auto',
          },
        ),
        // `width: 0` + `min-width: 100%`: os textos acompanham a largura que
        // a foto definiu em vez de puxarem o card para os lados.
        css('&.expanded .photo-gallery-challenge').styles(
          fontSize: 1.rem,
          raw: {'width': '0', 'min-width': '100%'},
        ),
        css('&.expanded .photo-gallery-author').styles(
          fontSize: .875.rem,
          raw: {'width': '0', 'min-width': '100%'},
        ),
        css('&.expanded .photo-gallery-taken-at').styles(
          fontSize: .8125.rem,
          raw: {'width': '0', 'min-width': '100%'},
        ),
      ]),
      css('.photo-gallery-image', [
        css('&').styles(
          width: 100.percent,
          height: 180.px,
          radius: .circular(8.px),
          raw: {'object-fit': 'cover', 'transition': 'filter 300ms ease'},
        ),
        // Teaser: só embaçado o suficiente para reconhecer que tem gente.
        css('&.blurred').styles(raw: {'filter': 'blur(14px)'}),
      ]),
      css('.photo-gallery-challenge').styles(
        fontSize: 13.px,
        fontWeight: .w600,
        color: AppColors.text,
        margin: .zero,
      ),
      css('.photo-gallery-author').styles(
        fontSize: 12.px,
        color: AppColors.textMuted,
        fontStyle: .italic,
        margin: .zero,
      ),
      css('.photo-gallery-taken-at').styles(
        fontSize: 11.px,
        color: AppColors.textMuted,
        margin: .zero,
      ),
    ]),
    // O card aberto não cobre a tela toda, então o fundo escura o resto da
    // página — e fechar clicando fora dele.
    css('.photo-gallery-backdrop').styles(
      position: .fixed(top: .zero, left: .zero, right: .zero, bottom: .zero),
      zIndex: ZIndex(49),
      backgroundColor: const Color.rgba(0, 0, 0, 0.7),
      cursor: .pointer,
    ),
    css('.photo-gallery-card-close', [
      css('&').styles(
        position: Position.absolute(top: 16.px, right: 16.px),
        width: 36.px,
        height: 36.px,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(50.percent),
        backgroundColor: AppColors.bg,
        color: AppColors.text,
        fontSize: 20.px,
        lineHeight: Unit.expression('1'),
        cursor: .pointer,
        shadow: BoxShadow(
          offsetX: .zero,
          offsetY: 2.px,
          blur: 10.px,
          color: AppColors.shadow,
        ),
      ),
      css('&:hover').styles(color: AppColors.accentStrong),
    ]),
  ];
}
