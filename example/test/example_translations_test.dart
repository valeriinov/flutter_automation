import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_automation/flutter_automation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/example_translations.dart';

const _renderedKeys = [
  'welcomeTitle',
  'signInButton',
  'mockModeTooltip',
  'catalogTitle',
  'catalogEmpty',
  'catalogLoadFailed',
];

void main() {
  for (final languageCode in ['en', 'uk']) {
    testWidgets('tr should give the $languageCode texts of the atlas', (
      tester,
    ) async {
      final file = File('tool/translations/$languageCode.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      late BuildContext context;

      await tester.pumpWidget(
        Localizations(
          locale: Locale(languageCode),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(
            builder: (builderContext) {
              context = builderContext;

              return const SizedBox.shrink();
            },
          ),
        ),
      );

      for (final key in _renderedKeys) {
        expect(LocaleKeyMarker.strip(tr(context, key)), json[key]);
      }
    });
  }
}
