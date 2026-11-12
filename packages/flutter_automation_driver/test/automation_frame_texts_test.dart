import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_automation_driver/src/automation_frame_texts.dart';

const _rowExtent = 100.0;
const _rowCount = 30;
const _coveredText = 'Covered page';
const _sheetText = 'Sheet title';
const _pageUnderSheetText = 'Page under the sheet';
const _shownTabText = 'Shown tab';
const _hiddenTabText = 'Hidden tab';
const _typedText = 'Typed message';
const _firstRowText = 'Row 0';
const _cachedRowText = 'Row 12';

void main() {
  group('AutomationFrameTexts Widget Tests', () {
    _automationFrameTexts_should_leaveOutARouteAnOpaqueOneCovers();
    _automationFrameTexts_should_readThePageUnderASheet();
    _automationFrameTexts_should_leaveOutATabUnderADisabledTickerMode();
    _automationFrameTexts_should_readOnlyTheChildAnIndexedStackShows();
    _automationFrameTexts_should_leaveOutRowsBuiltPastTheViewport();
    _automationFrameTexts_should_leaveOutATextLaidOutPastTheWindow();
  });
}

void _automationFrameTexts_should_leaveOutARouteAnOpaqueOneCovers() {
  testWidgets(
    'AutomationFrameTexts should leave out a route an opaque one covers',
    (tester) async {
      await tester.pumpWidget(_buildApp(const Text(_coveredText)));

      _navigator(tester).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: TextField()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), _typedText);
      await tester.pump();

      final texts = _read(tester);

      expect(texts, contains(_typedText));
      expect(texts, isNot(contains(_coveredText)));
    },
  );
}

void _automationFrameTexts_should_readThePageUnderASheet() {
  testWidgets('AutomationFrameTexts should read the page under a sheet', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(const Text(_pageUnderSheetText)));

    showModalBottomSheet<void>(
      context: tester.element(find.text(_pageUnderSheetText)),
      builder: (_) => const Text(_sheetText),
    );

    await tester.pumpAndSettle();

    final texts = _read(tester);

    expect(texts, containsAll([_pageUnderSheetText, _sheetText]));
  });
}

void _automationFrameTexts_should_leaveOutATabUnderADisabledTickerMode() {
  testWidgets(
    'AutomationFrameTexts should leave out a tab under a disabled ticker mode',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          const Stack(
            children: [
              TickerMode(enabled: false, child: Text(_hiddenTabText)),
              TickerMode(enabled: true, child: Text(_shownTabText)),
            ],
          ),
        ),
      );

      final texts = _read(tester);

      expect(texts, contains(_shownTabText));
      expect(texts, isNot(contains(_hiddenTabText)));
    },
  );
}

void _automationFrameTexts_should_readOnlyTheChildAnIndexedStackShows() {
  testWidgets(
    'AutomationFrameTexts should read only the child an indexed stack shows',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          const IndexedStack(
            index: 1,
            children: [Text(_hiddenTabText), Text(_shownTabText)],
          ),
        ),
      );

      final texts = _read(tester);

      expect(texts, contains(_shownTabText));
      expect(texts, isNot(contains(_hiddenTabText)));
    },
  );
}

void _automationFrameTexts_should_leaveOutRowsBuiltPastTheViewport() {
  testWidgets(
    'AutomationFrameTexts should leave out rows built past the viewport',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          SizedBox(
            height: _rowExtent * 2,
            child: ListView.builder(
              itemCount: _rowCount,
              itemExtent: _rowExtent,
              scrollCacheExtent: const ScrollCacheExtent.pixels(
                _rowExtent * _rowCount,
              ),
              itemBuilder: (_, index) => Text('Row $index'),
            ),
          ),
        ),
      );

      final texts = _read(tester);

      expect(find.text(_cachedRowText, skipOffstage: false), findsOneWidget);
      expect(texts, contains(_firstRowText));
      expect(texts, isNot(contains(_cachedRowText)));
    },
  );
}

void _automationFrameTexts_should_leaveOutATextLaidOutPastTheWindow() {
  testWidgets(
    'AutomationFrameTexts should leave out a text laid out past the window',
    (tester) async {
      final windowHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      await tester.pumpWidget(
        _buildApp(
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Text(_shownTabText),
              Positioned(top: windowHeight, child: const Text(_hiddenTabText)),
            ],
          ),
        ),
      );

      final texts = _read(tester);

      expect(texts, contains(_shownTabText));
      expect(texts, isNot(contains(_hiddenTabText)));
    },
  );
}

Widget _buildApp(Widget body) {
  return MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: body),
    ),
  );
}

NavigatorState _navigator(WidgetTester tester) {
  return tester.state<NavigatorState>(find.byType(Navigator));
}

List<String> _read(WidgetTester tester) {
  final view = tester.view;

  return AutomationFrameTexts.read(
    tester.binding.rootElement ?? tester.element(find.byType(MaterialApp)),
    Offset.zero & view.physicalSize / view.devicePixelRatio,
  );
}
