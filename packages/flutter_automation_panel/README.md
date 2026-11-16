# flutter_automation_panel

The builder of the QA panel for an app that runs on `flutter_automation_mock`.
A tester picks a flow and its outcome, changes the answer of one request and
starts a walk. A start shows the restart screen `Close and open the app`, and
the tester closes and opens the app. The player of the panel then does each
step of the flow inside the app: one action per tap of Next step in a manual
walk, every step in a row in an autorun. The package depends on the mock and on
`flutter_automation`, never on `flutter_driver` or the runner. Its interface is
in English and has a theme of its own, `AutomationPanelTheme`.

## Build a panel

```dart
final bootstrap = await AutomationModeBootstrap.restore(
  directory: '${supportDirectory.path}/automation',
  isSwitchable: kReleaseMode,
);
final catalogue = await AutomationCatalogueAsset.load(
  rootBundle,
  'assets/qa_catalogue.json',
);

final controller = AutomationPanelController(
  AutomationPanelDefinition.standard(
    mock: mock,
    catalogue: catalogue ?? const AutomationCatalogue(),
    isRestartRequired: bootstrap.isRestartRequired,
    sections: [
      AutomationSectionPanel.fromSection(catalogSection, api: catalogApi),
    ],
    onShare: (context, report) => shareFile(context, report),
  ),
);

MaterialApp(
  builder: (context, child) => AutomationRestartOverlay(
    isRestartRequired: bootstrap.isRestartRequired,
    child: AutomationPanelLauncher(
      controller: controller,
      isVisible: showDebugTools,
      child: child ?? const SizedBox(),
    ),
  ),
);
```

`AutomationModeBootstrap.restore` reads the saved mode before the dependency
injection. Build the mock with `isEnabled: isMockEnabled && bootstrap.isOnMock`
and `stateStore: bootstrap.store`. `isSwitchable: false` keeps the app on the
mock.

`AutomationCatalogueAsset.load` returns `null` when the asset is missing or
does not hold a catalogue. The project then passes
`catalogue ?? const AutomationCatalogue()` and keeps the panel.
`AutomationPanelDefinition.standard` builds the pages Flows,
Autorun, Sections and Log. `wrapPage` wraps each page, so the project marks it
for automation. A project with other pages uses the plain
`AutomationPanelDefinition` constructor and its own `pages`.

`AutomationSectionPanel.fromSection` takes the texts from the declarations: the
title and the description of the `MockSection`, the `MockProfile` titles and
descriptions, and the `title` of each `MockApiEndpoint`. A card of a section
that has an api and no `MockSection` uses `AutomationSectionPanel(title: ...,
api: ...)`.

## Language

The package ships English only. `AutomationPanelStrings` is a class with a
`const` constructor, one getter per text and one method per counted phrase
(`changeCount`, `requestCount`, `stepCount`, `variantCount`, `overrideCount`,
`profileSheetTitle`, `latencyLabel`). The failure reasons of the player are
methods too: `stepHasNoAction`, `stepHasUnknownAction`, `stepHasNoTarget`,
`stepDidNotAppear`, `stepDidNotGo`, `stepDidNotBecomeTappable`,
`stepCannotBeTapped`, `timeoutMilliseconds` and `timeoutSeconds`. The
reasons `noFocusedTextField` and `walkStopped` are getters. Its `languageCode`
is `'en'`. A project that needs another
language extends the class, overrides what it translates and passes the
subclass as `strings:` of the definition:

```dart
class UkrainianStrings extends AutomationPanelStrings {
  const UkrainianStrings();

  @override
  String get languageCode => 'uk';

  @override
  String get flowsTab => 'Потоки';

  @override
  String changeCount(int count) => '$count зміни';
}
```

The panel reads the texts of sections, profiles, requests and the catalogue in
`languageCode` and falls back to `en`, then to the first text.
`AutomationPanelStrings.of(context)` gives the strings of the nearest panel and
the English ones outside a panel. `AutomationRestartOverlay`,
`AutomationMockModeTile` and `showAutomationMockModeSheet` take an optional
`strings` parameter. They use the strings of the nearest panel when it is
missing, so a project that stands them outside the panel passes it.

In a debug build the controller asserts that every `restartKeys` entry of a
section is a key of the settings JSON, in the defaults or in a profile.

The project creates the controller before `runApp`: it handles the system back
button for the panel and, while a walk runs, swallows it from the first frame.

## Walk and autorun

`controller.startWalk(flow, variant, mode: ...)` saves the scenario of the
variant and the walk, and sets `isRestartRequired` to true, whatever the
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
`onShare` of the definition receives the context of the layer and that file and
shares it; without it the sheet has no Share logs.

The targets of the app reach the player only in a build with
`ENABLE_AUTOMATION_MARKING=true`.

`wrapButton` wraps the QA button, so the project marks it for automation.
`startPosition` sets where the button stands before the tester drags it; the
default is the bottom right. A driver tap lands on the centre of its target, so
a project moves the button off the controls its flows tap.

`AutomationRestartOverlay` shows the screen `Close and open the app` over the
app while `isRestartRequired` is true. It needs no panel controller, so it
works in the server mode too.

The project owns the debug menu and the gesture that opens it.
`bootstrap.createModeController()` gives the `AutomationModeController` that
switches between server and mock, writes the choice to `state.json` and sets
`isRestartRequired`. `AutomationMockModeTile` is a ready tile for it. It is an
`AutomationPanelSwitchTile`, so it fits an `AutomationPanelSheet`. A build that
cannot switch (`isSwitchable: false`, such as a debug build) always runs on the
mock, and `createModeController()` returns `null` there. The project calls it
only when the mock is on, and shows the tile only when the controller is not
`null`.

## Catalogue

`fvm dart run tool/run_flows.dart --qa-catalogue assets/qa_catalogue.json
--recordings <dir>` builds the catalogue out of the flows that set
`isInQaCatalogue: true` and the recordings of their runs. See
`flutter_automation_runner`.
