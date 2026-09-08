// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:casar/components/countdown.dart' as _countdown;
import 'package:casar/components/couple_section.dart' as _couple_section;
import 'package:casar/components/footer.dart' as _footer;
import 'package:casar/components/gift_list.dart' as _gift_list;
import 'package:casar/components/hero.dart' as _hero;
import 'package:casar/components/navbar.dart' as _navbar;
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
    ..._countdown.CountdownState.styles,
    ..._couple_section.CoupleSection.styles,
    ..._footer.Footer.styles,
    ..._gift_list.GiftListState.styles,
    ..._hero.Hero.styles,
    ..._navbar.Navbar.styles,
    ..._theme_toggle.ThemeToggleState.styles,
    ..._toast.Toast.styles,
    ..._toast.ToastStack.styles,
  ],
);
