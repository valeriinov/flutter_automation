import 'package:flutter_driver/flutter_driver.dart';
import 'package:vm_service/vm_service.dart';

/// {@category Utils}
///
/// The source files of the app that a run executed, read off the coverage that
/// the Dart VM keeps for the isolate of the app.
///
/// A file that the run never entered cannot have shaped what the run recorded.
/// The list names the files whose change makes the record stale. The list
/// leaves out generated files: each follows its source, which the list names
/// already, or the assets that `pubspec.yaml` declares.
final class AutomationCoverageManifest {
  /// The directory an app library's path starts with.
  static const appSourceDirectory = 'lib/';

  /// The file name endings of generated sources.
  static const generatedSuffixes = [
    '.g.dart',
    '.freezed.dart',
    '.gr.dart',
    '.config.dart',
    '.gen.dart',
  ];

  const AutomationCoverageManifest._();

  /// Reads the coverage of the isolate that [driver] uses and returns the files
  /// it names, as [fromSourceReport] does.
  ///
  /// The [appPackagePrefix] parameter is the `package:` prefix of the app's
  /// own libraries.
  static Future<List<String>> read(
    FlutterDriver driver, {
    required String appPackagePrefix,
  }) async {
    final isolateId = driver.appIsolate.id;

    if (isolateId == null) {
      throw StateError('The driver is connected to no isolate id.');
    }

    final report = await driver.serviceClient.getSourceReport(
      isolateId,
      [SourceReportKind.kCoverage],
      libraryFilters: [appPackagePrefix],
    );

    return fromSourceReport(report, appPackagePrefix: appPackagePrefix);
  }

  /// Returns the sorted `lib/` paths of the app scripts [report] holds at
  /// least one hit in, the scripts of the libraries under [appPackagePrefix].
  static List<String> fromSourceReport(
    SourceReport report, {
    required String appPackagePrefix,
  }) {
    final scripts = report.scripts ?? const [];
    final ranges = report.ranges ?? const [];
    final paths = ranges
        .where(_hasHits)
        .map((range) => _tryReadUri(scripts, range))
        .nonNulls
        .where((uri) => _isAppSource(uri, appPackagePrefix))
        .map((uri) => uri.replaceFirst(appPackagePrefix, appSourceDirectory))
        .toSet();

    return paths.toList()..sort();
  }

  static bool _hasHits(SourceReportRange range) {
    return range.coverage?.hits?.isNotEmpty ?? false;
  }

  static String? _tryReadUri(List<ScriptRef> scripts, SourceReportRange range) {
    final index = range.scriptIndex;

    if (index == null || index < 0) {
      return null;
    }

    return scripts.elementAtOrNull(index)?.uri;
  }

  static bool _isAppSource(String uri, String appPackagePrefix) {
    return uri.startsWith(appPackagePrefix) &&
        !generatedSuffixes.any(uri.endsWith);
  }
}
