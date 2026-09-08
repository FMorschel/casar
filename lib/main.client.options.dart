// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';

import 'package:casar/components/countdown.dart' deferred as _countdown;
import 'package:casar/components/gift_list.dart' deferred as _gift_list;
import 'package:casar/components/theme_toggle.dart' deferred as _theme_toggle;
import 'package:casar/pages/photo_challenges_page.dart'
    deferred as _photo_challenges_page;

/// Default [ClientOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.client.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultClientOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ClientOptions get defaultClientOptions => ClientOptions(
  clients: {
    'countdown': ClientLoader(
      (p) => _countdown.Countdown(),
      loader: _countdown.loadLibrary,
    ),
    'gift_list': ClientLoader(
      (p) => _gift_list.GiftList(),
      loader: _gift_list.loadLibrary,
    ),
    'theme_toggle': ClientLoader(
      (p) => _theme_toggle.ThemeToggle(),
      loader: _theme_toggle.loadLibrary,
    ),
    'photo_challenges_page': ClientLoader(
      (p) => _photo_challenges_page.PhotoChallengesFlow(),
      loader: _photo_challenges_page.loadLibrary,
    ),
  },
);
