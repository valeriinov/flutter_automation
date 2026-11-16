import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/sample_panel.dart';

const _wrapperKey = ValueKey('wrapper');

void main() {
  group('Automation Panel Definition Tests', () {
    _standard_should_buildTheFourPagesInOrder();
    _standard_should_wrapEveryPage();
    _onShare_should_receiveTheContextOfTheRunDoneLayer();
  });
}

AutomationPanelDefinition _standardOf(
  SamplePanel sample, {
  Widget Function(Widget page)? wrapPage,
}) {
  return AutomationPanelDefinition.standard(
    mock: sample.mock,
    catalogue: sampleCatalogue,
    isRestartRequired: sample.isRestartRequired,
    wrapPage: wrapPage,
  );
}

void _standard_should_buildTheFourPagesInOrder() {
  testWidgets('standard should build the four pages in order', (tester) async {
    final sample = await createSamplePanel(tester);

    final definition = _standardOf(sample);

    expect(definition.pages.map((page) => page.label), [
      'Flows',
      'Autorun',
      'Sections',
      'Log',
    ]);
  });
}

void _standard_should_wrapEveryPage() {
  testWidgets('standard should wrap every page', (tester) async {
    final sample = await createSamplePanel(tester);

    final wrapped = <Type>[];
    final definition = _standardOf(
      sample,
      wrapPage: (page) {
        wrapped.add(page.runtimeType);

        return KeyedSubtree(key: _wrapperKey, child: page);
      },
    );
    final built = <Widget>[];

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          for (final page in definition.pages) {
            built.add(page.builder(context));
          }

          return const SizedBox();
        },
      ),
    );

    expect(built.map((page) => page.key), everyElement(_wrapperKey));
    expect(wrapped, [
      AutomationFlowsPage,
      AutomationAutorunPage,
      AutomationSectionsPage,
      AutomationJournalPage,
    ]);
  });
}

void _onShare_should_receiveTheContextOfTheRunDoneLayer() {
  testWidgets('onShare should receive the context of the run done layer', (
    tester,
  ) async {
    BuildContext? sharedContext;
    File? sharedReport;

    final sample = await createSamplePanel(
      tester,
      player: RecordingPlayer(),
      onShare: (context, report) {
        sharedContext = context;
        sharedReport = report;
      },
    );

    await tester.runAsync(() async {
      await sample.controller.startWalk('login', 'signUpNeeded');
      await sample.controller.finishWalk();
    });
    await tester.pumpWidget(
      hostApp(
        child: AutomationPanelLauncher(
          controller: sample.controller,
          isVisible: true,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.tap(find.text(sampleStrings.shareLogs));
    await tester.pump();

    expect(sharedContext?.findRenderObject(), isA<RenderBox>());
    expect(sharedReport?.path, endsWith('report.json'));
  });
}
