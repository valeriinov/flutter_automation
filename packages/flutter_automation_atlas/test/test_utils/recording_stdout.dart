import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final class RecordingStdout extends Fake implements Stdout {
  final List<String> lines;

  RecordingStdout(this.lines);

  @override
  void writeln([Object? object = '']) {
    lines.add('$object');
  }

  // Runs [body] with `stdout` recording, and returns the lines [body] wrote.
  static Future<List<String>> captureLines(
    FutureOr<void> Function() body,
  ) async {
    final lines = <String>[];

    await IOOverrides.runZoned(
      () async => body(),
      stdout: () => RecordingStdout(lines),
    );

    return lines;
  }
}
