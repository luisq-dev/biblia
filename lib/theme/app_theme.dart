import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

enum AppColorPalette {
  googleBlue(
    id: 'google_blue',
    label: 'Azul Google',
    seedColor: Color(0xFF1A73E8),
  ),
  sageGreen(
    id: 'sage_green',
    label: 'Verde Salvia',
    seedColor: Color(0xFF2E6930),
  ),
  deepIndigo(
    id: 'deep_indigo',
    label: 'Índigo Real',
    seedColor: Color(0xFF3949AB),
  ),
  terracotta(
    id: 'terracotta',
    label: 'Terracota',
    seedColor: Color(0xFFB34700),
  ),
  crimsonWine(
    id: 'crimson_wine',
    label: 'Carmesí',
    seedColor: Color(0xFF881A38),
  ),
  royalPurple(
    id: 'royal_purple',
    label: 'Amatista',
    seedColor: Color(0xFF673AB7),
  ),
  slateMinimal(
    id: 'slate_minimal',
    label: 'Pizarra',
    seedColor: Color(0xFF455A64),
  ),
  amberOchre(
    id: 'amber_ochre',
    label: 'Ámbar Cálido',
    seedColor: Color(0xFFB07200),
  );

  const AppColorPalette({
    required this.id,
    required this.label,
    required this.seedColor,
  });

  final String id;
  final String label;
  final Color seedColor;

  static AppColorPalette fromId(String? id) {
    for (final AppColorPalette palette in values) {
      if (palette.id == id) return palette;
    }
    return googleBlue;
  }
}

enum ReadingFont {
  literata(
    'literata',
    'Literata',
    'Literata',
    'Equilibrada y cómoda para leer',
  ),
  classic(
    'classic',
    'Clásica',
    'LiberationSerif',
    'El estilo de una Biblia impresa',
  ),
  modern('modern', 'Moderna', 'LiberationSans', 'Trazos limpios y sencillos');

  const ReadingFont(this.id, this.label, this.family, this.description);
  final String id;
  final String label;
  final String family;
  final String description;

  static ReadingFont fromId(String? id) =>
      values.firstWhere((font) => font.id == id, orElse: () => literata);
}

@immutable
class ReadingFontTheme extends ThemeExtension<ReadingFontTheme> {
  const ReadingFontTheme(this.font);
  final ReadingFont font;

  @override
  ReadingFontTheme copyWith({ReadingFont? font}) =>
      ReadingFontTheme(font ?? this.font);

  @override
  ReadingFontTheme lerp(covariant ReadingFontTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

abstract final class AppTheme {
  static final Map<(Brightness, AppColorPalette, ReadingFont), ThemeData>
  _cache = {};

  static ThemeData light({
    AppColorPalette palette = AppColorPalette.googleBlue,
    ReadingFont font = ReadingFont.literata,
  }) => _theme(Brightness.light, palette, font);

  static ThemeData dark({
    AppColorPalette palette = AppColorPalette.googleBlue,
    ReadingFont font = ReadingFont.literata,
  }) => _theme(Brightness.dark, palette, font);

  static ThemeData _theme(
    Brightness brightness,
    AppColorPalette palette,
    ReadingFont font,
  ) => _cache.putIfAbsent((
    brightness,
    palette,
    font,
  ), () => _build(brightness, palette, font));

  static ThemeData _build(
    Brightness brightness,
    AppColorPalette palette,
    ReadingFont font,
  ) {
    final String readingFontFamily = font.family;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: palette.seedColor,
      brightness: brightness,
    );
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final TextTheme text = base.textTheme;

    final RoundedRectangleBorder rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[ReadingFontTheme(font)],
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontFamily: readingFontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontFamily: readingFontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontFamily: readingFontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return text.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll<Color>(
          scheme.surfaceContainerHigh,
        ),
        elevation: const WidgetStatePropertyAll<double>(0),
        shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        side: WidgetStatePropertyAll<BorderSide>(BorderSide.none),
        shape: WidgetStatePropertyAll<OutlinedBorder>(rounded),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 18),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle?>(
          text.bodyLarge?.copyWith(color: scheme.onSurface),
        ),
        hintStyle: WidgetStatePropertyAll<TextStyle?>(
          text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: scheme.onSurfaceVariant,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        modalBarrierColor: Colors.black.withValues(alpha: 0.42),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        focusElevation: 1,
        hoverElevation: 2,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.22),
        selectionHandleColor: scheme.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

abstract final class ReadingTypography {
  static TextStyle body(BuildContext context, double fontSize, {Color? color}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontFamily:
          Theme.of(context).extension<ReadingFontTheme>()?.font.family ??
          ReadingFont.literata.family,
      fontSize: fontSize,
      height: 1.65,
      letterSpacing: 0.1,
      color: color ?? scheme.onSurface,
      fontVariations:
          (Theme.of(context).extension<ReadingFontTheme>()?.font ??
                  ReadingFont.literata) ==
              ReadingFont.literata
          ? <FontVariation>[
              FontVariation('opsz', fontSize.clamp(7, 36)),
              const FontVariation('wght', 400),
            ]
          : null,
    );
  }

  static TextStyle verseNumber(BuildContext context, double fontSize) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontFamily:
          Theme.of(context).extension<ReadingFontTheme>()?.font.family ??
          ReadingFont.literata.family,
      fontSize: (fontSize * 0.64).clamp(10, 16),
      height: 1.8,
      fontWeight: FontWeight.w600,
      color: scheme.primary,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  static TextStyle title(BuildContext context, {double? fontSize}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontFamily:
          Theme.of(context).extension<ReadingFontTheme>()?.font.family ??
          ReadingFont.literata.family,
      fontSize: fontSize ?? 34,
      height: 1.15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
      color: scheme.onSurface,
      fontVariations:
          (Theme.of(context).extension<ReadingFontTheme>()?.font ??
                  ReadingFont.literata) ==
              ReadingFont.literata
          ? <FontVariation>[
              FontVariation('opsz', (fontSize ?? 34).clamp(7, 36)),
              const FontVariation('wght', 600),
            ]
          : null,
    );
  }
}
