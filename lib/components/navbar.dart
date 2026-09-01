import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../constants/theme.dart';
import '../constants/wedding_data.dart';
import 'theme_toggle.dart';

class Navbar extends StatelessComponent {
  const Navbar({super.key});

  @override
  Component build(BuildContext context) {
    return nav(classes: 'navbar', [
      a(href: '#topo', classes: 'navbar-brand', [
        .text('$brideName & $groomName'),
      ]),
      div(classes: 'navbar-links', [
        a(href: '#casal', [.text('O Casal')]),
        a(href: '#presentes', [.text('Presentes')]),
      ]),
      const ThemeToggle(),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.navbar', [
      css('&').styles(
        position: .sticky(top: .zero),
        display: .flex,
        alignItems: .center,
        justifyContent: .spaceBetween,
        gap: .all(16.px),
        padding: .symmetric(vertical: 16.px, horizontal: 32.px),
        backgroundColor: AppColors.bg.withOpacity(0.85),
        border: .only(
          bottom: BorderSide(color: AppColors.border, width: 1.px),
        ),
        zIndex: ZIndex(10),
        backdropFilter: Filter.blur(8.px),
      ),
      css('.navbar-brand').styles(
        fontFamily: AppFonts.heading,
        fontSize: 20.px,
        fontWeight: .w700,
        color: AppColors.accentStrong,
        textDecoration: .none,
      ),
      css('.navbar-links').styles(
        display: .flex,
        gap: .all(24.px),
      ),
      css('.navbar-links a').styles(
        color: AppColors.textMuted,
        textDecoration: .none,
        fontSize: 15.px,
        fontWeight: .w600,
      ),
      css('.navbar-links a:hover').styles(color: AppColors.accentStrong),
      css.media(MediaQuery.all(maxWidth: 720.px), [
        css('.navbar-links').styles(display: .none),
      ]),
    ]),
  ];
}
