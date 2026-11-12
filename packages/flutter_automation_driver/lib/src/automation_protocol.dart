/// {@category Utils}
///
/// Names the app and the host agree on: the commands the app answers, the
/// finder types it resolves, and the keys of their messages.
///
/// The app side (`driver_extension.dart`) and the host side
/// (`flutter_automation_driver.dart`) read the same constants, so each name has
/// one definition.
abstract final class AutomationProtocol {
  /// Command that answers the keyboard inset of the view.
  static const String keyboardReadCommand = 'keyboard.read';

  /// Command that answers the screen the app shows, the view size, the
  /// keyboard inset and the platform. With the [textsKey] and [widgetsKey]
  /// flags it also answers what the frame shows.
  static const String screenReadCommand = 'screen.read';

  /// Command that applies a language to the app.
  static const String localeApplyCommand = 'locale.apply';

  /// Command that saves a language for the next launch of the app.
  static const String localeSaveCommand = 'locale.save';

  /// Finder type that matches a text by its value, without locale key marks.
  static const String unmarkedTextFinderType = 'UnmarkedText';

  /// Finder type that matches a tooltip by its message, without locale key
  /// marks.
  static const String unmarkedTooltipFinderType = 'UnmarkedTooltip';

  /// Finder type that matches a text by the locale key it carries.
  static const String localeKeyTextFinderType = 'LocaleKeyText';

  /// Finder type that matches a tooltip by the locale key it carries.
  static const String localeKeyTooltipFinderType = 'LocaleKeyTooltip';

  /// Finder parameter that holds the text of an unmarked-text finder.
  static const String textParameter = 'text';

  /// Finder parameter that holds the key of a locale-key finder.
  static const String keyParameter = 'key';

  /// Key of the keyboard inset in the answers of both read commands.
  static const String keyboardInsetKey = 'inset';

  /// Key of the screen description in the answer of [screenReadCommand].
  static const String screenKey = 'screen';

  /// Key of the screen name inside the screen description, the value the
  /// host compares with the splash screen of a launch.
  static const String screenNameKey = 'screenName';

  /// Key of the view size in the answer of [screenReadCommand].
  static const String viewKey = 'view';

  /// Key of the logical view width.
  static const String widthKey = 'width';

  /// Key of the logical view height.
  static const String heightKey = 'height';

  /// Key of the platform name in the answer of [screenReadCommand].
  static const String platformKey = 'platform';

  /// Key of the texts the frame shows: a request flag of [screenReadCommand]
  /// and a key of its answer.
  static const String textsKey = 'texts';

  /// Key of the widget types the frame shows: a request flag of
  /// [screenReadCommand] and a key of its answer.
  static const String widgetsKey = 'widgets';

  /// Key of the language code in the requests and the answers of
  /// [localeApplyCommand] and [localeSaveCommand].
  static const String localeKey = 'locale';
}
