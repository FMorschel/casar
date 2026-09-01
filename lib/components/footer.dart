import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../constants/theme.dart';
import '../constants/wedding_data.dart';

class Footer extends StatelessComponent {
  const Footer({super.key});

  @override
  Component build(BuildContext context) {
    return footer(classes: 'site-footer', [
      p(classes: 'footer-names heading-font', [
        .text('$brideName & $groomName'),
      ]),
      p(classes: 'footer-hashtag', [.text(coupleHashtag)]),
      p(classes: 'footer-note', [
        .text('Feito com ♥ (e um pouco de Dart) para o nosso grande dia.'),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.site-footer', [
      css('&').styles(
        display: .flex,
        flexDirection: .column,
        alignItems: .center,
        gap: .all(8.px),
        padding: .symmetric(vertical: 48.px, horizontal: 24.px),
        backgroundColor: AppColors.bgSoft,
        border: .only(
          top: BorderSide(color: AppColors.border, width: 1.px),
        ),
        textAlign: .center,
      ),
      css(
        '.footer-names',
      ).styles(fontSize: 22.px, color: AppColors.accentStrong),
      css('.footer-hashtag').styles(color: AppColors.accent, fontWeight: .w600),
      css('.footer-note').styles(color: AppColors.textMuted, fontSize: 13.px),
    ]),
  ];
}
