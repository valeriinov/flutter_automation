import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/flutter_automation_atlas.dart';

import 'test_utils/test_atlas_root.dart';
import 'test_utils/write_published_journals.dart';

const _declared = [
  AtlasDeclaredRequest(
    method: 'GET',
    path: '/items',
    names: ['items'],
    usages: ['lib/items_service.dart:12'],
  ),
  AtlasDeclaredRequest(
    method: 'GET',
    path: '/items/by-owner',
    names: ['itemsByOwner'],
    usages: ['lib/items_service.dart:20'],
  ),
  AtlasDeclaredRequest(
    method: 'POST',
    path: '/orders',
    names: ['orders'],
    usages: ['lib/orders_service.dart:7'],
  ),
  AtlasDeclaredRequest(
    method: null,
    path: '/legacy',
    names: ['legacy'],
    usages: [],
  ),
];

void main() {
  group('AtlasRequestsTable Tests', () {
    _atlasRequestsTable_should_matchExactPath();
    _atlasRequestsTable_should_matchLongestDeclaredPathItContinues();
    _atlasRequestsTable_should_notMatchPathBeyondSegmentBoundary();
    _atlasRequestsTable_should_giveStatusOfEveryDeclaredRequest();
    _atlasRequestsTable_should_addLoggedPathNoDeclarationMatches();
    _atlasRequestsTable_should_failOnLoggedMethodNoDeclarationCalls();
  });
}

void _atlasRequestsTable_should_matchExactPath() {
  test('AtlasRequestsTable should match an exact path', () async {
    final rows = await _buildRows([_request('GET', '/items/by-owner')]);

    expect(rows[1]['status'], 'onFrames');
    expect(rows[0]['status'], 'pending');
    expect(rows.length, _declared.length);
  });
}

void _atlasRequestsTable_should_matchLongestDeclaredPathItContinues() {
  test('AtlasRequestsTable should match the longest declared path', () async {
    final rows = await _buildRows([
      _request('GET', '/items/by-owner/42'),
      _request('GET', '/items/42'),
    ]);

    expect(rows[1]['status'], 'onFrames');
    expect(rows[1]['stages'], {
      testJournalVariantId: [0],
    });
    expect(rows[0]['status'], 'onFrames');
    expect(rows.length, _declared.length);
  });
}

void _atlasRequestsTable_should_notMatchPathBeyondSegmentBoundary() {
  test('AtlasRequestsTable should not match beyond a segment', () async {
    final rows = await _buildRows([_request('GET', '/items-archive/7')]);

    expect(rows.last['path'], '/items-archive/{id}');
    expect(rows.last['status'], 'mockIssued');
    expect(rows[0]['status'], 'pending');
  });
}

void _atlasRequestsTable_should_giveStatusOfEveryDeclaredRequest() {
  test('AtlasRequestsTable should give the status of each request', () async {
    final rows = await _buildRows([_request('POST', '/orders')]);

    expect(rows.map((row) => row['status']), [
      'pending',
      'pending',
      'onFrames',
      'codeOnly',
    ]);
    expect(rows[2]['usages'], ['lib/orders_service.dart:7']);
    expect(rows[2]['endpoints'], ['orders']);
    expect(rows[3], isNot(contains('method')));
  });
}

void _atlasRequestsTable_should_addLoggedPathNoDeclarationMatches() {
  test('AtlasRequestsTable should add a logged path with ids', () async {
    final rows = await _buildRows([
      _request('GET', '/tags/17/children/0f8fad5b-d9cb-469f-a165-70867728950e'),
      _request('GET', '/tags/18/children/0f8fad5b-d9cb-469f-a165-70867728950e'),
    ]);

    expect(rows.length, _declared.length + 1);
    expect(rows.last, {
      'method': 'GET',
      'path': '/tags/{id}/children/{id}',
      'status': 'mockIssued',
      'endpoints': <String>[],
      'usages': <String>[],
      'stages': {
        testJournalVariantId: [0, 1],
      },
    });
  });
}

void _atlasRequestsTable_should_failOnLoggedMethodNoDeclarationCalls() {
  test('AtlasRequestsTable should fail on an uncalled method', () async {
    await expectLater(
      _buildRows([_request('DELETE', '/orders')]),
      throwsA(
        isA<AtlasException>().having(
          (error) => error.message,
          'message',
          contains('DELETE /orders'),
        ),
      ),
    );
  });
}

Map<String, Object?> _request(String method, String path) {
  return {'kind': 'request', 'method': method, 'path': path};
}

Future<List<Map<String, Object?>>> _buildRows(
  List<Map<String, Object?>> records,
) async {
  late List<Map<String, Object?>> rows;

  await TestAtlasRoot.run((root) {
    writePublishedJournals(
      root,
      journals: [
        for (final record in records) [record],
      ],
      unpublishedJournals: [
        [_request('GET', '/unpublished')],
      ],
    );

    final table = AtlasRequestsTable.build(
      id: 'requests',
      title: const {'en': 'Requests'},
      journalKind: 'request',
      store: AtlasStoreReader.open(root.project, rootPath: root.directory.path),
      declared: _declared,
    );

    expect(table.journalKind, 'request');

    rows = table.rows;
  });

  return rows;
}
