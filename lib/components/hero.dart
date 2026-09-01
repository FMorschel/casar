import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../constants/theme.dart';
import '../constants/wedding_data.dart';
import 'countdown.dart';

class Hero extends StatelessComponent {
  const Hero({super.key});

  @override
  Component build(BuildContext context) {
    return section(id: 'topo', classes: 'hero', [
      span(classes: 'hero-kicker heading-font', [.text('Nós vamos nos casar')]),
      h1(classes: 'hero-title', [.text('$brideName & $groomName')]),
      p(classes: 'hero-date', [.text('18 de setembro de 2026 · $venueName')]),
      const Countdown(),
      a(href: '#presentes', classes: 'hero-cta', [
        .text('Ver lista de presentes'),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.hero', [
      css('&').styles(
        display: .flex,
        flexDirection: .column,
        alignItems: .center,
        justifyContent: .center,
        gap: .all(20.px),
        textAlign: .center,
        minHeight: 90.vh,
        padding: .symmetric(vertical: 96.px, horizontal: 24.px),
        raw: {
          'background-image':
              'linear-gradient(160deg, var(--bg-soft), var(--bg))',
        },
      ),
      css('.hero-kicker').styles(
        fontSize: 16.px,
        fontStyle: .italic,
        color: AppColors.accentStrong,
        letterSpacing: 2.px,
      ),
      css('.hero-title').styles(
        fontSize: Unit.expression('clamp(2.75rem, 6vw, 5.5rem)'),
        color: AppColors.text,
      ),
      css('.hero-date').styles(
        fontSize: 18.px,
        color: AppColors.textMuted,
        margin: .only(bottom: 12.px),
      ),
      css('.hero-cta').styles(
        display: .inlineBlock,
        margin: .only(top: 12.px),
        padding: .symmetric(vertical: 14.px, horizontal: 32.px),
        backgroundColor: AppColors.accent,
        color: Colors.white,
        textDecoration: .none,
        fontWeight: .w700,
        radius: .circular(AppRadius.lg),
        shadow: BoxShadow(
          offsetX: .zero,
          offsetY: 6.px,
          blur: 20.px,
          color: AppColors.shadow,
        ),
        transition: Transition('transform', duration: 150.ms),
      ),
      css('.hero-cta:hover').styles(transform: .translate(y: (-2).px)),
    ]),
  ];
}
