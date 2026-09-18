import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/js_interop.dart';
import 'package:universal_web/web.dart' as web;

import '../constants/theme.dart';

/// Câmera ao vivo + instantâneo para um único desafio (FR-11, FR-12).
///
/// Nunca abre o app de câmera do sistema nem a galeria: usa `getUserMedia`
/// para mostrar o vídeo ao vivo e um `<canvas>` para tirar o instantâneo.
/// Depois de capturar, mostra a prévia com opções de confirmar ou tirar de
/// novo (sem limite de tentativas); ao confirmar, chama [onConfirmed] com o
/// `data:image/...;base64,...` do instantâneo.
///
/// Não é `@client`: só é montado dentro da subárvore de um componente
/// `@client` já existente, então [onConfirmed] pode ser um callback comum.
class PhotoCapture extends StatefulComponent {
  const PhotoCapture({required this.onConfirmed, super.key});

  final ValueChanged<String> onConfirmed;

  @override
  State<PhotoCapture> createState() => PhotoCaptureState();
}

class PhotoCaptureState extends State<PhotoCapture> {
  /// Ids únicos por instância: pode haver, em teoria, mais de um capturador
  /// montado ao mesmo tempo (troca rápida de desafio).
  late final String _videoId = 'photo-capture-video-${identityHashCode(this)}';
  late final String _canvasId =
      'photo-capture-canvas-${identityHashCode(this)}';
  late final String _nativeInputId =
      'photo-capture-native-${identityHashCode(this)}';

  web.MediaStream? _stream;
  web.MediaStreamTrack? _videoTrack;
  String? _capturedDataUrl;
  String? _error;
  bool _starting = false;

  /// Câmera preferida: traseira por padrão (fotos são dos desafios, não
  /// selfies). Alternada pelo botão de trocar câmera.
  String _facingMode = 'environment';

  /// Se a câmera atual expõe a lanterna via `getCapabilities()`. Só a
  /// traseira costuma ter — a frontal não fica perto do LED de flash.
  bool _hasTorch = false;

  /// Intenção do usuário ("flash ligado"), não o estado físico da lanterna:
  /// ela só é acesa no instante da captura, nunca fica ligada olhando o
  /// enquadramento (queimaria bateria e cegaria quem está posando).
  bool _flashOn = false;

  /// Tela branca da câmera frontal durante a captura, simulando um flash
  /// que ela não tem de verdade.
  bool _flashActive = false;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    if (!kIsWeb || _starting) return;
    _starting = true;
    try {
      final constraints = web.MediaStreamConstraints(
        video: web.MediaTrackConstraints(
          facingMode: web.ConstrainDOMStringParameters(
            ideal: _facingMode.toJS,
          ),
        ),
        audio: false.toJS,
      );
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      if (!mounted) {
        for (final track in stream.getTracks().toDart) {
          track.stop();
        }
        return;
      }
      final video =
          web.document.getElementById(_videoId) as web.HTMLVideoElement?;
      if (video != null) {
        video.srcObject = stream;
      }
      final tracks = stream.getVideoTracks().toDart;
      final track = tracks.isEmpty ? null : tracks.first;
      // `getCapabilities()` só inclui a chave `torch` quando o hardware
      // realmente suporta lanterna. O binding do `universal_web` tipa essa
      // propriedade como `JSArray<JSBoolean>` (a IDL antiga), mas o Chrome
      // no Android devolve um `boolean` puro — chamar `.toDart` nesse valor
      // não dá exceção, só lê um `.length` inexistente e volta uma lista
      // vazia, fazendo a lanterna traseira nunca ser detectada. `dartify()`
      // aceita os dois formatos (bool ou lista) sem assumir qual é.
      var hasTorch = false;
      if (track != null) {
        try {
          final capabilities = track.getCapabilities();
          final torch = capabilities.torch.dartify();
          hasTorch = switch (torch) {
            true => true,
            List() => torch.isNotEmpty,
            _ => false,
          };
          // Diagnóstico temporário: alguns Android relatam suporte a
          // lanterna via hardware, mas o Chrome não expõe `torch` em
          // `getCapabilities()` para aquele device/driver de câmera — sem
          // isso no console não dá para distinguir esse caso de um bug real
          // na deteção. Ver via `chrome://inspect` com o cabo USB.
          web.console.log(
            'photo-capture: track=${track.label} facingMode=$_facingMode '
                    'torch=$torch capabilities='
                .toJS,
          );
          web.console.log(capabilities);
        } catch (error) {
          hasTorch = false;
          web.console.log(
            'photo-capture: getCapabilities() falhou: $error'.toJS,
          );
        }
      }
      setState(() {
        _stream = stream;
        _videoTrack = track;
        _hasTorch = hasTorch;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Não consegui acessar a câmera. Confira as permissões do '
            'navegador e tente de novo.';
      });
    } finally {
      _starting = false;
    }
  }

  /// Alterna entre a câmera traseira e a frontal.
  ///
  /// Mesma regra do [_capture]: nada aqui pode falhar em silêncio. Este botão
  /// já ficou quebrado sem dar um pio porque a exceção subia sem ninguém para
  /// pegá-la, e um botão mudo é indistinguível de um botão morto.
  void _switchCamera() {
    try {
      _stopCamera();
      _facingMode = _facingMode == 'environment' ? 'user' : 'environment';
      setState(() {
        _stream = null;
        _flashOn = false;
      });
      _startCamera();
    } catch (error) {
      setState(() => _error = 'Não deu para trocar de câmera: $error');
    }
  }

  void _stopCamera() {
    // O tipo do `track` fica explícito de propósito: com um `?? const []` o
    // Dart inferia `dynamic` aqui, e `track.stop()` virava uma chamada
    // dinâmica — que no JS compilado procura um método Dart minificado num
    // objeto puro do navegador e estoura `NoSuchMethodError`. Era isso que
    // quebrava `Capturar` e `Trocar câmera` no celular.
    final stream = _stream;
    if (stream != null) {
      for (final web.MediaStreamTrack track in stream.getTracks().toDart) {
        track.stop();
      }
    }
    _stream = null;
    _videoTrack = null;
    _hasTorch = false;
  }

  /// Liga ou desliga a lanterna física da câmera traseira.
  ///
  /// Chamada só ao redor da captura (nunca fica ligada olhando o
  /// enquadramento), então um erro aqui não pode travar o fluxo de foto —
  /// por isso ela mesma não define [_error]; quem chama decide o que fazer.
  Future<void> _setTorch(bool on) async {
    final track = _videoTrack;
    if (track == null) return;
    await track
        .applyConstraints(
          web.MediaTrackConstraints(
            advanced: [web.MediaTrackConstraintSet(torch: on.toJS)].toJS,
          ),
        )
        .toDart;
  }

  /// Alterna a intenção de flash. Não liga a lanterna nem mostra a tela
  /// branca aqui — isso só acontece dentro de [_capture], no instante do
  /// instantâneo.
  void _toggleFlash() {
    setState(() => _flashOn = !_flashOn);
  }

  /// Tira o instantâneo.
  ///
  /// Nunca sai em silêncio: toda saída sem foto vira uma mensagem na tela.
  /// Um botão que não faz absolutamente nada ao ser tocado é
  /// indistinguível de um botão quebrado, e era exatamente assim que o
  /// `Capturar` se comportava no celular — sem nenhuma pista de qual das
  /// saídas tinha sido tomada.
  Future<void> _capture() async {
    // Nenhum dos dois flashes fica ligado se o instantâneo falhar antes de
    // desligá-los — daí viverem fora do try, num `finally`.
    var torchLit = false;
    try {
      final video =
          web.document.getElementById(_videoId) as web.HTMLVideoElement?;
      final canvas =
          web.document.getElementById(_canvasId) as web.HTMLCanvasElement?;
      if (video == null || canvas == null) {
        setState(() {
          _error =
              'Não achei a câmera nesta tela. Recarregue a página e tente '
              'de novo.';
        });
        return;
      }

      final width = video.videoWidth;
      final height = video.videoHeight;
      if (width == 0 || height == 0) {
        setState(() {
          _error =
              'A câmera ainda está abrindo. Espere um instante e toque em '
              'Capturar de novo.';
        });
        return;
      }

      // A traseira usa a lanterna de verdade; a frontal não tem uma, então
      // a tela inteira vira flash por um instante.
      if (_flashOn && _facingMode == 'environment' && _hasTorch) {
        await _setTorch(true);
        torchLit = true;
      } else if (_flashOn && _facingMode == 'user') {
        if (!mounted) return;
        setState(() => _flashActive = true);
      }
      if (torchLit || _flashActive) {
        // Tempo para a lanterna acender de fato ou para a tela branca
        // clarear o rosto antes de congelar o quadro do vídeo.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted) return;

      canvas.width = width;
      canvas.height = height;

      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.drawImage(video, 0, 0);
      // PNG em vez de JPEG: sem compressão com perda, guarda o instantâneo
      // na qualidade máxima que a câmera devolveu. HEIC não é uma opção —
      // nenhum navegador expõe esse formato em `canvas.toDataURL`/`toBlob`.
      final dataUrl = canvas.toDataURL('image/png');

      if (torchLit || _flashActive) {
        // Mantém o flash mais um tanto depois do quadro já ter sido
        // congelado: um clarão de meio segundo é fácil de perder de vista,
        // sobretudo o branco de tela simulado na frontal.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted) return;

      _stopCamera();
      setState(() {
        _capturedDataUrl = dataUrl;
        _flashActive = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _flashActive = false;
        _error = 'Não deu para tirar a foto: $error';
      });
    } finally {
      if (torchLit) {
        // A lanterna some de qualquer jeito quando `_stopCamera` para a
        // track, mas desligar explicitamente evita um clarão residual caso
        // o instantâneo falhe antes de chegar lá.
        unawaited(_setTorch(false));
      }
    }
  }

  void _retake() {
    setState(() => _capturedDataUrl = null);
    _startCamera();
  }

  void _confirm() {
    if (_capturedDataUrl case final dataUrl?) {
      component.onConfirmed(dataUrl);
    }
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final captured = _capturedDataUrl;
    return div(classes: 'photo-capture', [
      div(classes: 'photo-capture-stage', [
        video(
          [],
          id: _videoId,
          autoplay: true,
          muted: true,
          attributes: const {'playsinline': ''},
          styles: Styles(
            raw: {
              'display': captured == null ? 'block' : 'none',
            },
          ),
        ),
        if (captured case final dataUrl?)
          img(
            src: dataUrl,
            classes: 'photo-capture-preview',
            alt: 'Prévia da foto',
          )
        else if (_stream == null && !_starting)
          div(classes: 'photo-capture-permission', [
            button(
              onClick: _startCamera,
              [.text('Permitir acesso à câmera')],
            ),
          ]),
        Component.element(
          tag: 'canvas',
          id: _canvasId,
          styles: Styles(raw: const {'display': 'none'}),
          children: const [],
        ),
      ]),
      // Fora do palco de propósito: um flash de tela só ilumina de verdade
      // se a tela inteira acender, não só a prévia de 420px no meio da
      // página. `position: fixed` cobre a viewport inteira independente de
      // onde este componente está aninhado.
      div(
        classes: 'photo-capture-flash-overlay',
        styles: Styles(
          raw: {'opacity': _flashActive ? '1' : '0'},
        ),
        [],
      ),
      if (_error case final error?)
        p(classes: 'photo-capture-error', [.text(error)]),
      // Nenhum botão fica por cima do vídeo: no Android a camada de vídeo
      // costuma ser promovida para uma superfície do próprio sistema, que
      // pinta acima do HTML e engole o toque de quem estiver em cima dela.
      // Por isso trocar de câmera saiu de dentro do palco e virou um botão
      // ao lado de capturar.
      div(classes: 'photo-capture-actions', [
        if (captured == null) ...[
          button(
            onClick: _capture,
            attributes: {if (_stream == null) 'disabled': ''},
            [.text('Capturar')],
          ),
          Component.element(
            tag: 'input',
            id: _nativeInputId,
            attributes: const {
              'type': 'file',
              'accept': 'image/*',
              'capture': 'environment',
            },
            styles: Styles(raw: const {'display': 'none'}),
            events: {
              'change': (e) {
                final input = web.document.getElementById(_nativeInputId)
                    as web.HTMLInputElement?;
                if (input == null) return;
                final files = input.files;
                if (files != null && files.length > 0) {
                  final file = files.item(0)!;
                  final reader = web.FileReader();
                  reader.onload = ((web.Event event) {
                    final res = reader.result;
                    if (res != null) {
                      if (!mounted) return;
                      _stopCamera();
                      setState(() {
                        _capturedDataUrl = res.dartify() as String;
                        _flashActive = false;
                        _error = null;
                      });
                    }
                  }).toJS;
                  reader.onerror = ((web.Event event) {
                    if (!mounted) return;
                    setState(() {
                      _error = 'Erro ao ler a foto nativa.';
                    });
                  }).toJS;
                  reader.readAsDataURL(file);
                }
              },
            },
          ),
          label(
            htmlFor: _nativeInputId,
            classes: 'photo-capture-native',
            [.text('📸 Câmera Nativa')],
          ),
          if (_stream != null)
            button(
              classes: 'photo-capture-switch',
              onClick: _switchCamera,
              attributes: const {'aria-label': 'Trocar câmera'},
              [.text('🔄 Trocar câmera')],
            ),
          // Só aparece quando o flash faz algo de verdade: lanterna na
          // traseira quando o hardware suporta, ou tela branca simulada na
          // frontal (que nunca tem lanterna perto do sensor).
          if (_stream != null && (_hasTorch || _facingMode == 'user'))
            button(
              classes:
                  'photo-capture-flash${_flashOn ? ' photo-capture-flash-on' : ''}',
              onClick: _toggleFlash,
              attributes: const {'aria-label': 'Ligar/desligar flash'},
              [.text(_flashOn ? '⚡ Flash ligado' : '⚡ Flash')],
            ),
        ] else ...[
          button(onClick: _confirm, [.text('Confirmar')]),
          button(
            classes: 'photo-capture-retake',
            onClick: _retake,
            [.text('Tirar de novo')],
          ),
        ],
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.photo-capture', [
      // Sem a largura explícita o capturador seria dimensionado pelo próprio
      // conteúdo (o palco de 420px) e estouraria a tela em celulares
      // estreitos, levando o botão de trocar câmera para fora dela.
      css('&').styles(
        display: .flex,
        flexDirection: .column,
        alignItems: .center,
        gap: .all(16.px),
        width: 100.percent,
        maxWidth: 420.px,
        padding: .all(16.px),
      ),
      css('.photo-capture-error').styles(
        color: AppColors.accentStrong,
        fontSize: 13.px,
        textAlign: .center,
      ),
      css('.photo-capture-stage', [
        // A altura é limitada de propósito: a câmera de um celular devolve
        // um vídeo em pé, e sem teto ele empurraria os botões de capturar e
        // confirmar para muito abaixo da dobra.
        css('&').styles(
          position: const Position.relative(),
          display: .flex,
          alignItems: .center,
          justifyContent: .center,
          width: 100.percent,
          maxWidth: 420.px,
          minHeight: 240.px,
          maxHeight: 50.vh,
          raw: const {'max-height': '50svh'},
          radius: .circular(AppRadius.md),
          overflow: .hidden,
          backgroundColor: AppColors.bgSoft,
        ),
        css('video, .photo-capture-preview').styles(
          width: 100.percent,
          height: Unit.expression('auto'),
          maxHeight: 50.vh,
          display: .block,
          raw: const {'object-fit': 'contain'},
        ),
        css('.photo-capture-permission').styles(
          position: const Position.absolute(top: Unit.zero, left: Unit.zero),
          width: 100.percent,
          height: 100.percent,
          display: .flex,
          alignItems: .center,
          justifyContent: .center,
          padding: .all(16.px),
        ),
      ]),
      // Flash simulado da câmera frontal: fixo na viewport inteira (não só
      // no palco de 420px) — é a tela toda acendendo que ilumina o rosto de
      // quem está posando, não um retângulo no meio da página. Sem bloquear
      // toque (nada para tocar durante o clarão) e com uma transição curta
      // para não parecer um corte abrupto de tela.
      css('.photo-capture-flash-overlay').styles(
        position: const Position.fixed(top: Unit.zero, left: Unit.zero),
        width: 100.vw,
        height: 100.vh,
        backgroundColor: Colors.white,
        raw: const {
          'pointer-events': 'none',
          'transition': 'opacity 80ms ease-out',
          'z-index': '9999',
        },
      ),
      // Logo abaixo do palco, no fluxo normal — nunca sobrepondo o vídeo.
      // O teto de altura do palco é que mantém estes botões perto da dobra.
      css('.photo-capture-actions').styles(
        display: .flex,
        flexWrap: .wrap,
        justifyContent: .center,
        gap: .all(12.px),
      ),
      css('.photo-capture-actions button, .photo-capture-native', [
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
      css(
        '.photo-capture-retake, .photo-capture-switch, .photo-capture-flash, .photo-capture-native',
      ).styles(
        backgroundColor: AppColors.bgElevated,
        color: AppColors.accentStrong,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
      ),
      // Estado "ligado" com a mesma cor de destaque dos outros botões
      // primários, para não parecer apagado enquanto o flash está ativo.
      css('.photo-capture-flash-on').styles(
        backgroundColor: AppColors.accent,
        color: Colors.white,
        border: .unset,
      ),
    ]),
  ];
}
