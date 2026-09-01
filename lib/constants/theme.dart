import 'package:jaspr/dom.dart';

/// Design tokens shared across the site.
///
/// Colors and fonts are exposed as CSS variables so the light/dark toggle
/// can swap the whole palette instantly without re-rendering any component.
class AppColors {
  static const bg = Color.variable('--bg');
  static const bgSoft = Color.variable('--bg-soft');
  static const bgElevated = Color.variable('--bg-elevated');
  static const text = Color.variable('--text');
  static const textMuted = Color.variable('--text-muted');
  static const accent = Color.variable('--accent');
  static const accentStrong = Color.variable('--accent-strong');
  static const secondary = Color.variable('--secondary');
  static const border = Color.variable('--border');
  static const shadow = Color.variable('--shadow');
}

class AppFonts {
  static const heading = FontFamily.variable('--font-heading');
  static const body = FontFamily.variable('--font-body');
}

class AppRadius {
  static const lg = Unit.variable('--radius-lg');
  static const md = Unit.variable('--radius-md');
}

const _lightVars = {
  '--bg': '#fff9f5',
  '--bg-soft': '#fdedf0',
  '--bg-elevated': '#ffffff',
  '--text': '#3a2c2e',
  '--text-muted': '#8a7570',
  '--accent': '#c26b7a',
  '--accent-strong': '#a94f61',
  '--secondary': '#7f9b7e',
  '--border': '#f0dfd9',
  '--shadow': 'rgba(60, 30, 40, 0.10)',
  '--font-heading': "'Playfair Display', 'Cormorant Garamond', serif",
  '--font-body': "'Lora', Georgia, serif",
  '--radius-lg': '28px',
  '--radius-md': '16px',
  '--toggle-icon': "'🌸'",
};

const _darkVars = {
  '--bg': '#0a0e14',
  '--bg-soft': '#111823',
  '--bg-elevated': '#141d29',
  '--text': '#d6e3da',
  '--text-muted': '#7c93a3',
  '--accent': '#39d98a',
  '--accent-strong': '#22c55e',
  '--secondary': '#7aa2f7',
  '--border': '#1f2b3a',
  '--shadow': 'rgba(0, 0, 0, 0.55)',
  '--font-heading': "'JetBrains Mono', 'Fira Code', monospace",
  '--font-body': "'JetBrains Mono', 'Fira Code', monospace",
  '--radius-lg': '10px',
  '--radius-md': '6px',
  '--toggle-icon': "'</>'",
};

/// Global style rules: fonts import, css variables for both themes, and
/// base element styles. Meant to be included once in the root [Document].
List<StyleRule> get themeStyles => [
  css.import(
    'https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,500;0,700;1,600&family=Cormorant+Garamond:ital@0;1&family=Lora:ital@0;1&family=JetBrains+Mono:wght@400;500;700&display=swap',
  ),

  css(':root').styles(raw: _lightVars),
  css('[data-theme="dark"]').styles(raw: _darkVars),
  css.media(MediaQuery.all(prefersColorScheme: ColorScheme.dark), [
    css(':root:not([data-theme="light"])').styles(raw: _darkVars),
  ]),

  css('*').styles(boxSizing: .borderBox),
  css('html, body').styles(
    padding: .zero,
    margin: .zero,
    width: 100.percent,
    minHeight: 100.vh,
    backgroundColor: AppColors.bg,
    color: AppColors.text,
    fontFamily: AppFonts.body,
    transition: Transition.combine([
      Transition('background-color', duration: 300.ms),
      Transition('color', duration: 300.ms),
    ]),
  ),
  css('h1, h2, h3, h4, .heading-font').styles(
    fontFamily: AppFonts.heading,
    margin: .zero,
  ),
  css('a').styles(color: AppColors.accentStrong),
  css('button').styles(fontFamily: AppFonts.body),
  css('section').styles(
    boxSizing: .borderBox,
    padding: .symmetric(vertical: 64.px, horizontal: 24.px),
  ),
];
