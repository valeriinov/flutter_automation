import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_series.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';

import 'test_utils/create_atlas_snapshot.dart';
import 'test_utils/fake_atlas_project.dart';

final _uk = fakeAtlasLocales.first;
const _en = 'en';
const _flow = 'inbox_flow';
const _declinedVariant = 'counterQuoteDeclined';
const _acceptedVariant = 'sellerQuoteAccepted';
const _keyHash = '111111111111';
final _ukDeclined = _createSnapshot(_declinedVariant, _uk);
final _ukAccepted = _createSnapshot(_acceptedVariant, _uk);
final _enAccepted = _createSnapshot(_acceptedVariant, _en);

void main() {
  group('AtlasSeries Tests', () {
    _atlasSeries_should_fallBackToUkSnapshotWithItsKeys();
    _atlasSeries_should_showOwnSnapshotUntagged();
    _atlasSeries_should_showOnlyUkSnapshotsForUk();
  });
}

void _atlasSeries_should_fallBackToUkSnapshotWithItsKeys() {
  test('AtlasSeries should fall back to uk snapshot with its keys', () {
    final series = AtlasSeries.resolve(
      [_ukDeclined, _ukAccepted, _enAccepted],
      locale: _en,
      defaultLocale: _uk,
    );
    final declined = series[_ukDeclined.id];

    expect(declined?.snapshot, same(_ukDeclined));
    expect(declined?.fallbackLocale, _uk);
    expect(declined?.snapshot.stages.single.localeKeys, {
      'inboxTitle': _keyHash,
    });
  });
}

void _atlasSeries_should_showOwnSnapshotUntagged() {
  test('AtlasSeries should show own snapshot untagged', () {
    final series = AtlasSeries.resolve(
      [_ukDeclined, _ukAccepted, _enAccepted],
      locale: _en,
      defaultLocale: _uk,
    );
    final accepted = series[_enAccepted.id];

    expect(series.keys, [_ukDeclined.id, _ukAccepted.id]);
    expect(accepted?.snapshot, same(_enAccepted));
    expect(accepted?.fallbackLocale, isNull);
  });
}

void _atlasSeries_should_showOnlyUkSnapshotsForUk() {
  test('AtlasSeries should show only uk snapshots for uk', () {
    final series = AtlasSeries.resolve(
      [_ukDeclined, _enAccepted],
      locale: _uk,
      defaultLocale: _uk,
    );

    expect(series.keys, [_ukDeclined.id]);
    expect(series[_ukDeclined.id]?.fallbackLocale, isNull);
  });
}

AtlasSnapshot _createSnapshot(String variant, String locale) {
  return createAtlasSnapshot(
    flow: _flow,
    variant: variant,
    locale: locale,
    stages: const [
      AtlasStage(
        label: 'open the inbox',
        action: 'tap',
        journal: [],
        ok: true,
        target: null,
        block: null,
        targetRect: null,
        screen: 'inbox-route',
        designScreen: null,
        shot: null,
        error: null,
        localeKeys: {'inboxTitle': _keyHash},
      ),
    ],
  );
}
