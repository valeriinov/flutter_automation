# flutter_automation_panel

The builder of the QA panel for an app that runs on `flutter_automation_mock`.
A tester picks a flow and its outcome, changes the answer of one request and
walks the app by hand, with no restart. The package depends on the mock only.
Its interface is in English and has a theme of its own,
`AutomationPanelTheme`.

## Build a panel

```dart
final controller = AutomationPanelController(
  AutomationPanelDefinition(
    mock: mock,
    catalogue: AutomationCatalogue.fromJson(catalogueJson),
    onRestartRequired: showRestartScreen,
    pages: [
      AutomationPanelPage(
        label: 'Flows',
        builder: (_) => const AutomationFlowsPage(),
      ),
    ],
  ),
);

MaterialApp(
  builder: (context, child) => AutomationPanelLauncher(
    controller: controller,
    isVisible: showDebugTools,
    child: child ?? const SizedBox(),
  ),
);
```

The project creates the controller before `runApp`: it handles the system back
button for the panel from the first frame. A request of a later step moves the
manual walk forward. A start that needs a restart saves the scenario and the
walk, asks the project to restart and starts no flow.

`wrapButton` wraps the QA button, so the project marks it for automation.
`startPosition` sets where the button stands before the tester drags it; the
default is the bottom right. A driver tap lands on the centre of its target, so
a project moves the button off the controls its flows tap.

The project owns the debug menu, the gesture that opens it and the restart.
`AutomationModeController` switches between server and mock and writes the
choice to `state.json`. `AutomationMockModeTile` is a ready tile for it.

## Catalogue

`fvm dart run tool/run_flows.dart --qa-catalogue assets/qa_catalogue.json
--recordings <dir>` builds the catalogue out of the flows that set
`isInQaCatalogue: true` and the recordings of their runs. See
`flutter_automation_runner`.
