import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_automation_driver/src/automation_frame_widgets.dart';

const _rowExtent = 100.0;
const _rowCount = 30;
const _shownRowCount = 2;

void main() {
  group('AutomationFrameWidgets Widget Tests', () {
    _automationFrameWidgets_should_readOnlyTheChildAnIndexedStackShows();
    _automationFrameWidgets_should_leaveOutAnOffstageSubtree();
    _automationFrameWidgets_should_leaveOutRowsBuiltPastTheViewport();
    _automationFrameWidgets_should_nameATypeWithoutGenericArguments();
    _automationFrameWidgets_should_readSortedUniqueTypes();
  });
}

void _automationFrameWidgets_should_readOnlyTheChildAnIndexedStackShows() {
  testWidgets(
    'AutomationFrameWidgets should read only the child an indexed stack shows',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          const IndexedStack(index: 1, children: [_HiddenTab(), _ShownTab()]),
        ),
      );

      final widgets = _read(tester);

      expect(widgets, contains('_ShownTab'));
      expect(widgets, isNot(contains('_HiddenTab')));
    },
  );
}

void _automationFrameWidgets_should_leaveOutAnOffstageSubtree() {
  testWidgets('AutomationFrameWidgets should leave out an offstage subtree', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        const Column(
          children: [
            Offstage(child: _HiddenTab()),
            _ShownTab(),
          ],
        ),
      ),
    );

    final widgets = _read(tester);

    expect(widgets, contains('_ShownTab'));
    expect(widgets, isNot(contains('_HiddenTab')));
  });
}

void _automationFrameWidgets_should_leaveOutRowsBuiltPastTheViewport() {
  testWidgets(
    'AutomationFrameWidgets should leave out rows built past the viewport',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          SizedBox(
            height: _rowExtent * _shownRowCount,
            child: ListView.builder(
              itemCount: _rowCount,
              itemExtent: _rowExtent,
              scrollCacheExtent: const ScrollCacheExtent.pixels(
                _rowExtent * _rowCount,
              ),
              itemBuilder: (_, index) => index < _shownRowCount
                  ? const _ShownTab()
                  : const _HiddenTab(),
            ),
          ),
        ),
      );

      final widgets = _read(tester);

      expect(find.byType(_HiddenTab, skipOffstage: false), findsWidgets);
      expect(widgets, contains('_ShownTab'));
      expect(widgets, isNot(contains('_HiddenTab')));
    },
  );
}

void _automationFrameWidgets_should_nameATypeWithoutGenericArguments() {
  testWidgets(
    'AutomationFrameWidgets should name a type without generic arguments',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          ValueListenableBuilder<int>(
            valueListenable: ValueNotifier(0),
            builder: (_, value, _) => Text('$value'),
          ),
        ),
      );

      final widgets = _read(tester);

      expect(widgets, contains('ValueListenableBuilder'));
      expect(widgets.where((name) => name.contains('<')), isEmpty);
    },
  );
}

void _automationFrameWidgets_should_readSortedUniqueTypes() {
  testWidgets('AutomationFrameWidgets should read sorted unique types', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(const Column(children: [_ShownTab(), _ShownTab()])),
    );

    final widgets = _read(tester);

    expect(widgets, [...widgets]..sort());
    expect(widgets.toSet(), hasLength(widgets.length));
    expect(widgets.where((name) => name == '_ShownTab'), hasLength(1));
  });
}

Widget _buildApp(Widget body) {
  return MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: body),
    ),
  );
}

List<String> _read(WidgetTester tester) {
  final view = tester.view;

  return AutomationFrameWidgets.read(
    tester.binding.rootElement ?? tester.element(find.byType(MaterialApp)),
    Offset.zero & view.physicalSize / view.devicePixelRatio,
  );
}

class _ShownTab extends StatelessWidget {
  const _ShownTab();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 10, height: _rowExtent);
  }
}

class _HiddenTab extends StatelessWidget {
  const _HiddenTab();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 10, height: _rowExtent);
  }
}
