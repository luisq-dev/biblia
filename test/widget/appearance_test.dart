import 'package:biblia/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_support.dart';

void main() {
  testWidgets('paleta y fuente se eligen en desplegables y se conservan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await pumpBibleApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    final palette = find.byKey(const ValueKey<String>('color-palette'));
    expect(
      find.byType(DropdownButtonFormField<AppColorPalette>),
      findsOneWidget,
    );
    await tester.ensureVisible(palette);
    await tester.tap(palette);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terracota').last);
    await tester.pumpAndSettle();
    expect(harness.settings.colorPalette, AppColorPalette.terracotta);

    final font = find.byKey(const ValueKey<String>('reading-font'));
    await tester.ensureVisible(font);
    await tester.pumpAndSettle();
    await tester.tap(font);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moderna').last);
    await tester.pumpAndSettle();
    expect(harness.settings.readingFont, ReadingFont.modern);
    expect(harness.preferences.getString('settings.reading_font.v1'), 'modern');
    expect(
      harness.preferences.getString('settings.color_palette.v1'),
      'terracotta',
    );

    final preview = tester.widget<Text>(
      find.text('Un momento de calma para leer, comprender y reflexionar.'),
    );
    expect(preview.style?.fontFamily, ReadingFont.modern.family);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final verse = tester.widget<Text>(
      find.text('Versículo de prueba con amor y esperanza para la interfaz.'),
    );
    expect(verse.style?.fontFamily, ReadingFont.modern.family);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await disposeHarness(harness);
  });

  testWidgets(
    'el tamaño se previsualiza sin reconstruir la lectura durante el arrastre',
    (tester) async {
      final harness = await pumpBibleApp(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Slider));
      await tester.pumpAndSettle();
      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(27);
      await tester.pump();
      expect(harness.settings.readingFontSize, 19);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 27);
      final preview = tester.widget<Text>(
        find.text('Un momento de calma para leer, comprender y reflexionar.'),
      );
      expect(preview.style?.fontSize, 27);
      slider.onChangeEnd!(27);
      await tester.pumpAndSettle();
      expect(harness.settings.readingFontSize, 27);
      expect(
        harness.preferences.getDouble('settings.reading_font_size.v1'),
        27,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await disposeHarness(harness);
    },
  );

  testWidgets(
    'el tamaño no reconstruye los temas y restaura la fuente guardada',
    (tester) async {
      final harness = await pumpBibleApp(
        tester,
        initialPreferences: <String, Object>{
          'settings.reading_font.v1': 'classic',
          'settings.color_palette.v1': 'sage_green',
        },
      );
      expect(harness.settings.readingFont, ReadingFont.classic);
      final ThemeData? theme = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme;
      await harness.settings.setReadingFontSize(25);
      await tester.pumpAndSettle();
      expect(
        identical(
          theme,
          tester.widget<MaterialApp>(find.byType(MaterialApp)).theme,
        ),
        isTrue,
      );
      expect(theme?.extension<ReadingFontTheme>()?.font, ReadingFont.classic);
      await tester.pumpWidget(const SizedBox.shrink());
      await disposeHarness(harness);
    },
  );
}
