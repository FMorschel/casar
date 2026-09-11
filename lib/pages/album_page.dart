import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/gallery_refresh_button.dart';
import '../components/loading_indicator.dart';
import '../components/photo_gallery.dart';
import '../components/theme_toggle.dart';
import '../components/toast.dart';
import '../constants/photo_challenges.dart';
import '../constants/theme.dart';
import '../utils/local_gallery.dart';
import '../utils/photo_challenges_api.dart';
import '../utils/preview_mode.dart';

/// Página de `/album`: só o álbum compartilhado das fotos dos desafios, sem
/// o portão de nome nem o sorteio de `/fotos` — para quem só quer ver (ou
/// receber um link direto para) as fotos.
///
/// Mesma regra de revelação de `/fotos` (FR-18): as fotos ficam borradas até
/// [photoRevealDate], em `constants/wedding_data.dart`.
class AlbumPage extends StatelessComponent {
  const AlbumPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'album-page', [
      div(classes: 'album-page-header', [const ThemeToggle()]),
      const AlbumFlow(),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    // Bloco comum, e não flex column, pelo mesmo motivo do cabeçalho de
    // `/fotos` (ver `photo_challenges_page.dart`): como flex item o
    // cabeçalho `sticky` largava o topo assim que o álbum carregava e a
    // página passava a rolar.
    css('.album-page').styles(minHeight: 100.vh),
    css('.album-page-header').styles(
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

/// Único ponto de hidratação (`@client`) da página, pelo mesmo motivo de
/// [PhotoChallengesFlow] em `/fotos`: um elemento só na raiz, para a
/// hidratação ancorar certo.
@client
class AlbumFlow extends StatefulComponent {
  const AlbumFlow({super.key});

  @override
  State<AlbumFlow> createState() => AlbumFlowState();
}

class AlbumFlowState extends State<AlbumFlow> {
  final _api = const PhotoChallengesApi();

  List<GalleryPhoto>? _galleryPhotos;
  bool _galleryLoading = false;
  bool _galleryRefreshing = false;
  bool _galleryRefreshFailed = false;

  String? _toastMessage;
  bool _toastIsError = false;
  Timer? _toastTimer;

  bool _disposed = false;

  /// Modo prévia ligado em `/fotos` neste navegador (ver
  /// `utils/preview_mode.dart`): também revela o álbum aqui, sem exigir
  /// digitar a senha de novo — não há portão de nome nesta página onde
  /// digitá-la.
  bool _forceRevealed = false;

  @override
  void initState() {
    super.initState();
    _forceRevealed = readPreviewMode();
    unawaited(_refreshGallery());
  }

  @override
  void dispose() {
    _disposed = true;
    _toastTimer?.cancel();
    super.dispose();
  }

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

  void _showToast(String message, {bool isError = false}) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastIsError = isError;
    });
    _toastTimer = Timer(const Duration(seconds: 3), () {
      _toastTimer = null;
      if (_disposed) return;
      setState(() => _toastMessage = null);
    });
  }

  /// Desliga o modo prévia (ver `utils/preview_mode.dart`): sem isso, quem
  /// abrisse `/album?previa=felipe+julia` uma vez (ou tivesse o modo prévia
  /// ligado de testar `/fotos` antes) ficaria vendo o álbum sem borrão para
  /// sempre neste navegador, sem nenhum jeito de desligar a partir desta
  /// página — `/fotos` tem o painel de prévia para isso, `/album` não tinha
  /// nenhum.
  void _exitPreviewMode() {
    writePreviewMode(enabled: false);
    setState(() => _forceRevealed = false);
  }

  /// Atualização pedida pelo visitante no botão flutuante.
  Future<void> _manualRefreshGallery() async {
    if (_galleryRefreshing) return;
    setState(() {
      _galleryRefreshing = true;
      _galleryRefreshFailed = false;
    });
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
    );
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'album-flow', [
      if (_forceRevealed)
        div(classes: 'album-preview-banner', [
          span([
            .text('Modo prévia ligado — o álbum está sem o borrão.'),
          ]),
          button(
            classes: 'album-preview-exit',
            attributes: const {'type': 'button'},
            onClick: _exitPreviewMode,
            [.text('Borrar de novo')],
          ),
        ]),
      if (_galleryLoading && _galleryPhotos == null)
        const LoadingIndicator('Carregando álbum…')
      else if (_galleryPhotos case final photos?)
        PhotoGallery(photos: photos, forceRevealed: _forceRevealed),
      if (_api.isEnabled)
        GalleryRefreshButton(
          onRefresh: _manualRefreshGallery,
          refreshing: _galleryRefreshing,
          failed: _galleryRefreshFailed,
        ),
      if (_toastMessage case final message?)
        ToastStack(
          toasts: [Toast(message: message, isError: _toastIsError)],
        ),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.album-flow').styles(
      display: .flex,
      flexDirection: .column,
      alignItems: .center,
      gap: .all(24.px),
      width: 100.percent,
      padding: .all(24.px),
    ),
    css('.album-preview-banner', [
      css('&').styles(
        display: .flex,
        flexWrap: .wrap,
        alignItems: .center,
        justifyContent: .center,
        gap: .all(12.px),
        width: 100.percent,
        maxWidth: 480.px,
        padding: .symmetric(vertical: 10.px, horizontal: 16.px),
        backgroundColor: AppColors.bgElevated,
        border: .all(style: .dashed, color: AppColors.textMuted, width: 1.px),
        radius: .circular(AppRadius.md),
        color: AppColors.textMuted,
        fontSize: .8125.rem,
      ),
      css('.album-preview-exit', [
        css('&').styles(
          padding: .symmetric(vertical: 6.px, horizontal: 14.px),
          border: .all(style: .solid, color: AppColors.border, width: 1.px),
          radius: .circular(AppRadius.md),
          backgroundColor: AppColors.bg,
          color: AppColors.text,
          fontFamily: AppFonts.body,
          fontSize: .8125.rem,
          cursor: .pointer,
        ),
        css('&:hover').styles(
          backgroundColor: AppColors.bgSoft,
          color: AppColors.accentStrong,
        ),
      ]),
    ]),
  ];
}
