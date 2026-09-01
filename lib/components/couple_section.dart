import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../constants/theme.dart';
import '../constants/wedding_data.dart';

class CoupleSection extends StatelessComponent {
  const CoupleSection({super.key});

  @override
  Component build(BuildContext context) {
    return section(id: 'casal', classes: 'couple', [
      h2(classes: 'section-title', [.text('O Casal')]),
      div(classes: 'couple-grid', [
        _bioCard(brideBio),
        div(classes: 'couple-heart', [.text('♥')]),
        _bioCard(groomBio),
      ]),
    ]);
  }

  Component _bioCard(BioInfo info) {
    return div(classes: 'bio-card', [
      div(classes: 'bio-avatar', [.text(info.emoji)]),
      h3([.text(info.name)]),
      p([.text(info.bio)]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.couple', [
      css('&').styles(backgroundColor: AppColors.bg),
      css('.section-title').styles(
        textAlign: .center,
        fontSize: 2.5.rem,
        color: AppColors.accentStrong,
        margin: .only(bottom: 48.px),
      ),
      css('.couple-grid').styles(
        display: .flex,
        alignItems: .center,
        justifyContent: .center,
        gap: .all(32.px),
        flexWrap: .wrap,
        maxWidth: 960.px,
        margin: .symmetric(horizontal: Unit.expression('auto')),
      ),
      css('.couple-heart').styles(
        fontSize: 2.5.rem,
        color: AppColors.accent,
      ),
      css('.bio-card').styles(
        display: .flex,
        flexDirection: .column,
        alignItems: .center,
        textAlign: .center,
        backgroundColor: AppColors.bgElevated,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.lg),
        padding: .all(32.px),
        maxWidth: 340.px,
        shadow: BoxShadow(
          offsetX: .zero,
          offsetY: 8.px,
          blur: 24.px,
          color: AppColors.shadow,
        ),
      ),
      css('.bio-avatar').styles(
        fontSize: 3.rem,
        margin: .only(bottom: 12.px),
      ),
      css('.bio-card h3').styles(
        fontSize: 22.px,
        color: AppColors.text,
        margin: .only(bottom: 8.px),
      ),
      css('.bio-card p').styles(
        color: AppColors.textMuted,
        lineHeight: Unit.expression('1.6'),
      ),
    ]),
  ];
}
