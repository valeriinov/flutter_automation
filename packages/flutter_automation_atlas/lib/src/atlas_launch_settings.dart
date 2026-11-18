/// {@category Utils}
///
/// How the atlas starts the app on a simulator with `flutter run`.
final class AtlasLaunchSettings {
  /// The Flutter flavor, absent when the app has none.
  final String? flavor;

  /// The entry point of the app, relative to the root of the project.
  final String entry;

  /// The `--dart-define` values, each as `NAME=value`.
  final List<String> defines;

  /// The words put before `flutter` and `dart` in every command the atlas
  /// starts, such as `['fvm']`; empty when the project calls them directly.
  final List<String> commandPrefix;

  const AtlasLaunchSettings({
    required this.entry,
    this.flavor,
    this.defines = const [],
    this.commandPrefix = const [],
  });

  /// The executable and the leading arguments of the command that runs
  /// [tool], such as `flutter` or `dart`.
  ({String executable, List<String> arguments}) resolveCommand(String tool) {
    final words = [...commandPrefix, tool];

    return (executable: words.first, arguments: words.skip(1).toList());
  }
}
