import 'package:flutter/material.dart';

/// Actual Budget's purple, so the two apps read as related. It is the one
/// accent: primary actions, focus, selection. Everything else is neutral.
const Color _accent = Color(0xFF8719E0);

/// Spacing scale (4pt grid). Use these instead of ad-hoc numbers.
class Space {
  Space._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal gutter for every screen and sheet.
  static const double gutter = 20;
}

/// Corner-radius rule, applied everywhere:
/// controls and inline surfaces (buttons, inputs, notes, chips) use [control];
/// sheets and dialogs use [sheet] on their top corners.
class Radii {
  Radii._();

  static const double control = 12;
  static const double sheet = 24;

  static final BorderRadius controlAll = BorderRadius.circular(control);
}

/// Colors that ColorScheme has no slot for. Read via `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  /// Inflow amounts. Semantic, not decorative: it sits next to an explicit
  /// "+" sign so meaning never depends on color alone.
  final Color inflow;

  const AppTokens({required this.inflow});

  factory AppTokens.of(Brightness brightness) => AppTokens(
    inflow: brightness == Brightness.dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
  );

  @override
  AppTokens copyWith({Color? inflow}) => AppTokens(inflow: inflow ?? this.inflow);

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(inflow: Color.lerp(inflow, other.inflow, t)!);
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  /// Falls back to defaults under a theme that wasn't built by [AppTheme]
  /// (tests, previews), instead of crashing on a missing extension.
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ?? AppTokens.of(theme.brightness);
  }
}

/// Monospace style for money, dates and other figures, so columns line up.
TextStyle figures(TextStyle? base) => (base ?? const TextStyle()).copyWith(
  fontFamily: 'GeistMono',
  fontFeatures: const [FontFeature.tabularFigures()],
  letterSpacing: 0,
);

class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Seeded scheme for the accent roles, then the surfaces are replaced with
    // a cool neutral (zinc-like) ramp so screens are not tinted lavender.
    // No pure black or white anywhere.
    final seeded = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final scheme = isDark
        ? seeded.copyWith(
            surface: const Color(0xFF111113),
            onSurface: const Color(0xFFECECEE),
            onSurfaceVariant: const Color(0xFFA1A1AA),
            surfaceContainerLowest: const Color(0xFF0C0C0E),
            surfaceContainerLow: const Color(0xFF17171A),
            surfaceContainer: const Color(0xFF1C1C20),
            surfaceContainerHigh: const Color(0xFF242428),
            surfaceContainerHighest: const Color(0xFF2E2E33),
            outline: const Color(0xFF52525B),
            outlineVariant: const Color(0xFF2E2E33),
          )
        : seeded.copyWith(
            surface: const Color(0xFFFAFAFA),
            onSurface: const Color(0xFF18181B),
            onSurfaceVariant: const Color(0xFF52525B),
            surfaceContainerLowest: const Color(0xFFFFFFFE),
            surfaceContainerLow: const Color(0xFFF4F4F5),
            surfaceContainer: const Color(0xFFEFEFF1),
            surfaceContainerHigh: const Color(0xFFE8E8EB),
            surfaceContainerHighest: const Color(0xFFE0E0E4),
            outline: const Color(0xFFA1A1AA),
            outlineVariant: const Color(0xFFE4E4E7),
          );

    final baseText = (isDark ? Typography.material2021().white : Typography.material2021().black)
        .apply(fontFamily: 'Geist', bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final textTheme = baseText.copyWith(
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        height: 1.15,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: baseText.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.45),
      bodySmall: baseText.bodySmall?.copyWith(height: 1.4, color: scheme.onSurfaceVariant),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0),
      labelMedium: baseText.labelMedium?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0),
    );

    final controlShape = RoundedRectangleBorder(borderRadius: Radii.controlAll);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    const buttonMinSize = Size(64, 52);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Geist',
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      extensions: [AppTokens.of(brightness)],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: controlShape,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: controlShape,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: controlShape,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        border: OutlineInputBorder(
          borderRadius: Radii.controlAll,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.controlAll,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.controlAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.controlAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.controlAll,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          shape: WidgetStatePropertyAll(controlShape),
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sheet)),
        titleTextStyle: textTheme.titleLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sheet)),
      ),
    );
  }
}
