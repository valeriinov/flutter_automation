import 'package:flutter/widgets.dart';
import 'package:flutter_automation/flutter_automation.dart';

const _texts = {
  'en': {
    'welcomeTitle': 'Welcome',
    'signInButton': 'Sign in',
    'mockModeTooltip': 'Mock mode',
    'catalogTitle': 'Catalog',
    'catalogEmpty': 'The catalog is empty',
    'catalogLoadFailed': 'Could not load the catalog',
  },
  'uk': {
    'welcomeTitle': 'Ласкаво просимо',
    'signInButton': 'Увійти',
    'mockModeTooltip': 'Режим мока',
    'catalogTitle': 'Каталог',
    'catalogEmpty': 'Каталог порожній',
    'catalogLoadFailed': 'Не вдалося завантажити каталог',
  },
};

/// The text of [key] in the language of the app, in English for a language
/// without texts. A build that marks locale keys appends the mark of [key].
String tr(BuildContext context, String key) {
  final languageCode = Localizations.localeOf(context).languageCode;
  final value = (_texts[languageCode] ?? _texts['en'])?[key] ?? key;

  if (!AutomationSettings.isLocaleKeyMarkingEnabled) {
    return value;
  }

  return LocaleKeyMarker.mark(key, value);
}
