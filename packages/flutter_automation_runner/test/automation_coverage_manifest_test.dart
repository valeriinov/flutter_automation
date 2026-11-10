import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import 'package:flutter_automation_runner/src/automation_coverage_manifest.dart';

const _prefix = 'package:sample_app/';
const _firstHit = 12;
const _secondHit = 48;
const _miss = 96;
const _scriptUris = [
  'package:sample_app/presentation/ui/screens/item_details/item_details_view.dart',
  'package:sample_app/domain/usecases/basket_use_case.dart',
  'package:sample_app/data/dto/basket/basket_dto.g.dart',
  'package:sample_app/domain/entities/basket/basket_data.freezed.dart',
  'package:sample_app/presentation/ui/navigation/app_router.gr.dart',
  'package:sample_app/presentation/di/injector.config.dart',
  'package:sample_app/common/generated/assets.gen.dart',
  'package:flutter/src/widgets/text.dart',
  'package:sample_app/domain/usecases/item_use_case.dart',
  'package:sample_app/domain/usecases/order_use_case.dart',
];

void main() {
  group('AutomationCoverageManifest Tests', () {
    _automationCoverageManifest_should_listHitAppSourcesAsLibPaths();
    _automationCoverageManifest_should_returnEmptyForEmptyReport();
  });
}

void _automationCoverageManifest_should_listHitAppSourcesAsLibPaths() {
  test(
    'AutomationCoverageManifest should list hit app sources as lib paths',
    () {
      final report = SourceReport(
        scripts: [
          for (final (index, uri) in _scriptUris.indexed)
            ScriptRef(id: 'scripts/$index', uri: uri),
        ],
        ranges: [
          _createRange(scriptIndex: 0, hits: [_firstHit]),
          _createRange(scriptIndex: 0, hits: [_secondHit]),
          _createRange(scriptIndex: 1, hits: [_firstHit, _secondHit]),
          for (final scriptIndex in [2, 3, 4, 5, 6, 7])
            _createRange(scriptIndex: scriptIndex, hits: [_firstHit]),
          _createRange(scriptIndex: 8, hits: []),
          SourceReportRange(scriptIndex: 9, compiled: false),
        ],
      );
      final manifest = AutomationCoverageManifest.fromSourceReport(
        report,
        appPackagePrefix: _prefix,
      );

      expect(manifest, [
        'lib/domain/usecases/basket_use_case.dart',
        'lib/presentation/ui/screens/item_details/item_details_view.dart',
      ]);
    },
  );
}

void _automationCoverageManifest_should_returnEmptyForEmptyReport() {
  test('AutomationCoverageManifest should return empty for empty report', () {
    final manifest = AutomationCoverageManifest.fromSourceReport(
      SourceReport(),
      appPackagePrefix: _prefix,
    );

    expect(manifest, isEmpty);
  });
}

SourceReportRange _createRange({
  required int scriptIndex,
  required List<int> hits,
}) {
  return SourceReportRange(
    scriptIndex: scriptIndex,
    compiled: true,
    coverage: SourceReportCoverage(hits: hits, misses: [_miss]),
  );
}
