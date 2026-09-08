import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../constants/theme.dart';
import '../constants/wedding_data.dart';
import '../utils/gift_ideas_api.dart';
import '../utils/pix.dart';
import 'pix_qr.dart';
import 'toast.dart';

/// Cache local da lista compartilhada, para o grid não aparecer vazio
/// enquanto a planilha não responde (ou quando o convidado está sem internet).
const _storageKey = 'casar-custom-gift-ideas';

@client
class GiftList extends StatefulComponent {
  const GiftList({super.key});

  @override
  State<GiftList> createState() => GiftListState();
}

class GiftListState extends State<GiftList> {
  List<GiftItem> customIdeas = [];
  String nameInput = '';
  String priceInput = '';
  String authorInput = '';
  String emojiInput = giftEmojiOptions.first;

  /// Cards virados para o lado do Pix, identificados por [_giftId].
  final Set<String> flippedGifts = {};

  /// Card cujo código acabou de ser copiado (para trocar o texto do botão).
  String? copiedGift;

  final GiftIdeasApi _api = const GiftIdeasApi();

  /// Enquanto a ideia está a caminho da planilha o botão fica travado, para
  /// não mandar a mesma sugestão duas vezes.
  bool sending = false;

  /// Mensagem de "não deu certo" do último envio, se houver.
  String? sendError;

  /// Atualização manual da lista em andamento (botão flutuante).
  bool refreshing = false;

  /// A última atualização manual não chegou até a planilha.
  bool refreshFailed = false;

  /// Aviso passageiro no rodapé da tela. `null` quando não há nada a dizer.
  String? toastMessage;

  /// O aviso atual é de erro (muda a cor).
  bool toastIsError = false;

  Timer? _toastTimer;

  /// `true` depois que o componente sai da tela: nenhum `setState` de resposta
  /// atrasada da planilha pode rodar a partir daí.
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final stored = web.window.localStorage.getItem(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        customIdeas = stored.split('\n').map(_parseIdea).toList();
      }
      _loadIdeas();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _toastTimer?.cancel();
    super.dispose();
  }

  /// Mostra um aviso no rodapé. Sem [autoDismiss] ele fica até ser trocado —
  /// é o caso do "buscando…", que só sai quando a busca termina.
  void _showToast(
    String message, {
    bool isError = false,
    Duration? autoDismiss,
  }) {
    _toastTimer?.cancel();
    setState(() {
      toastMessage = message;
      toastIsError = isError;
    });
    if (autoDismiss == null) return;
    _toastTimer = Timer(autoDismiss, () {
      if (_disposed) return;
      setState(() => toastMessage = null);
    });
  }

  /// Busca as ideias que os outros convidados já mandaram. Se a planilha não
  /// responder, o cache local continua valendo — ninguém vê a lista vazia.
  Future<bool> _loadIdeas() async {
    final ideas = await _api.fetchIdeas();
    if (ideas == null || _disposed) return false;
    setState(() => customIdeas = ideas);
    _cacheIdeas();
    return true;
  }

  /// Atualização pedida pelo convidado no botão flutuante.
  Future<void> _refresh() async {
    if (refreshing) return;
    setState(() {
      refreshing = true;
      refreshFailed = false;
    });
    _showToast('Buscando as ideias mais novas…');
    final loaded = await _loadIdeas();
    if (_disposed) return;
    setState(() {
      refreshing = false;
      refreshFailed = !loaded;
    });
    _showToast(
      loaded
          ? 'Lista de ideias atualizada!'
          : 'Não deu para atualizar agora. Tente de novo em instantes.',
      isError: !loaded,
      autoDismiss: Duration(seconds: loaded ? 3 : 5),
    );
  }

  void _cacheIdeas() {
    if (!kIsWeb) return;
    web.window.localStorage.setItem(
      _storageKey,
      customIdeas
          .map((g) => '${g.emoji}|${g.name}|${g.price}|${g.author}')
          .join('\n'),
    );
  }

  /// Entries are stored as `emoji|name|price|author`. Ideas saved before the
  /// emoji/author fields existed only have `name|price`, so anything with
  /// fewer than three fields is read using the old layout.
  static GiftItem _parseIdea(String entry) {
    final parts = entry.split('|');
    if (parts.length < 3) {
      return GiftItem(
        emoji: '💡',
        name: parts[0],
        price: _formatPrice(parts.length > 1 ? parts[1] : ''),
      );
    }
    return GiftItem(
      emoji: parts[0],
      name: parts[1],
      price: _formatPrice(parts[2]),
      author: parts.length > 3 ? parts[3] : '',
    );
  }

  /// `|` and newlines are the storage separators, so they can't survive a
  /// round-trip through localStorage.
  static String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[|\r\n]'), ' ').trim();

  /// Só dígitos e separadores entram no campo de valor: qualquer letra ou
  /// símbolo é descartado enquanto o convidado digita.
  static String _priceInput(String value) =>
      value.replaceAll(RegExp(r'[^\d.,]'), '');

  /// O valor precisa ser um número legível: `25`, `25,90`, `1.000` ou
  /// `1.000,50`. Sobras como `1,2,3` ou só um separador travam o botão em vez
  /// de virar um Pix errado.
  static bool _isPriceValid(String value) =>
      RegExp(r'^\d+([.,]\d{3})*([.,]\d{1,2})?$').hasMatch(_priceInput(value));

  /// Normaliza o valor para o padrão brasileiro (`R$ 1.234,56`): o último
  /// separador seguido de 1 ou 2 dígitos é o decimal — não importa se veio
  /// como ponto ou vírgula — e os demais são milhar e somem.
  static String _formatPrice(String value) {
    final raw = _priceInput(value);
    if (!RegExp(r'\d').hasMatch(raw)) return '';

    final decimalMatch = RegExp(r'[.,](\d{1,2})$').firstMatch(raw);
    final cents = decimalMatch?.group(1) ?? '';
    final wholeSource = decimalMatch == null
        ? raw
        : raw.substring(0, decimalMatch.start);
    final whole = wholeSource.replaceAll(RegExp(r'[^\d]'), '');

    final grouped = StringBuffer();
    final digits = whole.isEmpty ? '0' : whole;
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
      grouped.write(digits[i]);
    }

    // `25,5` vira `25,50`: centavos pela metade confundem na hora do Pix.
    final suffix = cents.isEmpty ? '' : ',${cents.padRight(2, '0')}';
    return 'R\$ $grouped$suffix';
  }

  /// O botão só libera com emoji, nome e um valor que dá para virar Pix.
  /// Os três são obrigatórios; só o autor é opcional.
  bool get _canSubmit =>
      _sanitize(emojiInput).isNotEmpty &&
      _sanitize(nameInput).isNotEmpty &&
      _isPriceValid(priceInput);

  /// Formulário em branco não é erro: a mensagem só aparece depois que o
  /// convidado começou a preencher (ou apagou o emoji que já vinha escolhido).
  bool get _formTouched =>
      nameInput.trim().isNotEmpty ||
      priceInput.isNotEmpty ||
      authorInput.trim().isNotEmpty ||
      _sanitize(emojiInput).isEmpty;

  /// Primeiro problema pendente do formulário, ou `null` quando está tudo
  /// certo. Só uma mensagem por vez para não encher a tela de alertas.
  String? get _formError {
    if (_sanitize(emojiInput).isEmpty) return 'Escolha um emoji para a ideia.';
    if (_sanitize(nameInput).isEmpty) return 'Dê um nome para a ideia.';
    if (priceInput.trim().isEmpty) return 'Informe o valor da ideia.';
    if (!_isPriceValid(priceInput)) {
      return 'Escreva o valor só com números, como 25 ou 25,90.';
    }
    return null;
  }

  Future<void> _addIdea() async {
    final name = _sanitize(nameInput);
    final price = _formatPrice(priceInput);
    final author = _sanitize(authorInput);
    final emoji = _sanitize(emojiInput);
    if (!_canSubmit || sending) return;

    final idea = GiftItem(
      emoji: emoji,
      name: name,
      price: price,
      author: author,
    );

    // A ideia entra na tela na hora: a viagem até a planilha não pode fazer o
    // convidado achar que o botão não funcionou.
    setState(() {
      customIdeas = [...customIdeas, idea];
      nameInput = '';
      priceInput = '';
      authorInput = '';
      emojiInput = giftEmojiOptions.first;
      sendError = null;
      sending = _api.isEnabled;
    });
    _cacheIdeas();

    if (!_api.isEnabled) return;

    final sent = await _api.submitIdea(idea);
    if (_disposed) return;
    setState(() {
      sending = false;
      sendError = sent
          ? null
          : 'Não deu para salvar a ideia para os outros convidados agora. '
                'Ela ficou aqui no seu navegador — tente de novo mais tarde.';
    });
    // Aproveita para trazer o que os outros mandaram enquanto isso.
    if (sent) await _loadIdeas();
  }

  @override
  Component build(BuildContext context) {
    return section(id: 'presentes', classes: 'gifts', [
      h2(classes: 'section-title', [
        .text('Lista de Presentes (de brincadeira)'),
      ]),
      p(classes: 'gifts-subtitle', [
        .text(
          'A presença de vocês já é o maior presente! Não precisa trazer nada — se quiserem nos ajudar, '
          'preferimos um Pix. Mas pra dar uma graça, aqui vai um cardápio de ideias totalmente '
          'não oficiais de quanto cada coisa "vale":',
        ),
      ]),
      div(
        classes: 'gifts-grid',
        [
          for (final gift in [...giftList, ...customIdeas]) _giftCard(gift),
        ],
      ),
      div(classes: 'gift-add', [
        h3([.text('Tem uma ideia engraçada? Adicione a sua!')]),
        p(classes: 'gift-add-label', [
          .text(
            'O que você mandar aparece na lista para todo mundo que abrir o site.',
          ),
        ]),
        p(classes: 'gift-add-label', [
          .text(
            'Escolha um emoji da lista — ou digite/cole qualquer outro no primeiro campo, '
            'usando o teclado de emojis do seu celular ou computador.',
          ),
        ]),
        div(classes: 'gift-emoji-picker', [
          for (final emoji in giftEmojiOptions)
            button(
              classes: emoji == emojiInput
                  ? 'emoji-option selected'
                  : 'emoji-option',
              attributes: {'type': 'button', 'aria-label': 'Emoji $emoji'},
              onClick: () => setState(() => emojiInput = emoji),
              [.text(emoji)],
            ),
        ]),
        div(classes: 'gift-add-form', [
          input<String>(
            type: InputType.text,
            value: emojiInput,
            classes: 'emoji-input',
            attributes: {
              'placeholder': '🎉',
              'aria-label': 'Emoji da ideia — escolha acima ou digite o seu',
            },
            onInput: (value) => setState(() => emojiInput = value),
          ),
          input<String>(
            type: InputType.text,
            value: nameInput,
            attributes: {'placeholder': 'Ex: Taxa pro noivo não roncar'},
            onInput: (value) => setState(() => nameInput = value),
          ),
          input<String>(
            type: InputType.text,
            value: priceInput,
            attributes: {
              'placeholder': 'Ex: 25,90',
              'inputmode': 'decimal',
            },
            onInput: (value) => setState(() => priceInput = _priceInput(value)),
          ),
          input<String>(
            type: InputType.text,
            value: authorInput,
            attributes: {'placeholder': 'Seu nome (opcional)'},
            onInput: (value) => setState(() => authorInput = value),
          ),
          button(
            onClick: _addIdea,
            attributes: {
              if (!_canSubmit || sending) 'disabled': '',
            },
            [.text(sending ? 'Enviando…' : 'Adicionar ideia')],
          ),
          if (_formTouched)
            if (_formError case final error?)
              p(classes: 'gift-add-error', [.text(error)]),
          if (sendError case final error?)
            p(classes: 'gift-add-error', [.text(error)]),
        ]),
      ]),
      if (_api.isEnabled)
        button(
          classes: [
            'gift-refresh',
            if (refreshing) 'is-refreshing',
            if (refreshFailed) 'has-failed',
          ].join(' '),
          attributes: {
            'type': 'button',
            'aria-label': 'Atualizar a lista de ideias',
            'title': refreshFailed
                ? 'Não deu para atualizar agora. Tente de novo.'
                : 'Ver as ideias que os outros convidados mandaram',
            if (refreshing) 'disabled': '',
          },
          onClick: _refresh,
          [
            span(classes: 'gift-refresh-icon', [.text('↻')]),
          ],
        ),
      if (toastMessage case final message?)
        ToastStack(
          toasts: [
            Toast(
              message: message,
              isError: toastIsError,
              showSpinner: refreshing,
            ),
          ],
        ),
    ]);
  }

  /// Identidade estável do card — os itens não têm id próprio, então o
  /// conteúdo serve de chave.
  static String _giftId(GiftItem gift) =>
      '${gift.emoji}|${gift.name}|${gift.price}';

  void _toggleFlip(GiftItem gift) {
    final id = _giftId(gift);
    setState(() {
      if (!flippedGifts.remove(id)) flippedGifts.add(id);
      copiedGift = null;
    });
  }

  void _copyPix(GiftItem gift, String payload) {
    if (kIsWeb) {
      web.window.navigator.clipboard.writeText(payload);
    }
    setState(() => copiedGift = _giftId(gift));
  }

  Component _giftCard(GiftItem gift) {
    final id = _giftId(gift);
    final flipped = flippedGifts.contains(id);
    final payload = buildPixPayload(
      key: pixKey,
      merchantName: pixReceiverName,
      merchantCity: pixCity,
      amount: parsePixAmount(gift.price),
      message: (gift.author.isEmpty ? '' : '${gift.author}: ') + gift.name,
    );

    return div(classes: 'gift-card', [
      div(
        classes: flipped ? 'gift-card-inner flipped' : 'gift-card-inner',
        // O card inteiro é clicável: qualquer ponto vira a carta.
        attributes: {
          'role': 'button',
          'tabindex': '0',
          'aria-pressed': flipped ? 'true' : 'false',
          'aria-label': flipped
              ? 'Voltar para os detalhes de "${gift.name}"'
              : 'Mostrar QR Code do Pix para "${gift.name}"',
        },
        events: {
          'click': (_) => _toggleFlip(gift),
          'keydown': (event) {
            final key = (event as web.KeyboardEvent).key;
            if (key != 'Enter' && key != ' ') return;
            event.preventDefault();
            _toggleFlip(gift);
          },
        },
        [
          div(classes: 'gift-face gift-front', [
            span(classes: 'gift-emoji', [.text(gift.emoji)]),
            h3([.text(gift.name)]),
            if (gift.price.isNotEmpty)
              p(classes: 'gift-price', [.text(gift.price)]),
            if (gift.author.isNotEmpty)
              p(classes: 'gift-author', [.text('ideia de ${gift.author}')]),
            p(classes: 'gift-hint', [.text('toque no card para o Pix')]),
          ]),
          div(classes: 'gift-face gift-back', [
            // O QR só é gerado depois do primeiro clique: montar dezenas deles
            // de uma vez atrasaria bastante a primeira renderização.
            // Nome e valor já aparecem na frente do card (e vão dentro do
            // próprio payload), então aqui só o QR precisa de espaço.
            if (flipped) PixQr(data: payload, size: 190),
            button(
              classes: 'gift-copy',
              attributes: {'type': 'button'},
              // Copiar não pode virar o card junto.
              events: {
                'click': (event) {
                  event.stopPropagation();
                  _copyPix(gift, payload);
                },
              },
              [.text(copiedGift == id ? 'Copiado!' : 'Copiar código Pix')],
            ),
            p(classes: 'gift-flip-back', [.text('toque no card para voltar')]),
          ]),
        ],
      ),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.gifts', [
      css('&').styles(backgroundColor: AppColors.bg),
      css('.section-title').styles(
        textAlign: .center,
        fontSize: 2.5.rem,
        color: AppColors.accentStrong,
        margin: .only(bottom: 12.px),
      ),
      css('.gifts-subtitle').styles(
        textAlign: .center,
        color: AppColors.textMuted,
        maxWidth: 560.px,
        margin: .symmetric(horizontal: Unit.expression('auto')),
      ),
      css('.gifts-grid').styles(
        display: .flex,
        flexWrap: .wrap,
        justifyContent: .center,
        gap: .all(24.px),
        maxWidth: 1100.px,
        margin: .only(
          top: 48.px,
          left: Unit.expression('auto'),
          right: Unit.expression('auto'),
        ),
      ),
      css('.gift-card', [
        css('&').styles(
          width: 240.px,
          minHeight: 340.px,
          raw: {'perspective': '1000px'},
        ),
        css(
          '&:hover .gift-card-inner:not(.flipped)',
        ).styles(transform: .translate(y: (-4).px)),
      ]),
      // O card inteiro gira em 3D; as duas faces ficam empilhadas e apenas a
      // que está de frente permanece visível.
      css('.gift-card-inner').styles(
        position: const Position.relative(),
        cursor: .pointer,
        width: 100.percent,
        height: 100.percent,
        minHeight: 340.px,
        transition: Transition(
          'transform',
          duration: 500.ms,
          curve: Curve.ease,
        ),
        raw: {'transform-style': 'preserve-3d'},
      ),
      css(
        '.gift-card-inner.flipped',
      ).styles(raw: {'transform': 'rotateY(180deg)'}),
      css('.gift-face').styles(
        position: const Position.absolute(top: Unit.zero, left: Unit.zero),
        display: .flex,
        flexDirection: .column,
        alignItems: .center,
        justifyContent: .center,
        textAlign: .center,
        width: 100.percent,
        height: 100.percent,
        padding: .all(24.px),
        // Nada pode vazar para fora da borda do card.
        overflow: .hidden,
        backgroundColor: AppColors.bgElevated,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
        shadow: BoxShadow(
          offsetX: .zero,
          offsetY: 4.px,
          blur: 16.px,
          color: AppColors.shadow,
        ),
        raw: {
          'backface-visibility': 'hidden',
          '-webkit-backface-visibility': 'hidden',
        },
      ),
      css('.gift-back').styles(
        gap: .all(8.px),
        // O QR precisa de folga lateral; a face da frente é que pede padding
        // maior por causa do texto.
        padding: .symmetric(vertical: 16.px, horizontal: 12.px),
        raw: {'transform': 'rotateY(180deg)'},
      ),
      css('.gift-qr-note').styles(fontSize: 12.px, color: AppColors.textMuted),
      css('.pix-qr').styles(
        radius: .circular(8.px),
        padding: .all(6.px),
        backgroundColor: const Color('#ffffff'),
        // Sem isto o flex column encolhe o SVG até ele ficar ilegível.
        raw: {'flex-shrink': '0'},
      ),
      css('.gift-copy', [
        css('&').styles(
          padding: .symmetric(vertical: 8.px, horizontal: 14.px),
          border: .unset,
          radius: .circular(AppRadius.md),
          backgroundColor: AppColors.accent,
          color: Colors.white,
          fontSize: 13.px,
          fontWeight: .w600,
          fontFamily: AppFonts.body,
          cursor: .pointer,
        ),
        css('&:hover').styles(backgroundColor: AppColors.accentStrong),
        css('&:disabled').styles(
          backgroundColor: AppColors.border,
          color: AppColors.textMuted,
          cursor: .notAllowed,
        ),
      ]),
      // Ocupa a linha inteira do form para a mensagem não brigar com os campos.
      css('.gift-add-error').styles(
        flex: Flex(grow: 1, shrink: 1, basis: 100.percent),
        textAlign: .center,
        fontSize: 13.px,
        color: AppColors.accentStrong,
        margin: .zero,
      ),
      css('.gift-flip-back').styles(
        color: AppColors.textMuted,
        fontSize: 12.px,
      ),
      css('.gift-hint').styles(
        fontSize: 11.px,
        color: AppColors.textMuted,
        margin: .only(top: 10.px),
      ),
      css('.gift-emoji', [
        css('&').styles(
          display: .block,
          fontSize: 2.5.rem,
          lineHeight: 1.em,
          margin: .only(bottom: 8.px),
          padding: .all(4.px),
          transition: Transition('transform', duration: 150.ms),
        ),
        css('.gift-card:hover &').styles(transform: .scale(1.15)),
      ]),
      css('.gift-card h3').styles(
        fontSize: 16.px,
        color: AppColors.text,
        margin: .only(bottom: 8.px),
      ),
      css('.gift-price').styles(
        color: AppColors.accentStrong,
        fontWeight: .w700,
      ),
      css('.gift-add').styles(
        maxWidth: 560.px,
        margin: .only(
          top: 56.px,
          left: Unit.expression('auto'),
          right: Unit.expression('auto'),
        ),
        textAlign: .center,
      ),
      css('.gift-author').styles(
        color: AppColors.textMuted,
        fontSize: 13.px,
        fontStyle: .italic,
        margin: .only(top: 8.px),
      ),
      css('.gift-add h3').styles(
        color: AppColors.text,
        margin: .only(bottom: 16.px),
      ),
      css('.gift-add-label').styles(
        color: AppColors.textMuted,
        fontSize: 14.px,
        margin: .only(bottom: 8.px),
      ),
      css('.gift-emoji-picker').styles(
        display: .flex,
        flexWrap: .wrap,
        gap: .all(6.px),
        justifyContent: .center,
        margin: .only(bottom: 16.px),
      ),
      css('.emoji-option', [
        css('&').styles(
          fontSize: 20.px,
          lineHeight: 1.2.em,
          padding: .symmetric(vertical: 4.px, horizontal: 6.px),
          backgroundColor: AppColors.bgElevated,
          border: .all(style: .solid, color: AppColors.border, width: 1.px),
          radius: .circular(AppRadius.md),
          cursor: .pointer,
        ),
        css('&:hover').styles(
          border: .all(style: .solid, color: AppColors.accent, width: 1.px),
        ),
        css('&.selected').styles(
          backgroundColor: AppColors.bgSoft,
          border: .all(
            style: .solid,
            color: AppColors.accentStrong,
            width: 2.px,
          ),
        ),
      ]),
      css('.gift-add-form').styles(
        display: .flex,
        flexWrap: .wrap,
        gap: .all(12.px),
        justifyContent: .center,
      ),
      css('.gift-add-form input').styles(
        padding: .symmetric(vertical: 10.px, horizontal: 16.px),
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
        backgroundColor: AppColors.bgElevated,
        color: AppColors.text,
        fontFamily: AppFonts.body,
        flex: Flex(grow: 1, shrink: 1, basis: 200.px),
      ),
      css('.gift-add-form .emoji-input').styles(
        textAlign: .center,
        flex: Flex(grow: 0, shrink: 0, basis: 64.px),
      ),
      css('.gift-add-form button', [
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
      ]),
      // Ocupa a linha inteira do form para a mensagem não brigar com os campos.
      css('.gift-add-error').styles(
        flex: Flex(grow: 1, shrink: 1, basis: 100.percent),
        textAlign: .center,
        fontSize: 13.px,
        color: AppColors.accentStrong,
        margin: .zero,
      ),
      // Fica fixo na tela: o convidado pode buscar as ideias novas de onde
      // estiver na página, sem voltar até o formulário.
      css('.gift-refresh', [
        css('&').styles(
          position: .fixed(bottom: 24.px, right: 24.px),
          zIndex: ZIndex(20),
          display: .flex,
          alignItems: .center,
          justifyContent: .center,
          width: 48.px,
          height: 48.px,
          padding: .zero,
          border: .all(
            style: .solid,
            color: AppColors.border,
            width: 1.px,
          ),
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
        css('&.is-refreshing .gift-refresh-icon').styles(
          animation: const Animation(
            name: 'gift-refresh-spin',
            duration: Duration(milliseconds: 900),
            curve: .linear,
            count: 9999,
          ),
        ),
      ]),
      css('.gift-refresh-icon').styles(display: .block),
    ]),
    css.keyframes('gift-refresh-spin', {
      'from': Styles(transform: .rotate(0.deg)),
      'to': Styles(transform: .rotate(360.deg)),
    }),
  ];
}
