import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../components/challenge_reveal.dart';
import '../components/gallery_refresh_button.dart';
import '../components/guest_name_gate.dart';
import '../components/loading_indicator.dart';
import '../components/photo_capture.dart';
import '../components/photo_gallery.dart';
import '../components/preview_panel.dart';
import '../components/theme_toggle.dart';
import '../components/toast.dart';
import '../constants/photo_challenges.dart';
import '../constants/theme.dart';
import '../utils/challenge_draw.dart';
import '../utils/custom_challenge.dart';
import '../utils/guest_challenge_draw.dart';
import '../utils/guest_name.dart';
import '../utils/local_gallery.dart';
import '../utils/photo_challenges_api.dart';
import '../utils/preview_mode.dart';

/// Página de `/fotos`: pede o nome do convidado, sorteia 3 desafios com uma
/// animação, guia a captura de uma foto por desafio e mostra o álbum
/// compartilhado.
class PhotoChallengesPage extends StatelessComponent {
  const PhotoChallengesPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'photo-challenges-page', [
      div(classes: 'photo-challenges-header', [const ThemeToggle()]),
      const PhotoChallengesFlow(),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    // Um bloco comum, de propósito, e não um flex column: como flex item o
    // cabeçalho `sticky` largava o topo assim que a página passava a rolar
    // (foi só o álbum carregar para ela ficar alta o bastante) e ia parar no
    // fim dela. A navbar de `/`, que é `sticky` igual mas mora num bloco,
    // nunca teve isso. Ninguém aqui perde a centralização: cada filho já
    // centraliza o próprio conteúdo.
    css('.photo-challenges-page').styles(
      minHeight: 100.vh,
    ),
    css('.photo-challenges-header').styles(
      position: .sticky(top: .zero),
      display: .flex,
      justifyContent: .end,
      width: 100.percent,
      padding: .symmetric(vertical: 8.px, horizontal: 32.px),
      backgroundColor: AppColors.bg.withOpacity(0.85),
      border: .only(
        bottom: BorderSide(color: AppColors.border, width: 1.px),
      ),
      zIndex: ZIndex(10),
      backdropFilter: Filter.blur(8.px),
    ),
  ];
}

/// Único ponto de hidratação (`@client`) da página: sem parâmetros no
/// construtor, porque componentes `@client` só aceitam tipos primitivos
/// serializáveis. O nome do convidado, o sorteio e a galeria vivem como
/// estado interno; [GuestNameGate], [ChallengeReveal] e [PhotoCapture] são
/// montados aqui dentro como componentes comuns (não `@client`), já que
/// fazem parte da mesma subárvore já hidratada.
@client
class PhotoChallengesFlow extends StatefulComponent {
  const PhotoChallengesFlow({super.key});

  @override
  State<PhotoChallengesFlow> createState() => PhotoChallengesFlowState();
}

/// Ids fixos de toast para os fluxos que têm um aviso de "em andamento"
/// seguido do resultado — o resultado atualiza o mesmo toast na pilha em vez
/// de empilhar um segundo. Cada fluxo só roda um de cada vez (guardado por
/// flags como `_galleryRefreshing`), então um id fixo por fluxo basta.
const _galleryRefreshToastId = 'gallery-refresh';
const _photoUploadToastId = 'photo-upload';

class _ToastEntry {
  const _ToastEntry({
    required this.id,
    required this.message,
    required this.isError,
  });

  final Object id;
  final String message;
  final bool isError;
}

class PhotoChallengesFlowState extends State<PhotoChallengesFlow> {
  final _api = const PhotoChallengesApi();

  /// Referência ao portão do nome, para avisá-lo de uma correção de nome
  /// (ver [_renameGuest]) sem passar por ele de novo — sem isso, o portão
  /// continuaria enxergando o nome antigo e a comparação em [build] achava
  /// que um convidado diferente tinha aparecido, sorteando os desafios de
  /// novo por engano.
  final _gateKey = GlobalStateKey<GuestNameGateState>();

  /// Convidado para quem o sorteio atual em [_challenges] foi feito. `null`
  /// enquanto o nome ainda não é conhecido ou o sorteio ainda não começou.
  String? _guestName;

  /// Id do convidado na planilha (aba `convidados`), devolvido pelo
  /// servidor no primeiro sorteio. `null` até lá, ou em modo local
  /// (endpoint desligado) — corrigir o nome (ver [_renameGuest]) só é
  /// possível com o endpoint ligado e o id conhecido.
  String? _guestId;

  /// Correção de nome (FR de renomear) em andamento.
  bool _renamingGuest = false;
  bool _renameFormOpen = false;
  String _renameInput = '';
  String? _renameError;

  /// Todos os desafios do convidado: os de cada sorteio mais os que ele
  /// mesmo escreveu, na ordem em que apareceram. Os que ainda não têm foto
  /// em [_confirmedPhotos] são os pendentes, e são só esses que ficam na
  /// frente do convidado — o resto vira histórico recolhido.
  List<PhotoChallenge>? _challenges;
  Map<String, String> _confirmedPhotos = {};

  /// Textos cuja animação de sorteio já rodou neste navegador: cada sorteio
  /// novo anima só as frases dele, sem repetir as que o convidado já viu.
  Set<String> _revealedTexts = {};

  /// Histórico (desafios já enviados) aberto — começa fechado para não
  /// empurrar o que interessa, os pendentes, para fora da tela.
  bool _historyOpen = false;

  /// Sorteio de mais um trio em andamento.
  bool _drawingMore = false;

  /// Desafio escrito pelo próprio convidado, esperando a foto. Só entra em
  /// [_challenges] quando a foto é confirmada — desistir no meio não deixa
  /// um desafio pendente para trás.
  PhotoChallenge? _customChallenge;
  bool _customFormOpen = false;
  String _customInput = '';
  CustomChallengeError? _customError;

  List<GalleryPhoto>? _galleryPhotos;
  bool _galleryLoading = false;

  /// Atualização manual do álbum em andamento (botão flutuante).
  bool _galleryRefreshing = false;

  /// A última atualização manual não chegou até a planilha.
  bool _galleryRefreshFailed = false;

  /// Modo prévia ligado neste navegador (ver [readPreviewMode]): os noivos
  /// testando o site publicado, onde `kDebugMode` é sempre falso.
  bool _previewMode = false;

  /// Se o painel de atalhos deve aparecer: em desenvolvimento ele vem de
  /// graça, em produção só com o modo prévia ligado.
  bool get _showPreviewPanel => kDebugMode || _previewMode;

  /// Força o álbum a aparecer revelado sem esperar [photoRevealDate] chegar
  /// de verdade — é a razão de existir do modo prévia, então já começa
  /// ligado quando ele está ligado.
  bool _devForceReveal = false;

  /// Desafio pendente que o convidado tocou para tirar a foto agora. `null`
  /// enquanto nenhum estiver selecionado — a câmera só aparece com um
  /// desafio selecionado.
  String? _selectedChallengeText;

  /// Textos dos desafios cuja foto foi confirmada mas não conseguiu ser
  /// enviada à planilha/Drive (endpoint ligado, mas a chamada falhou) — a
  /// foto fica só neste navegador (FR-15) e o convidado precisa ser avisado,
  /// já que os noivos não vão vê-la no álbum sozinhos.
  final Set<String> _uploadFailedChallenges = {};

  /// Avisos passageiros no rodapé, para o convidado saber quando a página
  /// está conversando com a planilha/Drive (algo que acontece fora do
  /// aparelho dele e, sem isso, pareceria só ter travado).
  ///
  /// Empilhados (não substituídos): um sorteio e um envio de foto podem
  /// avisar ao mesmo tempo, e o convidado precisa conseguir ler os dois em
  /// vez de o segundo apagar o primeiro antes da hora. Chamadas que passam o
  /// mesmo [_showToast]'s `id` (ex.: "mandando" seguido de "mandado") ainda
  /// substituem uma à outra — são o mesmo aviso evoluindo, não dois avisos.
  final List<_ToastEntry> _toasts = [];
  final Map<Object, Timer> _toastTimers = {};
  int _toastSeq = 0;

  bool _disposed = false;

  /// Banco de frases inteiro (ver [PhotoChallengesApi.fetchChallengeBank]),
  /// buscado da planilha assim que a página abre — única fonte dele, sem
  /// cópia local no site. `null` enquanto a busca não termina.
  List<PhotoChallenge>? _challengeBank;

  /// A busca de [_challengeBank] falhou (endpoint desligado ou a chamada não
  /// respondeu): sem banco de frases não dá para sortear nem validar
  /// desafios escritos à mão, então a página não sai desse estado sozinha.
  bool _challengeBankFailed = false;

  @override
  void initState() {
    super.initState();
    _previewMode = readPreviewMode();
    _devForceReveal = _previewMode;
    unawaited(_loadChallengeBank());
  }

  Future<void> _loadChallengeBank() async {
    if (!kIsWeb) return;
    final bank = await _api.fetchChallengeBank();
    if (_disposed) return;
    if (bank == null) {
      setState(() => _challengeBankFailed = true);
      return;
    }
    setState(() => _challengeBank = bank);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  /// Mostra um aviso passageiro. Sem [id], sempre empilha um novo; com [id],
  /// atualiza o aviso daquele id se já houver um na pilha (ex.: o "enviando"
  /// virando "enviado"), ou o cria caso contrário.
  void _showToast(
    String message, {
    bool isError = false,
    Duration? autoDismiss,
    Object? id,
  }) {
    final toastId = id ?? _toastSeq++;
    _toastTimers.remove(toastId)?.cancel();
    setState(() {
      final entry = _ToastEntry(
        id: toastId,
        message: message,
        isError: isError,
      );
      final index = _toasts.indexWhere((t) => t.id == toastId);
      if (index == -1) {
        _toasts.add(entry);
      } else {
        _toasts[index] = entry;
      }
    });
    if (autoDismiss == null) return;
    _toastTimers[toastId] = Timer(autoDismiss, () {
      _toastTimers.remove(toastId);
      if (_disposed) return;
      setState(() => _toasts.removeWhere((t) => t.id == toastId));
    });
  }

  /// Dispara o sorteio para [guestName] na primeira vez que ele é conhecido.
  /// Chamado de fora do `build` (via microtask) para não mudar estado durante
  /// a construção da árvore.
  void _startFor(String guestName) {
    if (_guestName == guestName || _disposed) return;
    // Com `setState` para o painel de prévia, que é irmão do portão do nome,
    // enxergar o nome novo sem esperar o sorteio voltar da planilha.
    setState(() => _guestName = guestName);
    _init(guestName);
  }

  Future<void> _init(String guestName) async {
    final challengeBank = _challengeBank!;
    final stored = readGuestChallengeDraw(
      guestName,
      challengeBank: challengeBank,
    );

    List<PhotoChallenge>? drawn;
    Map<String, String>? remoteConfirmedPhotos;
    if (_api.isEnabled) {
      final remote = await _api.drawChallenges(
        guestName,
        guestId: readGuestId(),
        challengeBank: challengeBank,
      );
      if (remote != null) {
        drawn = remote.challenges;
        remoteConfirmedPhotos = remote.confirmedPhotos;
        if (remote.guestId.isNotEmpty) writeGuestId(remote.guestId);
        if (!_disposed) setState(() => _guestId = remote.guestId);
      }
    }
    drawn ??= stored?.challenges ?? _localDraw(const []);

    // Desafios que só este navegador conhece: a foto foi confirmada, mas o
    // envio para a planilha falhou (FR-15). Eles não voltam do servidor e
    // sumiriam do histórico do convidado se a resposta dele fosse aplicada
    // sozinha.
    final storedPhotos = stored?.photos ?? const <String, String>{};
    final localOnly = [
      for (final challenge in stored?.challenges ?? const <PhotoChallenge>[])
        if (!drawn.contains(challenge) &&
            storedPhotos.containsKey(challenge.text))
          challenge,
    ];
    final all = [...drawn, ...localOnly];

    // Quando o servidor respondeu, ele é a fonte de verdade de quais
    // desafios já têm foto (FR-16) — o `localStorage` pode estar
    // desatualizado (ex.: foto marcada como feita numa sessão antiga cujo
    // envio nunca chegou à planilha). Só cai para o que está salvo neste
    // navegador quando o servidor está desligado ou não respondeu, para não
    // perder o registro do modo local (FR-15).
    final confirmedSource = remoteConfirmedPhotos ?? storedPhotos;
    final confirmed = <String, String>{
      for (final entry in confirmedSource.entries)
        if (all.any((c) => c.text == entry.key)) entry.key: entry.value,
      for (final challenge in localOnly)
        challenge.text: storedPhotos[challenge.text]!,
    };

    // Um desafio já fotografado obviamente já foi visto: só as frases de um
    // sorteio que este navegador ainda não mostrou passam pela animação
    // (FR-10) — reabrir a página não repete a de quem já viu.
    final revealed = {
      ...?stored?.revealed,
      ...confirmed.keys,
    }..removeWhere((text) => !all.any((c) => c.text == text));

    if (_disposed) return;
    _applyChallenges(guestName, all, confirmed, revealed);

    unawaited(_refreshGallery());
  }

  /// Guarda o estado dos desafios do convidado na tela e no navegador — os
  /// dois sempre juntos, para uma recarga não voltar no tempo.
  void _applyChallenges(
    String guestName,
    List<PhotoChallenge> challenges,
    Map<String, String> photos,
    Set<String> revealed,
  ) {
    setState(() {
      _challenges = challenges;
      _confirmedPhotos = photos;
      _revealedTexts = revealed;
    });
    writeGuestChallengeDraw(guestName, challenges, photos, revealed: revealed);
  }

  /// Desafios do convidado que ainda esperam uma foto.
  List<PhotoChallenge> get _pending => [
    for (final challenge in _challenges ?? const <PhotoChallenge>[])
      if (!_confirmedPhotos.containsKey(challenge.text)) challenge,
  ];

  /// Desafios que o convidado já mandou — o histórico recolhido.
  List<PhotoChallenge> get _done => [
    for (final challenge in _challenges ?? const <PhotoChallenge>[])
      if (_confirmedPhotos.containsKey(challenge.text)) challenge,
  ];

  /// Toca em um desafio ainda pendente para selecioná-lo (abrindo a câmera)
  /// ou tocar de novo para desmarcá-lo.
  void _toggleChallenge(String challengeText) {
    setState(() {
      _selectedChallengeText = _selectedChallengeText == challengeText
          ? null
          : challengeText;
    });
  }

  void _onRevealFinished(String guestName, List<PhotoChallenge> revealed) {
    final challenges = _challenges;
    if (challenges == null) return;
    _applyChallenges(guestName, challenges, _confirmedPhotos, {
      ..._revealedTexts,
      for (final challenge in revealed) challenge.text,
    });
  }

  /// Sorteio local (FR-9), usado quando o endpoint não está configurado ou
  /// não respondeu: mesmas regras do servidor, mas sem saber o que os outros
  /// convidados já pegaram — sem uma fonte única de verdade, a preferência
  /// por frases inéditas fica valendo só dentro deste navegador.
  List<PhotoChallenge> _localDraw(List<PhotoChallenge> current) {
    return drawPhotoChallenges(
      bank: _challengeBank!,
      pickedByGuest: {for (final challenge in current) challenge.text},
      pickedByAnyone: const {},
    );
  }

  /// Sorteia mais um trio, depois que o convidado mandou as fotos de todos
  /// os desafios que já tinha.
  Future<void> _drawMore(String guestName) async {
    final current = _challenges;
    if (current == null || _drawingMore) return;

    setState(() => _drawingMore = true);
    List<PhotoChallenge>? updated;
    Map<String, String>? photos;
    String? error;
    if (_api.isEnabled) {
      final (remote, drawError) = await _api.drawMore(
        guestName,
        guestId: _guestId,
        challengeBank: _challengeBank!,
      );
      if (remote != null) {
        updated = remote.challenges;
        photos = remote.confirmedPhotos;
      } else {
        error = drawError;
      }
    } else {
      updated = [...current, ..._localDraw(current)];
    }
    if (_disposed) return;
    setState(() => _drawingMore = false);

    if (updated == null) {
      _showToast(
        'Não deu para sortear agora. Tente de novo em instantes.'
        '${error != null ? ' ($error)' : ''}',
        isError: true,
        autoDismiss: const Duration(seconds: 5),
      );
      return;
    }
    // Compara pelo que veio a mais, não pelo tamanho: a lista do servidor
    // pode não ter os desafios que só existem neste navegador (envio que
    // falhou), e o convidado não pode perdê-los ao sortear de novo.
    final added = [
      for (final challenge in updated)
        if (!current.contains(challenge)) challenge,
    ];
    if (added.isEmpty) {
      // O banco de frases acabou para este convidado: daqui pra frente só
      // sobram os desafios que ele mesmo escrever.
      _showToast(
        'Acabaram os desafios sorteáveis! Agora é só criar os seus.',
        autoDismiss: const Duration(seconds: 6),
      );
      return;
    }

    final all = [...current, ...added];
    final confirmed = <String, String>{
      ..._confirmedPhotos,
      if (photos != null)
        for (final entry in photos.entries)
          if (all.any((c) => c.text == entry.key)) entry.key: entry.value,
    };
    _applyChallenges(guestName, all, confirmed, {
      ..._revealedTexts,
      ...confirmed.keys,
    });
  }

  /// Abre (ou fecha) o campo de escrever o próprio desafio.
  void _toggleCustomForm() {
    setState(() {
      _customFormOpen = !_customFormOpen;
      _customInput = '';
      _customError = null;
    });
  }

  /// Aceita a frase escrita pelo convidado e já abre a câmera para ela.
  void _submitCustomChallenge() {
    final text = normalizeCustomChallenge(_customInput);
    final error = validateCustomChallenge(
      text,
      bank: _challengeBank!,
      alsoAvoid: [
        for (final challenge in _challenges ?? const <PhotoChallenge>[])
          challenge.text,
      ],
    );
    if (error != null) {
      setState(() => _customError = error);
      return;
    }
    setState(() {
      _customChallenge = PhotoChallenge.custom(text);
      _selectedChallengeText = text;
      _customFormOpen = false;
      _customInput = '';
      _customError = null;
    });
  }

  void _cancelCustomChallenge() {
    setState(() {
      _customChallenge = null;
      _selectedChallengeText = null;
    });
  }

  /// Esquece o nome salvo e recarrega, caindo de volta no portão do nome.
  ///
  /// Recarregar (em vez de mexer no estado em memória) é de propósito: o
  /// sorteio, a galeria e a câmera pendurados no nome antigo somem junto,
  /// sem chance de sobrar um pedaço da sessão anterior na tela.
  ///
  /// Também apaga o id do convidado: sem isso, o id do nome esquecido
  /// hijackaria a identidade de outro convidado se este navegador digitasse
  /// um nome diferente depois — o servidor casa pelo `id` antes do nome
  /// (ver `resolveGuest_` em tools/apps_script/Code.gs).
  void _forgetGuestName() {
    if (!kIsWeb) return;
    web.window.localStorage.removeItem(guestNameStorageKey);
    removeGuestId();
    web.window.location.reload();
  }

  /// Como [_forgetGuestName], mas apaga também o sorteio guardado para esse
  /// nome — recomeço do zero, sem recuperar os desafios ao redigitá-lo.
  ///
  /// Não mexe na planilha: um nome que já sorteou lá volta com o mesmo
  /// sorteio; para um sorteio realmente novo, use um nome novo.
  void _forgetGuestData() {
    if (!kIsWeb) return;
    if (readGuestName() case final name?) {
      removeGuestChallengeDraw(name);
    }
    _forgetGuestName();
  }

  /// Liga o modo prévia (senha digitada no portão do nome) e já revela o
  /// álbum, que é o que os noivos vêm testar.
  void _enablePreviewMode() {
    writePreviewMode(enabled: true);
    setState(() {
      _previewMode = true;
      _devForceReveal = true;
    });
  }

  /// Desliga o modo prévia e devolve o álbum ao borrão, para conferir como
  /// a página fica para um convidado antes da data.
  void _disablePreviewMode() {
    writePreviewMode(enabled: false);
    setState(() {
      _previewMode = false;
      _devForceReveal = false;
    });
  }

  /// Abre (ou fecha) o campo de corrigir o nome, pré-preenchido com o nome
  /// atual — é mais fácil ajustar um erro de digitação do que redigitar do
  /// zero.
  void _toggleRenameForm() {
    setState(() {
      _renameFormOpen = !_renameFormOpen;
      _renameInput = _renameFormOpen ? (_guestName ?? '') : '';
      _renameError = null;
    });
  }

  /// Corrige o nome do convidado (FR de renomear): a planilha guarda as
  /// fotos pelo `guest_id`, não pelo nome, então isso vale para todo o
  /// histórico já enviado sem precisar tocar em nenhuma linha de foto — só
  /// o [_guestId] muda de nome (ver tools/apps_script/Code.gs).
  Future<void> _renameGuest() async {
    final oldName = _guestName;
    final guestId = _guestId;
    if (oldName == null || _renamingGuest) return;
    if (guestId == null) {
      // Sem endpoint ligado (ou antes do primeiro sorteio voltar) não há
      // convidado na planilha para corrigir ainda.
      setState(
        () => _renameError =
            'Ainda não deu para confirmar seu cadastro. Tente de novo em '
            'instantes.',
      );
      return;
    }

    final normalized = normalizeGuestName(_renameInput);
    if (!isGuestNameLongEnough(normalized)) {
      setState(() => _renameError = 'Digite um nome válido.');
      return;
    }
    if (normalized == oldName) {
      setState(() => _renameFormOpen = false);
      return;
    }

    setState(() {
      _renamingGuest = true;
      _renameError = null;
    });
    final (newName, error) = await _api.renameGuest(
      guestId: guestId,
      newName: normalized,
    );
    if (_disposed) return;
    setState(() => _renamingGuest = false);

    if (newName == null) {
      setState(
        () => _renameError = switch (error) {
          'name_taken' => 'Esse nome já está sendo usado por outro convidado.',
          _ => 'Não deu para corrigir agora. Tente de novo em instantes.',
        },
      );
      return;
    }

    // O sorteio salvo neste navegador mora sob a chave do nome antigo (ver
    // `guest_challenge_draw.dart`) — sem mover, ele sumiria daqui até o
    // próximo sorteio trazê-lo de volta da planilha.
    renameGuestChallengeDraw(oldName, newName);
    writeGuestName(newName);
    // Antes do nosso próprio setState, de propósito: o portão precisa já
    // estar mostrando o nome novo quando este widget reconstruir, senão o
    // `build` acha que um convidado diferente apareceu (nome novo do
    // portão != [_guestName] já atualizado) e sorteia os desafios de novo
    // por engano.
    _gateKey.currentState?.updateGuestName(newName);
    setState(() {
      _guestName = newName;
      _renameFormOpen = false;
      _renameInput = '';
    });
    _showToast(
      'Nome corrigido para "$newName"!',
      autoDismiss: const Duration(seconds: 4),
    );

    // O álbum já carregado guarda o nome de autor de quando foi buscado —
    // ele não se atualiza sozinho só porque a planilha mudou. Busca de novo
    // para as fotos deste convidado aparecerem com o nome corrigido sem
    // esperar a próxima atualização manual (FR-16).
    unawaited(_refreshGallery());
  }

  /// Busca o álbum. Devolve `false` quando o endpoint está ligado mas a
  /// chamada falhou (caindo no álbum local), para o chamador manual saber
  /// diferenciar sucesso de falha.
  Future<bool> _refreshGallery() async {
    if (_disposed) return false;
    setState(() => _galleryLoading = true);
    final remote = _api.isEnabled ? await _api.fetchGallery() : null;
    final photos = remote ?? readLocalGalleryPhotos();
    if (_disposed) return false;
    setState(() {
      _galleryPhotos = photos;
      _galleryLoading = false;
    });
    return !_api.isEnabled || remote != null;
  }

  /// Atualização pedida pelo convidado no botão flutuante.
  Future<void> _manualRefreshGallery() async {
    if (_galleryRefreshing) return;
    setState(() {
      _galleryRefreshing = true;
      _galleryRefreshFailed = false;
    });
    _showToast('Buscando as fotos mais novas…', id: _galleryRefreshToastId);
    final loaded = await _refreshGallery();
    if (_disposed) return;
    setState(() {
      _galleryRefreshing = false;
      _galleryRefreshFailed = !loaded;
    });
    _showToast(
      loaded
          ? 'Álbum atualizado!'
          : 'Não deu para atualizar agora. Tente de novo em instantes.',
      isError: !loaded,
      autoDismiss: Duration(seconds: loaded ? 3 : 5),
      id: _galleryRefreshToastId,
    );
  }

  Future<void> _onPhotoConfirmed(
    String guestName,
    PhotoChallenge challenge,
    String dataUrl,
  ) async {
    final challenges = _challenges;
    if (challenges == null) return;

    // Um desafio escrito pelo convidado só entra na lista dele agora, junto
    // com a foto — antes disso era só um rascunho na tela.
    final updatedChallenges = challenges.contains(challenge)
        ? challenges
        : [...challenges, challenge];
    final updatedPhotos = {..._confirmedPhotos, challenge.text: dataUrl};
    setState(() {
      _selectedChallengeText = null;
      _customChallenge = null;
    });
    _applyChallenges(guestName, updatedChallenges, updatedPhotos, {
      ..._revealedTexts,
      challenge.text,
    });

    final takenAt = DateTime.now();
    String? remoteUrl;
    if (_api.isEnabled) {
      _showToast(
        'Enviando sua foto para o álbum…',
        id: _photoUploadToastId,
      );
      remoteUrl = await _api.uploadPhoto(
        guestName: guestName,
        guestId: _guestId,
        challenge: challenge,
        photoDataUrl: dataUrl,
        takenAt: takenAt,
      );
      if (!_disposed) {
        _showToast(
          remoteUrl != null ? 'Foto enviada!' : 'Não deu para enviar a foto.',
          isError: remoteUrl == null,
          autoDismiss: Duration(seconds: remoteUrl != null ? 3 : 5),
          id: _photoUploadToastId,
        );
      }
    }
    if (remoteUrl == null) {
      // Sem envio (endpoint desligado, ou ligado mas a chamada falhou):
      // guarda no álbum local para a galeria continuar demonstrável de
      // ponta a ponta (FR-15). Se o endpoint estava ligado, isso é uma
      // falha de verdade — avisa o convidado.
      appendLocalGalleryPhoto(
        GalleryPhoto(
          challengeText: challenge.text,
          authorName: guestName,
          photoUrl: dataUrl,
          takenAt: takenAt,
        ),
      );
      if (_api.isEnabled && !_disposed) {
        setState(() => _uploadFailedChallenges.add(challenge.text));
      }
    }

    await _refreshGallery();
  }

  @override
  Component build(BuildContext context) {
    final challengeBank = _challengeBank;
    if (challengeBank == null) {
      if (_challengeBankFailed) {
        return div(classes: 'photo-challenges-body', [
          div(classes: 'photo-challenges-status', [
            .text(
              'Não deu para carregar os desafios agora. Recarregue a '
              'página para tentar de novo.',
            ),
          ]),
        ]);
      }
      return const LoadingIndicator('Carregando os desafios…');
    }

    // Um elemento só na raiz, e não um `Component.fragment`: este é um
    // componente `@client`, e no site publicado o servidor entrega a ilha
    // vazia — todo o conteúdo entra na hidratação. Com vários nós na raiz
    // (ainda por cima em número variável, já que o painel é condicional) a
    // hidratação ancorava errado e enfiava a ilha inteira antes do
    // cabeçalho, que ia parar no fim da página.
    return div(classes: 'photo-challenges-body', [
      // Fora do [GuestNameGate] de propósito: o painel precisa alcançar
      // também as etapas em que o portão (ou a animação de sorteio) ainda
      // está na frente — é lá que "apagar meu nome" costuma fazer falta.
      if (_showPreviewPanel)
        PreviewPanel(
          guestName: readGuestName(),
          albumRevealed: _devForceReveal,
          onChangeName: _forgetGuestName,
          onForgetGuest: _forgetGuestData,
          onToggleAlbum: () =>
              setState(() => _devForceReveal = !_devForceReveal),
          onExit: _previewMode ? _disablePreviewMode : null,
        ),
      GuestNameGate(
        key: _gateKey,
        challengeBank: challengeBank,
        onPreviewModeRequested: _enablePreviewMode,
        builder: (context, guestName) {
          if (_guestName != guestName) {
            Future.microtask(() => _startFor(guestName));
          }
          return _buildFlow(guestName);
        },
      ),
    ]);
  }

  Component _buildFlow(String guestName) {
    final challenges = _challenges;
    if (_guestName != guestName || challenges == null) {
      return const LoadingIndicator('Carregando seus desafios…');
    }

    final pending = _pending;
    final unrevealed = [
      for (final challenge in pending)
        if (!_revealedTexts.contains(challenge.text)) challenge,
    ];
    if (unrevealed.isNotEmpty) {
      return ChallengeReveal(
        // Cada sorteio anima do zero: sem uma chave própria, o componente
        // seria reaproveitado e continuaria de onde o anterior parou.
        key: ValueKey([for (final c in unrevealed) c.text].join('|')),
        challenges: unrevealed,
        challengeBank: _challengeBank!,
        onFinished: () => _onRevealFinished(guestName, unrevealed),
      );
    }

    final done = _done;
    final selected = _selectedChallenge(pending);

    return div(classes: 'photo-challenges-flow', [
      _buildNameHeader(guestName),
      if (pending.isNotEmpty)
        div(classes: 'photo-challenges-list', [
          for (final challenge in pending)
            _buildChallengeItem(challenge, selected: selected == challenge),
        ]),
      if (selected == null) _buildNextStep(guestName, pending: pending),
      if (_uploadFailedChallenges.isNotEmpty)
        p(classes: 'photo-challenges-upload-error', [
          .text(
            _uploadFailedChallenges.length == 1
                ? 'Não conseguimos enviar sua foto de '
                      '"${_uploadFailedChallenges.first}" para o álbum '
                      'compartilhado. Ela ficou salva só neste navegador — '
                      'avise os noivos para não perder o registro!'
                : 'Não conseguimos enviar ${_uploadFailedChallenges.length} '
                      'das suas fotos para o álbum compartilhado. Elas '
                      'ficaram salvas só neste navegador — avise os noivos '
                      'para não perder o registro!',
          ),
        ]),
      if (selected != null) ...[
        if (selected.isCustom)
          div(classes: 'photo-challenges-custom-active', [
            p(classes: 'photo-challenges-custom-active-text', [
              .text(selected.text),
            ]),
            button(
              classes: 'photo-challenges-action secondary',
              onClick: _cancelCustomChallenge,
              [.text('Escrever outro desafio')],
            ),
          ]),
        PhotoCapture(
          key: ValueKey(selected.text),
          onConfirmed: (dataUrl) =>
              _onPhotoConfirmed(guestName, selected, dataUrl),
        ),
      ],
      if (done.isNotEmpty) _buildHistory(done),
      if (_galleryLoading && _galleryPhotos == null)
        p(classes: 'photo-challenges-status', [.text('Carregando álbum…')])
      else if (_galleryPhotos case final photos?)
        PhotoGallery(photos: photos, forceRevealed: _devForceReveal),
      if (_api.isEnabled)
        GalleryRefreshButton(
          onRefresh: _manualRefreshGallery,
          refreshing: _galleryRefreshing,
          failed: _galleryRefreshFailed,
        ),
      if (_toasts.isNotEmpty)
        ToastStack(
          toasts: [
            for (final toast in _toasts)
              Toast(
                key: ValueKey(toast.id),
                message: toast.message,
                isError: toast.isError,
              ),
          ],
        ),
    ]);
  }

  /// Título com o nome do convidado e o atalho para corrigi-lo (FR de
  /// renomear), para quem escreveu algo errado no portão não ficar preso a
  /// isso pelo resto da festa.
  Component _buildNameHeader(String guestName) {
    return div(classes: 'photo-challenges-name-header', [
      h1(classes: 'section-title', [.text('Seus desafios, $guestName!')]),
      if (!_renameFormOpen)
        button(
          classes: 'photo-challenges-rename-toggle',
          attributes: const {'type': 'button'},
          onClick: _toggleRenameForm,
          [.text('É "$guestName" mesmo? Corrigir nome')],
        ),
      if (_renameFormOpen) _buildRenameForm(),
    ]);
  }

  Component _buildRenameForm() {
    return div(classes: 'photo-challenges-rename', [
      input<String>(
        type: InputType.text,
        value: _renameInput,
        attributes: {'placeholder': 'Seu nome, do jeito certo'},
        onInput: (value) => setState(() {
          _renameInput = value;
          _renameError = null;
        }),
        events: {
          'keydown': (event) {
            if ((event as web.KeyboardEvent).key == 'Enter') _renameGuest();
          },
        },
      ),
      if (_renameError case final error?)
        p(classes: 'photo-challenges-rename-error', [.text(error)]),
      div(classes: 'photo-challenges-rename-actions', [
        button(
          classes: 'photo-challenges-action',
          attributes: {
            'type': 'button',
            if (_renamingGuest) 'disabled': '',
          },
          onClick: _renameGuest,
          [.text(_renamingGuest ? 'Salvando…' : 'Salvar nome')],
        ),
        button(
          classes: 'photo-challenges-action secondary',
          attributes: const {'type': 'button'},
          onClick: _toggleRenameForm,
          [.text('Cancelar')],
        ),
      ]),
    ]);
  }

  Component _buildChallengeItem(
    PhotoChallenge challenge, {
    required bool selected,
  }) {
    return div(
      classes: selected
          ? 'photo-challenge-item selected'
          : 'photo-challenge-item',
      events: events(onClick: () => _toggleChallenge(challenge.text)),
      [
        span(classes: 'photo-challenge-check', [.text('○')]),
        .text(challenge.text),
      ],
    );
  }

  /// O desafio que está com a câmera aberta: um dos pendentes sorteados ou o
  /// que o convidado acabou de escrever.
  PhotoChallenge? _selectedChallenge(List<PhotoChallenge> pending) {
    final text = _selectedChallengeText;
    if (text == null) return null;
    if (_customChallenge case final custom? when custom.text == text) {
      return custom;
    }
    for (final challenge in pending) {
      if (challenge.text == text) return challenge;
    }
    return null;
  }

  /// O que fazer agora que não há câmera aberta: sortear mais um trio (só
  /// com tudo em dia) e/ou escrever o próprio desafio (liberado depois do
  /// primeiro trio completo).
  Component _buildNextStep(
    String guestName, {
    required List<PhotoChallenge> pending,
  }) {
    final finishedRound = pending.isEmpty;
    final canWriteOwn =
        finishedRound || _confirmedPhotos.length >= challengesPerDraw;
    if (!canWriteOwn) return const Component.empty();

    return div(classes: 'photo-challenges-next', [
      if (finishedRound)
        p(classes: 'photo-challenges-done', [
          .text(
            _confirmedPhotos.isEmpty
                ? 'Não sobrou desafio para sortear — mas você ainda pode '
                      'inventar os seus!'
                : 'Você mandou todas as suas fotos! Quer continuar? 💛',
          ),
        ]),
      div(classes: 'photo-challenges-actions', [
        if (finishedRound)
          button(
            classes: 'photo-challenges-action',
            attributes: {
              'type': 'button',
              if (_drawingMore) 'disabled': '',
            },
            onClick: () => _drawMore(guestName),
            [
              .text(
                _drawingMore
                    ? 'Sorteando…'
                    : 'Sortear mais $challengesPerDraw desafios',
              ),
            ],
          ),
        button(
          classes: 'photo-challenges-action secondary',
          attributes: const {'type': 'button'},
          onClick: _toggleCustomForm,
          [
            .text(
              _customFormOpen ? 'Deixa pra lá' : 'Escrever meu próprio desafio',
            ),
          ],
        ),
      ]),
      if (_customFormOpen) _buildCustomForm(),
    ]);
  }

  Component _buildCustomForm() {
    return div(classes: 'photo-challenges-custom', [
      input<String>(
        type: InputType.text,
        value: _customInput,
        attributes: {
          'placeholder': 'Ex.: Foto do padrinho dormindo na cadeira',
          'maxlength': '$maxCustomChallengeLength',
        },
        onInput: (value) => setState(() {
          _customInput = value;
          _customError = null;
        }),
        events: {
          'keydown': (event) {
            if ((event as web.KeyboardEvent).key == 'Enter') {
              _submitCustomChallenge();
            }
          },
        },
      ),
      p(classes: 'photo-challenges-custom-hint', [
        .text(
          'Escreva pelo menos três palavras, cada uma com duas letras ou '
          'mais.',
        ),
      ]),
      if (_customError case final error?)
        p(classes: 'photo-challenges-custom-error', [.text(error.message)]),
      button(
        classes: 'photo-challenges-action',
        attributes: const {'type': 'button'},
        onClick: _submitCustomChallenge,
        [.text('Tirar a foto desse desafio')],
      ),
    ]);
  }

  /// Tudo que o convidado já mandou, recolhido atrás de um botão e com
  /// rolagem própria: fica à mão sem empurrar os desafios pendentes e o
  /// álbum para longe.
  Component _buildHistory(List<PhotoChallenge> done) {
    return div(classes: 'photo-challenges-history', [
      button(
        classes: 'photo-challenges-history-toggle',
        attributes: {
          'type': 'button',
          'aria-expanded': '$_historyOpen',
        },
        onClick: () => setState(() => _historyOpen = !_historyOpen),
        [
          .text(
            '${_historyOpen ? '▾' : '▸'} Desafios que você já mandou '
            '(${done.length})',
          ),
        ],
      ),
      if (_historyOpen)
        ul(classes: 'photo-challenges-history-list', [
          for (final challenge in done)
            li(classes: 'photo-challenges-history-item', [
              span(classes: 'photo-challenge-check', [.text('✓')]),
              .text(challenge.text),
              if (challenge.isCustom)
                span(classes: 'photo-challenges-history-tag', [
                  .text('seu desafio'),
                ]),
            ]),
        ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.photo-challenges-status').styles(
      color: AppColors.textMuted,
      padding: .all(32.px),
    ),
    css('.photo-challenges-flow').styles(
      display: .flex,
      flexDirection: .column,
      alignItems: .center,
      gap: .all(24.px),
      width: 100.percent,
      padding: .all(24.px),
      animation: const Animation(
        name: 'photo-challenges-flow-in',
        duration: Duration(milliseconds: 400),
        curve: .easeOut,
      ),
    ),
    css.keyframes('photo-challenges-flow-in', {
      'from': Styles(opacity: 0, transform: .translate(y: 8.px)),
      'to': Styles(opacity: 1, transform: .translate(y: .zero)),
    }),
    css('.section-title').styles(
      textAlign: .center,
      fontSize: 2.rem,
      color: AppColors.accentStrong,
      margin: .zero,
    ),
    css('.photo-challenges-name-header').styles(
      display: .flex,
      flexDirection: .column,
      alignItems: .center,
      gap: .all(6.px),
    ),
    css('.photo-challenges-rename-toggle', [
      css('&').styles(
        padding: .zero,
        border: .unset,
        backgroundColor: Colors.transparent,
        color: AppColors.textMuted,
        fontSize: .8125.rem,
        textDecoration: TextDecoration(line: TextDecorationLine.underline),
        cursor: .pointer,
      ),
      css('&:hover').styles(color: AppColors.accentStrong),
    ]),
    css('.photo-challenges-rename', [
      css('&').styles(
        display: .flex,
        flexDirection: .column,
        alignItems: .center,
        gap: .all(8.px),
        width: 100.percent,
        maxWidth: 360.px,
        padding: .all(16.px),
        backgroundColor: AppColors.bgElevated,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
      ),
      css('input').styles(
        width: 100.percent,
        padding: .symmetric(vertical: 10.px, horizontal: 14.px),
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
        backgroundColor: AppColors.bg,
        color: AppColors.text,
        fontFamily: AppFonts.body,
      ),
    ]),
    css('.photo-challenges-rename-error').styles(
      margin: .zero,
      color: AppColors.accentStrong,
      fontSize: .8125.rem,
      fontWeight: .w600,
    ),
    css('.photo-challenges-rename-actions').styles(
      display: .flex,
      gap: .all(8.px),
    ),
    css('.photo-challenges-list').styles(
      display: .flex,
      flexDirection: .column,
      gap: .all(8.px),
      width: 100.percent,
      maxWidth: 480.px,
    ),
    css('.photo-challenge-item', [
      css('&').styles(
        display: .flex,
        alignItems: .center,
        gap: .all(10.px),
        padding: .symmetric(vertical: 10.px, horizontal: 14.px),
        backgroundColor: AppColors.bgElevated,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
        color: AppColors.textMuted,
        cursor: .pointer,
      ),
      css('&.selected').styles(
        border: .all(style: .solid, color: AppColors.accent, width: 1.px),
        backgroundColor: AppColors.bgSoft,
      ),
    ]),
    css('.photo-challenge-check').styles(
      color: AppColors.accentStrong,
      fontWeight: .w700,
    ),
    css('.photo-challenges-done').styles(
      color: AppColors.accentStrong,
      fontWeight: .w600,
      textAlign: .center,
      margin: .zero,
    ),
    css('.photo-challenges-next').styles(
      display: .flex,
      flexDirection: .column,
      alignItems: .center,
      gap: .all(12.px),
      width: 100.percent,
      maxWidth: 480.px,
    ),
    css('.photo-challenges-actions').styles(
      display: .flex,
      flexWrap: .wrap,
      justifyContent: .center,
      gap: .all(10.px),
    ),
    css('.photo-challenges-action', [
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
        cursor: .progress,
      ),
      css('&.secondary').styles(
        backgroundColor: Colors.transparent,
        color: AppColors.textMuted,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
      ),
      css('&.secondary:hover').styles(
        backgroundColor: AppColors.bgElevated,
        color: AppColors.text,
      ),
    ]),
    css('.photo-challenges-custom', [
      css('&').styles(
        display: .flex,
        flexDirection: .column,
        gap: .all(8.px),
        width: 100.percent,
        padding: .all(16.px),
        backgroundColor: AppColors.bgElevated,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
      ),
      css('input').styles(
        padding: .symmetric(vertical: 10.px, horizontal: 14.px),
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
        backgroundColor: AppColors.bg,
        color: AppColors.text,
        fontFamily: AppFonts.body,
      ),
    ]),
    css('.photo-challenges-custom-hint').styles(
      margin: .zero,
      color: AppColors.textMuted,
      fontSize: .8125.rem,
    ),
    css('.photo-challenges-custom-error').styles(
      margin: .zero,
      color: AppColors.accentStrong,
      fontSize: .8125.rem,
      fontWeight: .w600,
    ),
    css('.photo-challenges-custom-active', [
      css('&').styles(
        display: .flex,
        flexDirection: .column,
        alignItems: .center,
        gap: .all(10.px),
        width: 100.percent,
        maxWidth: 480.px,
        padding: .all(16.px),
        backgroundColor: AppColors.bgSoft,
        border: .all(style: .solid, color: AppColors.accent, width: 1.px),
        radius: .circular(AppRadius.md),
        textAlign: .center,
      ),
      css('.photo-challenges-custom-active-text').styles(
        margin: .zero,
        color: AppColors.text,
        fontWeight: .w600,
      ),
    ]),
    // Histórico recolhido: o que já foi enviado não pode competir por espaço
    // com os desafios pendentes nem com o álbum.
    css('.photo-challenges-history', [
      css('&').styles(
        display: .flex,
        flexDirection: .column,
        gap: .all(8.px),
        width: 100.percent,
        maxWidth: 480.px,
      ),
      css('.photo-challenges-history-toggle', [
        css('&').styles(
          padding: .symmetric(vertical: 8.px, horizontal: 12.px),
          border: .unset,
          radius: .circular(AppRadius.md),
          backgroundColor: Colors.transparent,
          color: AppColors.textMuted,
          fontSize: .875.rem,
          textAlign: .left,
          cursor: .pointer,
        ),
        css('&:hover').styles(color: AppColors.text),
      ]),
      css('.photo-challenges-history-list').styles(
        display: .flex,
        flexDirection: .column,
        gap: .all(6.px),
        margin: .zero,
        padding: .all(4.px),
        listStyle: .none,
        maxHeight: 220.px,
        overflow: .only(y: .auto),
      ),
      css('.photo-challenges-history-item').styles(
        display: .flex,
        alignItems: .center,
        gap: .all(8.px),
        padding: .symmetric(vertical: 8.px, horizontal: 12.px),
        backgroundColor: AppColors.bgElevated,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
        color: AppColors.textMuted,
        fontSize: .875.rem,
      ),
      css('.photo-challenges-history-tag').styles(
        padding: .symmetric(vertical: 2.px, horizontal: 8.px),
        radius: .circular(999.px),
        backgroundColor: AppColors.bgSoft,
        color: AppColors.accentStrong,
        fontSize: .75.rem,
        whiteSpace: .noWrap,
      ),
    ]),
    css('.photo-challenges-upload-error').styles(
      color: AppColors.accentStrong,
      backgroundColor: AppColors.bgElevated,
      border: .all(style: .solid, color: AppColors.accentStrong, width: 1.px),
      radius: .circular(AppRadius.md),
      padding: .symmetric(vertical: 10.px, horizontal: 14.px),
      textAlign: .center,
      fontWeight: .w600,
      width: 100.percent,
      maxWidth: 480.px,
    ),
  ];
}
