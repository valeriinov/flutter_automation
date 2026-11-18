import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';

import 'test_atlas_root.dart';

const testHeadlessFrameHash = 'eeeeeeeeeeee';
const testHeadlessJournalHash = 'ffffffffffff';

final testHeadlessRenderer = 'Flutter $testFlutterVersion · ${Abi.current()}';

AtlasSnapshot addTestHeadlessHashes(
  AtlasSnapshot snapshot, {
  List<String?>? frameHashes,
  List<String?>? journalHashes,
  String? endFrameHash = testHeadlessFrameHash,
  String? renderer,
}) {
  return snapshot.copyWithHeadlessWalk(
    renderer: renderer ?? testHeadlessRenderer,
    stages: [
      for (final (index, stage) in snapshot.stages.indexed)
        stage.copyWithHeadlessHashes(
          frameHash: _readHash(frameHashes, index, testHeadlessFrameHash),
          journalHash: _readHash(journalHashes, index, testHeadlessJournalHash),
        ),
    ],
    end: snapshot.end.copyWithHeadlessFrameHash(endFrameHash),
  );
}

void expectTestHeadlessHashes(AtlasSnapshot snapshot) {
  expect(
    snapshot.stages.map((stage) => stage.headlessFrameHash),
    everyElement(testHeadlessFrameHash),
  );
  expect(
    snapshot.stages.map((stage) => stage.headlessJournalHash),
    everyElement(testHeadlessJournalHash),
  );
  expect(snapshot.end.headlessFrameHash, testHeadlessFrameHash);
  expect(snapshot.headlessRenderer, testHeadlessRenderer);
}

String? _readHash(List<String?>? hashes, int index, String fallback) {
  if (hashes == null) {
    return fallback;
  }

  return hashes.elementAtOrNull(index);
}
