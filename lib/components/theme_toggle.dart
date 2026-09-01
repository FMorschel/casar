import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../constants/theme.dart';

const _storageKey = 'casar-theme';

@client
class ThemeToggle extends StatefulComponent {
  const ThemeToggle({super.key});

  @override
  State<ThemeToggle> createState() => ThemeToggleState();
}

class ThemeToggleState extends State<ThemeToggle> {
  bool isDark = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final stored = web.window.localStorage.getItem(_storageKey);
      final prefersDark = web.window
          .matchMedia('(prefers-color-scheme: dark)')
          .matches;
      isDark = stored != null ? stored == 'dark' : prefersDark;
      _applyToDocument();
    }
  }

  void _applyToDocument() {
    web.document.documentElement?.setAttribute(
      'data-theme',
      isDark ? 'dark' : 'light',
    );
  }

  void _toggle() {
    setState(() => isDark = !isDark);
    web.window.localStorage.setItem(_storageKey, isDark ? 'dark' : 'light');
    _applyToDocument();
  }

  @override
  Component build(BuildContext context) {
    return button(
      classes: 'theme-toggle',
      onClick: _toggle,
      attributes: {
        'aria-label': isDark
            ? 'Mudar para modo florido'
            : 'Mudar para modo dev',
      },
      [
        span(classes: 'theme-toggle-icon', [.text(isDark ? '</>' : '🌸')]),
        span(classes: 'theme-toggle-label', [
          .text(isDark ? 'modo dev' : 'modo flor'),
        ]),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.theme-toggle', [
      css('&').styles(
        display: .flex,
        alignItems: .center,
        gap: .all(8.px),
        padding: .symmetric(vertical: 8.px, horizontal: 16.px),
        border: .all(style: .solid, color: AppColors.border, width: 1.px),
        radius: .circular(AppRadius.lg),
        backgroundColor: AppColors.bgElevated,
        color: AppColors.text,
        cursor: .pointer,
        fontSize: 14.px,
        fontWeight: .w600,
        shadow: BoxShadow(
          offsetX: .zero,
          offsetY: 2.px,
          blur: 8.px,
          color: AppColors.shadow,
        ),
        transition: Transition.combine([
          Transition('transform', duration: 150.ms),
          Transition('background-color', duration: 300.ms),
        ]),
      ),
      css('&:hover').styles(transform: .scale(1.05)),
      css('.theme-toggle-icon').styles(fontSize: 16.px),
    ]),
  ];
}
