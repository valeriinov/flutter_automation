# flutter_automation_panel

The builder of the QA panel for an app that runs on `flutter_automation_mock`.
A tester picks a flow and its outcome, changes the answer of one request and
starts a walk. A start restarts the app. The player of the panel then does each
step of the flow inside the app: one action per tap of Next step in a manual
walk, every step in a row in an autorun. The package depends on the mock and on
`flutter_automation`, never on `flutter_driver` or the runner. Its interface is
in English and has a theme of its own, `AutomationPanelTheme`.

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
button for the panel and, while a walk runs, swallows it from the first frame.

## Walk and autorun

`controller.startWalk(flow, variant, mode: ...)` saves the scenario of the
variant and the walk, and calls `onRestartRequired` once, whatever the
scenario held before. It starts nothing:
the walk begins when the tester opens the app again. A branch whose
`isChosenBeforeStart` is true is picked on the flow map, before the restart.
The other branches are picked on the plaque, at the fork.

`AutomationFlowPlayer` does a catalogue step with the public API of Flutter: a
pointer event for a tap or a drag, `EditableTextState` for text,
`Scrollable.ensureVisible` for a scroll into view, and a poll of the element
tree for a wait. It reads the `finder` JSON of the step itself. The steps
`driverCommand`, the probes and the traces are skipped. A target that does not
appear stops the walk with a reason on the plaque. A `dateText` or a declared
date finder reads the date formats and the date key templates of the catalogue,
which the runner builds out of the `flutter_automation:` section of
`pubspec.yaml`. Pass `AutomationPlayerSettings.readLocale` to name the locale
of the formats.

While a walk runs, `AutomationPanelLauncher` puts an `AutomationInputGate` above
the app. The gate covers the dialogs and the sheets, blocks the finger and
lets the events of the player through. The plaque and the QA button stand above
the gate inside an `AutomationInputPassThrough`, so the finger reaches them and
a tap of the player goes through them. The launcher sets
`controller.isLauncherVisible`: the gate and the back button block only while
the launcher shows. Collapsed, the plaque is one line: a cross that ends the
walk and leaves the app on its screen, the flow and the step, and a round
button that does the next step. Open, it names the next action or lists the
branches of a fork above the pinned Exit and Next step buttons. The variant of
the walk is the selected branch, so Next step goes on at once. After a failed
step the main button reads Try again; when no action is left it reads Finish.
The body scrolls, and the tester drags the plaque down by its head.

The gate blocks pointers only. The soft keyboard of the tester still types into
the app during a walk.

An autorun (`AutomationAutorunPage`, the button Restart and run) shows the
`AutomationTouchIndicator` circle and nothing else while it plays its steps. A
failure brings the plaque back, and Try again runs the autorun again.

An autorun and the Finish of a manual walk end with the run sheet: the requests
scroll above the pinned Share logs, Run again and Exit buttons; Exit is the
main button. The controller
saves the report of the run to `runs/<time>/report.json` of the state store.
`onShare` of the definition receives that file and shares it; without it the
sheet has no Share logs.

The targets of the app reach the player only in a build with
`ENABLE_AUTOMATION_MARKING=true`.

`wrapButton` wraps the QA button, so the project marks it for automation.
`startPosition` sets where the button stands before the tester drags it; the
default is the bottom right. A driver tap lands on the centre of its target, so
a project moves the button off the controls its flows tap.

The project owns the debug menu, the gesture that opens it and the restart.
`AutomationModeController` switches between server and mock and writes the
choice to `state.json`. `AutomationMockModeTile` is a ready tile for it. It is an
`AutomationPanelSwitchTile`, so it fits an `AutomationPanelSheet`.

## Catalogue

`fvm dart run tool/run_flows.dart --qa-catalogue assets/qa_catalogue.json
--recordings <dir>` builds the catalogue out of the flows that set
`isInQaCatalogue: true` and the recordings of their runs. See
`flutter_automation_runner`.
