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

  void _capture() {
    final video =
        web.document.getElementById(_videoId) as web.HTMLVideoElement?;
    final canvas =
        web.document.getElementById(_canvasId) as web.HTMLCanvasElement?;
    if (video == null || canvas == null) return;

    final width = video.videoWidth;
    final height = video.videoHeight;
    if (width == 0 || height == 0) return;
    canvas.width = width;
    canvas.height = height;

    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(video, 0, 0);
    final dataUrl = canvas.toDataURL('image/jpeg', 0.85.toJS);

    _stopCamera();
    setState(() => _capturedDataUrl = dataUrl);
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
      if (_error case final error?)
        p(classes: 'photo-capture-error', [.text(error)]),
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
          ])
        else if (_stream != null)
          button(
            classes: 'photo-capture-switch',
            onClick: _switchCamera,
            attributes: const {'aria-label': 'Trocar câmera'},
            [.text('🔄')],
          ),
        Component.element(
          tag: 'canvas',
          id: _canvasId,
          styles: Styles(raw: const {'display': 'none'}),
          children: const [],
        ),
      ]),
      div(classes: 'photo-capture-actions', [
        if (captured == null)
          button(
            onClick: _capture,
            attributes: {if (_stream == null) 'disabled': ''},
            [.text('Capturar')],
          )
        else ...[
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
      css('&').styles(
        display: .flex,
        flexDirection: .column,
        alignItems: .center,
        gap: .all(16.px),
        padding: .all(16.px),
      ),
      css('.photo-capture-error').styles(
        color: AppColors.accentStrong,
        fontSize: 13.px,
        textAlign: .center,
      ),
      css('.photo-capture-stage', [
        css('&').styles(
          position: const Position.relative(),
          width: 100.percent,
          maxWidth: 420.px,
          minHeight: 240.px,
          radius: .circular(AppRadius.md),
          overflow: .hidden,
          backgroundColor: AppColors.bgSoft,
        ),
        css('video, .photo-capture-preview').styles(
          width: 100.percent,
          height: Unit.expression('auto'),
          display: .block,
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
        css('.photo-capture-switch').styles(
          position: Position.absolute(top: 12.px, right: 12.px),
          width: 40.px,
          height: 40.px,
          radius: .circular(50.percent),
          border: .unset,
          backgroundColor: const Color.rgba(0, 0, 0, 0.45),
          color: Colors.white,
          fontSize: 18.px,
          cursor: .pointer,
        ),
      ]),
      css('.photo-capture-actions').styles(
        display: .flex,
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
      css('.photo-capture-retake').styles(
        backgroundColor: AppColors.bgElevated,
        color: AppColors.accentStrong,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
      ),
    ]),
  ];
}
