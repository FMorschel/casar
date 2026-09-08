// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:casar/components/challenge_reveal.dart' as _challenge_reveal;
import 'package:casar/components/countdown.dart' as _countdown;
import 'package:casar/components/couple_section.dart' as _couple_section;
import 'package:casar/components/footer.dart' as _footer;
import 'package:casar/components/gift_list.dart' as _gift_list;
import 'package:casar/components/guest_name_gate.dart' as _guest_name_gate;
import 'package:casar/components/hero.dart' as _hero;
import 'package:casar/components/loading_indicator.dart' as _loading_indicator;
import 'package:casar/components/navbar.dart' as _navbar;
import 'package:casar/components/photo_capture.dart' as _photo_capture;
import 'package:casar/components/photo_gallery.dart' as _photo_gallery;
import 'package:casar/components/theme_toggle.dart' as _theme_toggle;
import 'package:casar/components/toast.dart' as _toast;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  clientId: 'main.client.dart.js',
  clients: {
    _countdown.Countdown: ClientTarget<_countdown.Countdown>('countdown'),
    _gift_list.GiftList: ClientTarget<_gift_list.GiftList>('gift_list'),
    _theme_toggle.ThemeToggle: ClientTarget<_theme_toggle.ThemeToggle>(
      'theme_toggle',
    ),
  },
  styles: () => [
    ..._challenge_reveal.ChallengeRevealState.styles,
    ..._countdown.CountdownState.styles,
    ..._couple_section.CoupleSection.styles,
    ..._footer.Footer.styles,
    ..._gift_list.GiftListState.styles,
    ..._guest_name_gate.GuestNameGateState.styles,
    ..._hero.Hero.styles,
    ..._loading_indicator.LoadingIndicator.styles,
    ..._navbar.Navbar.styles,
    ..._photo_capture.PhotoCaptureState.styles,
    ..._photo_gallery.PhotoGalleryState.styles,
    ..._theme_toggle.ThemeToggleState.styles,
    ..._toast.Toast.styles,
    ..._toast.ToastStack.styles,
  ],
);
