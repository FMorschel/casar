import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../constants/theme.dart';
import '../constants/wedding_data.dart';

@client
class Countdown extends StatefulComponent {
  const Countdown({super.key});

  @override
  State<Countdown> createState() => CountdownState();
}

class CountdownState extends State<Countdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    if (kIsWeb) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  Duration _computeRemaining() {
    final remaining = weddingDate.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _tick() {
    setState(() => _remaining = _computeRemaining());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return div(classes: 'countdown', [
      _unit(days, 'dias'),
      _separator(),
      _unit(hours, 'horas'),
      _separator(),
      _unit(minutes, 'min'),
      _separator(),
      _unit(seconds, 'seg'),
    ]);
  }

  Component _separator() => span(classes: 'countdown-sep', [.text(':')]);

  Component _unit(int value, String label) {
    return div(classes: 'countdown-unit', [
      span(classes: 'countdown-value', [
        .text(value.toString().padLeft(2, '0')),
      ]),
      span(classes: 'countdown-label', [.text(label)]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.countdown', [
      css('&').styles(
        display: .flex,
        alignItems: .center,
        justifyContent: .center,
        gap: .all(12.px),
        flexWrap: .wrap,
      ),
      css('.countdown-unit').styles(
        display: .flex,
        flexDirection: .column,
        alignItems: .center,
        justifyContent: .center,
        minWidth: 76.px,
        padding: .symmetric(vertical: 16.px, horizontal: 8.px),
        backgroundColor: AppColors.bgElevated,
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.md),
        shadow: BoxShadow(
          offsetX: .zero,
          offsetY: 4.px,
          blur: 16.px,
          color: AppColors.shadow,
        ),
      ),
      css('.countdown-value').styles(
        fontFamily: AppFonts.heading,
        fontSize: 2.5.rem,
        fontWeight: .w700,
        color: AppColors.accentStrong,
        lineHeight: Unit.expression('1.2'),
      ),
      css('.countdown-label').styles(
        fontSize: 12.px,
        color: AppColors.textMuted,
        textTransform: .upperCase,
        letterSpacing: 1.px,
        margin: .only(top: 4.px),
      ),
      css('.countdown-sep').styles(
        fontSize: 2.rem,
        color: AppColors.border,
        fontWeight: .w700,
      ),
      css.media(MediaQuery.all(maxWidth: 520.px), [
        css('&').styles(flexWrap: .nowrap, gap: .all(6.px)),
        css('.countdown-unit').styles(
          flex: const Flex(grow: 1, shrink: 1, basis: Unit.zero),
          minWidth: Unit.zero,
          padding: .symmetric(vertical: 12.px, horizontal: 4.px),
        ),
        css('.countdown-value').styles(fontSize: 1.75.rem),
        css('.countdown-label').styles(fontSize: 10.px, letterSpacing: .5.px),
        css('.countdown-sep').styles(display: .none),
      ]),
    ]),
  ];
}
