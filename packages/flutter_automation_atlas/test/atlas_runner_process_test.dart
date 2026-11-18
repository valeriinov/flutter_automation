import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_runner_process.dart';
import 'package:flutter_automation_atlas/src/atlas_stage_scope.dart';

import 'test_utils/fake_atlas_project.dart';
import 'test_utils/test_atlas_root.dart';

const _flow = 'shop_flow';
const _variant = 'shopFromSearch';
const _captureOption = '--capture';
const _recordOption = '--record';
const _otherLocale = 'en';
const _stderrClosing = Duration(milliseconds: 50);
const _walkTimeout = Timeout(Duration(seconds: 30));

void main() {
  group('AtlasRunnerProcess Tests', () {
    _atlasRunnerProcess_should_recordFullWalkInDefaultLocale();
    _atlasRunnerProcess_should_recordNothingForPartialWalk();
    _atlasRunnerProcess_should_recordNothingInOtherLocale();
    _atlasRunnerProcess_should_recordNothingOutsideQaCatalogue();
  });
}

void _atlasRunnerProcess_should_recordFullWalkInDefaultLocale() {
  test(
    'AtlasRunnerProcess should record full walk in default locale',
    () async {
      await TestAtlasRoot.run((root) async {
        final started = <List<String>>[];

        await _walk(
          root,
          started,
          isInQaCatalogue: true,
          scope: const AtlasStageScope.every(),
          locale: fakeAtlasLocales.first,
        );

        expect(started.single, contains(_captureOption));
        expect(started.single, contains(_recordOption));
        expect(
          started.single[started.single.indexOf(_recordOption) + 1],
          root.paths.recordingsPath,
        );
      });
    },
    timeout: _walkTimeout,
  );
}

void _atlasRunnerProcess_should_recordNothingForPartialWalk() {
  test('AtlasRunnerProcess should record nothing for partial walk', () async {
    await TestAtlasRoot.run((root) async {
      final started = <List<String>>[];

      await _walk(
        root,
        started,
        isInQaCatalogue: true,
        scope: AtlasStageScope.of(const [0], stageCount: 3),
        locale: fakeAtlasLocales.first,
      );

      expect(started.single, isNot(contains(_recordOption)));
    });
  }, timeout: _walkTimeout);
}

void _atlasRunnerProcess_should_recordNothingInOtherLocale() {
  test('AtlasRunnerProcess should record nothing in other locale', () async {
    await TestAtlasRoot.run((root) async {
      final started = <List<String>>[];

      await _walk(
        root,
        started,
        isInQaCatalogue: true,
        scope: const AtlasStageScope.every(),
        locale: _otherLocale,
      );

      expect(started.single, isNot(contains(_recordOption)));
    });
  }, timeout: _walkTimeout);
}

void _atlasRunnerProcess_should_recordNothingOutsideQaCatalogue() {
  test(
    'AtlasRunnerProcess should record nothing outside QA catalogue',
    () async {
      await TestAtlasRoot.run((root) async {
        final started = <List<String>>[];

        await _walk(
          root,
          started,
          isInQaCatalogue: false,
          scope: const AtlasStageScope.every(),
          locale: fakeAtlasLocales.first,
        );

        expect(started.single, isNot(contains(_recordOption)));
      });
    },
    timeout: _walkTimeout,
  );
}

Future<void> _walk(
  TestAtlasRoot root,
  List<List<String>> started, {
  required bool isInQaCatalogue,
  required AtlasStageScope scope,
  required String locale,
}) async {
  root.writeFlow(_flow, {
    'isInQaCatalogue': isInQaCatalogue,
    'variants': {
      _variant: {
        'items': [
          {
            'action': 'tap',
            'label': 'open',
            'finder': {'by': 'valueKey', 'value': 'open'},
          },
        ],
      },
    },
  });

  final variant = AtlasDefinitions.read(root.paths).variants.single;

  final captureDirectory = await root.createCaptureDirectory();

  await AtlasRunnerProcess(
    root.paths,
    'ws://127.0.0.1:1/ws',
    locale,
    startProcess: (executable, arguments) async {
      started.add(arguments);

      return _FakeProcess();
    },
  ).capture(variant, scope, captureDirectory);
}

final class _FakeProcess extends Fake implements Process {
  @override
  Stream<List<int>> get stdout =>
      Stream.value(utf8.encode(jsonEncode({'flow': _flow, 'ok': true})));

  @override
  Stream<List<int>> get stderr =>
      Stream.fromFuture(Future.delayed(_stderrClosing, () => <int>[]));

  @override
  Future<int> get exitCode => Future.value(0);
}
