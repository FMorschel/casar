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

  web.MediaStream? _stream;
  String? _capturedDataUrl;
  String? _error;
  bool _starting = false;

  /// Câmera preferida: traseira por padrão (fotos são dos desafios, não
  /// selfies). Alternada pelo botão de trocar câmera.
  String _facingMode = 'environment';

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
      setState(() {
        _stream = stream;
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

  void _switchCamera() {
    _stopCamera();
    _facingMode = _facingMode == 'environment' ? 'user' : 'environment';
    setState(() => _stream = null);
    _startCamera();
  }

  void _stopCamera() {
    for (final track in _stream?.getTracks().toDart ?? const []) {
      track.stop();
    }
    _stream = null;
  }

  /// Tira o instantâneo.
  ///
  /// Nunca sai em silêncio: toda saída sem foto vira uma mensagem na tela.
  /// Um botão que não faz absolutamente nada ao ser tocado é
  /// indistinguível de um botão quebrado, e era exatamente assim que o
  /// `Capturar` se comportava no celular — sem nenhuma pista de qual das
  /// saídas tinha sido tomada.
  void _capture() {
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
      canvas.width = width;
      canvas.height = height;

      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.drawImage(video, 0, 0);
      final dataUrl = canvas.toDataURL('image/jpeg', 0.85.toJS);

      _stopCamera();
      setState(() {
        _capturedDataUrl = dataUrl;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = 'Não deu para tirar a foto: $error');
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
          if (_stream != null)
            button(
              classes: 'photo-capture-switch',
              onClick: _switchCamera,
              attributes: const {'aria-label': 'Trocar câmera'},
              [.text('🔄 Trocar câmera')],
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
      // Logo abaixo do palco, no fluxo normal — nunca sobrepondo o vídeo.
      // O teto de altura do palco é que mantém estes botões perto da dobra.
      css('.photo-capture-actions').styles(
        display: .flex,
        flexWrap: .wrap,
        justifyContent: .center,
        gap: .all(12.px),
      ),
      css('.photo-capture-actions button', [
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
      css('.photo-capture-retake, .photo-capture-switch').styles(
        backgroundColor: AppColors.bgElevated,
        color: AppColors.accentStrong,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
      ),
    ]),
  ];
}
