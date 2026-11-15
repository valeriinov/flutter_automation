import 'package:flutter/material.dart';

/// {@category Utils}
///
/// The look of the panel: colors, shapes and type of the package style.
///
/// The panel never takes the theme of the app that hosts it. It wraps its
/// pages in [toThemeData], which carries this extension, so a block reads the
/// same tokens in any app. A block drawn outside the panel falls back to
/// [AutomationPanelTheme.light].
@immutable
final class AutomationPanelTheme extends ThemeExtension<AutomationPanelTheme> {
  /// Radius of a button, a field and a row.
  static const double buttonRadius = 14;

  /// Radius of a card.
  static const double cardRadius = 20;

  /// Radius of the top corners of a sheet.
  static const double sheetRadius = 28;

  /// Height of the main button.
  static const double primaryButtonHeight = 52;

  /// Height of any other button.
  static const double buttonHeight = 48;

  /// Smallest side of a target the finger hits.
  static const double touchTarget = 44;

  /// Spacing steps: small, medium and large.
  static const double gapSmall = 8;
  static const double gapMedium = 12;
  static const double gapLarge = 16;

  /// Background of a page.
  final Color background = const Color(0xFFF7F6F3);

  /// Background of a card, a header and a sheet.
  final Color surface = const Color(0xFFFFFFFF);

  /// Background of a quiet row inside a card.
  final Color surfaceQuiet = const Color(0xFFFAF9F7);

  /// Background of the track of a segmented control.
  final Color track = const Color(0xFFEDEBE6);

  /// Primary text.
  final Color text = const Color(0xFF1C1A17);

  /// Text of a request path.
  final Color textPath = const Color(0xFF45413B);

  /// Secondary text.
  final Color textSecondary = const Color(0xFF6B665E);

  /// Icons and marks that carry no meaning.
  final Color textMuted = const Color(0xFFA39E95);

  /// Hairline between blocks.
  final Color line = const Color(0xFFE7E4DE);

  /// Hairline between rows of a card.
  final Color lineSoft = const Color(0xFFF0EEEA);

  /// Border of a control.
  final Color lineStrong = const Color(0xFFD9D5CD);

  /// Accent of the panel.
  final Color accent = const Color(0xFF0F766E);

  /// Soft fill of the accent.
  final Color accentSoft = const Color(0xFFE3F4F1);

  /// Faint fill of a selected row.
  final Color accentFaint = const Color(0xFFF1FAF8);

  /// Text and mark of an override or an error.
  final Color danger = const Color(0xFFC2283F);

  /// Fill of an override.
  final Color dangerSoft = const Color(0xFFFDEBEE);

  /// Border of an override.
  final Color dangerLine = const Color(0xFFF6C6CE);

  /// Mark of a setting that needs a restart.
  final Color restart = const Color(0xFFB45309);

  /// Fill of the note about a restart.
  final Color restartSoft = const Color(0xFFFEF3E2);

  /// Text of the note about a restart.
  final Color restartText = const Color(0xFF8A4A0B);

  /// Text and mark of success.
  final Color success = const Color(0xFF2F8F4E);

  /// Fill of success.
  final Color successSoft = const Color(0xFFE8F5EC);

  /// Color that dims the app under a sheet.
  final Color scrim = const Color(0x661C1A17);

  /// Family of the text, `null` for the font of the platform.
  final String? fontFamily;

  /// Family of request paths. The default is Menlo, which iOS holds. Any other
  /// platform draws its own monospace font.
  final String monoFamily;

  /// The panel style with the font of the platform.
  const AutomationPanelTheme.light({
    this.fontFamily,
    this.monoFamily = 'Menlo',
  });

  /// The theme of the panel with this extension inside.
  ///
  /// The theme styles the Material radios, switches, text fields, text
  /// selection and text buttons. They take the colors of the panel, not the
  /// colors of the app.
  ThemeData toThemeData() {
    final scheme = ColorScheme.light(
      primary: accent,
      onPrimary: surface,
      secondary: accent,
      surface: surface,
      onSurface: text,
      error: danger,
      outline: lineStrong,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: fontFamily,
      splashFactory: NoSplash.splashFactory,
      dividerColor: line,
      extensions: [this],
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? null : textSecondary,
        ),
        visualDensity: VisualDensity.compact,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Color(0xFFFFFFFF)),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accent : lineStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: gapMedium),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: accent),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: shape, foregroundColor: accent),
      ),
    );
  }

  /// A style of the panel text.
  ///
  /// The [size] parameter is the font size.
  /// The [weight] parameter is the font weight.
  /// The [color] parameter is the text color, the primary text by default.
  /// The [isMono] parameter picks the monospace family of request paths.
  TextStyle textStyle({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    bool isMono = false,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? text,
      fontFamily: isMono ? monoFamily : fontFamily,
      fontFamilyFallback: isMono ? const ['monospace'] : null,
      height: isMono ? 1.2 : 1.25,
      decoration: TextDecoration.none,
    );
  }

  /// The theme of the nearest panel, [AutomationPanelTheme.light] outside one.
  static AutomationPanelTheme of(BuildContext context) {
    return Theme.of(context).extension<AutomationPanelTheme>() ??
        const AutomationPanelTheme.light();
  }

  /// The theme with another font family.
  ///
  /// The fonts are the only part of the style a project changes, so they are
  /// the only parameters.
  @override
  AutomationPanelTheme copyWith({String? fontFamily, String? monoFamily}) {
    return AutomationPanelTheme.light(
      fontFamily: fontFamily ?? this.fontFamily,
      monoFamily: monoFamily ?? this.monoFamily,
    );
  }

  @override
  AutomationPanelTheme lerp(AutomationPanelTheme? other, double t) {
    return t < 0.5 || other == null ? this : other;
  }
}
