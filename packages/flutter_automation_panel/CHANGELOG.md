# Changelog

## 0.11.0

- Version bump with `flutter_automation_atlas` 0.11.0.

## 0.10.0

- `AutomationCatalogueAsset.load` throws an
  `AutomationCatalogueVersionException` for a catalogue without `version: 2`.
  It answered `null` before. Migration: regenerate the catalogue.
- The Flows tab draws area, then group, then flow. It lists the areas in the
  order of their first group. A group without an area stays flat.

## 0.9.4

- New `backendErrorStatusCodes` on `AutomationPanelDefinition` and
  `AutomationResponseSheet`, and `AutomationPanelController.backendErrorStatusCodesOf`.
  A code with statuses takes its first status when chosen, and the sheet offers
  its statuses alone; a chosen status leaves out the codes it does not come
  with. A code without an entry keeps any status.

## 0.9.3

- Version bump with `flutter_automation_mock` 0.9.3.

## 0.9.2

- Documentation: the README describes the backend error codes, the overrides
  of a request and a full build of the mock for the panel.

## 0.9.1

- The response sheet offers the backend error codes of every request, then the
  codes of the endpoint of the request (`MockApiEndpoint.backendErrorCodes`).
  `AutomationPanelController.backendErrorCodesOf(path)` lists them. The codes
  of the endpoint need `readEndpointResolver` of the definition.
- The latency of the response sheet has no Default segment. A request with no
  latency of its own shows the latency of every request as chosen. A tap on it
  takes the latency of the request away.

## 0.9.0

- Breaking: `AutomationPanelStrings` is a class with a `const` constructor,
  getters and methods, not a class of static constants. `AutomationPanelStrings.X`
  becomes `strings.X` on an instance. A project extends the class to translate
  the panel and passes it as `AutomationPanelDefinition.strings` (English by
  default). `languageCode` names the language of the texts of sections,
  profiles, requests and the catalogue; the panel reads them with
  `AutomationLocalizedText.resolve`.
- Breaking: `describeCount`, `describeOverrideCount` and
  `AutomationLatencyNote.labels` are gone. The strings hold `changeCount`,
  `requestCount`, `stepCount`, `variantCount`, `overrideCount`,
  `latencyLabel` and `profileSheetTitle`.
- Breaking: `AutomationSectionPanel` takes `AutomationLocalizedText` titles and
  loses `profileTitles`, `profileDescriptions` and `requestTitles`. The new
  `AutomationSectionPanel.fromSection(section, api:)` reads the texts from the
  `MockSection`, its `MockProfile` values and the `MockApiEndpoint.title` values.
- `AutomationPanelStrings.of(context)` gives the strings of the nearest panel,
  English outside one. The `strings` parameter of `AutomationRestartOverlay`,
  `AutomationMockModeTile`, `showAutomationMockModeSheet`,
  `showAutomationRestartSheet`, `AutomationConfirmSheet`,
  `showAutomationConfirmSheet` and `AutomationPanelSheet` is optional: the
  strings of the nearest panel stand in.
- Breaking: the default constructor of `AutomationSectionPanel` has no
  `section:` parameter. A section with profiles uses
  `AutomationSectionPanel.fromSection`. `profileTitle(name, languageCode)`
  gives the title of a profile.
- The strings hold `latencyLabel` and the failure reasons of the player:
  `stepHasNoAction`, `stepHasUnknownAction`, `stepHasNoTarget`,
  `stepDidNotAppear`, `stepDidNotGo`, `stepDidNotBecomeTappable`,
  `stepCannotBeTapped`, `noFocusedTextField`, `walkStopped`,
  `timeoutMilliseconds` and `timeoutSeconds`. `AutomationFlowPlayer` takes
  `strings` and words its failures with them.
- Breaking: the exported `AutomationRequestRow.describeOverride` needs
  `strings`, and `AutomationFlowPlayer.describe` needs `languageCode`.
- Breaking: `AutomationPanelDefinition.onRestartRequired` and
  `AutomationModeController.onRestartRequired` are gone. Both take a required
  `ValueNotifier<bool> isRestartRequired` instead. The panel sets it to true at
  each start of a walk and at each change of a restart key, and `switchTo`
  sets it after it saves the mode.
- Breaking: `AutomationPanelDefinition.onShare` is
  `FutureOr<void> Function(BuildContext context, File report)`. The context is
  the one of the end-of-run layer.
- New `AutomationRestartOverlay`: the screen `Close and open the app` over the
  app while `isRestartRequired` is true, in both modes.
- New `AutomationModeBootstrap.restore`: reads the saved mode before the
  dependency injection and gives the state store, `isSwitchable`, `isOnMock`,
  the restart flag and `createModeController()`. `createModeController()`
  returns `null` when the build cannot switch the mode.
- New `AutomationCatalogueAsset.load` and `AutomationPanelDefinition.standard`:
  the catalogue loads from an asset in one call, and the panel gets the pages
  Flows, Autorun, Sections and Log, each wrapped by `wrapPage`.
- The controller of the panel asserts in a debug build that every key of
  `restartKeys` is a key of the settings JSON of its section, and names the
  section and the key.

## 0.8.7

- A change that restarts the app asks first in a sheet,
  `Apply and restart the app?`, with Cancel first and Apply second: a profile
  that needs a restart, a cross on the Changes page that restarts the app, a
  preset that restarts the app and the Mock mode switch. Cancel keeps the
  scenario and the mode.
- New `AutomationPanelController.needsRestartFor`, `showAutomationRestartSheet`
  and `applyAutomationScenario`.

## 0.8.6

- New Changes page: a tap on the status row opens it. It lists the outcome,
  the latency of every request, the profile of each section that differs from
  its defaults, the overrides of single requests and any other scenario key.
  A cross removes one change, and Reset all removes every change.
- The Log tab is the history of the requests: each row shows the status code
  it got, and a row whose answer an override gave says so under its path,
  such as `Answered by an override: error · Slow latency`. The rule of a path
  stays in the Response sheet and on the Changes page. Clear log, under the
  search beside the count of requests, empties the log.
- The status row counts every change the Changes page lists, such as
  `Custom mock · 3 changes`. `AutomationPanelStatus.changeCount` replaces
  `overrideCount`.
- Reset, Reset all, Clear log, a preset applied over changes and the delete
  of a preset ask first in an `AutomationConfirmSheet`, with Cancel first and
  the confirm button second.
- A section card shows the `description` of its section. The profile sheet
  shows the title of each profile, its line from `profileDescriptions`, its
  code in a chip and the `Restarts the app` badge when it needs a restart,
  and has a search over more than eight profiles. The value of a card row stands at its right edge.
- New `AutomationPanelDefinition.sections`, `AutomationPanelStatus.onPressed`,
  `AutomationRequestRow.note`, `AutomationChangesPage`,
  `AutomationConfirmSheet`, `showAutomationConfirmSheet`,
  `showAutomationResetSheet`, `AutomationPanelCard.subtitle` and
  `AutomationPanelRadioTile.code` and `AutomationPanelRadioTile.needsRestart`.

## 0.8.5

- The Response sheet sets the latency of one request: Default (the latency of
  every request), Fast, Real or Slow, with the delay line under it. Apply with
  no error chosen keeps the mock answer and sets only the latency. A second
  tap on a chosen code clears it. Use mock response and the cross of a request
  row clear both the error and the latency.
- A request row with a latency of its own is an override row, such as
  `Override: 500 · Slow latency`. The status row and the section cards count
  a request with an error, a latency or both once.
- A start of a walk or an autorun keeps every latency the scenario holds; an
  outcome adds its own on top.
- New `AutomationPanelDefinition.readEndpointResolver`. With it the panel
  matches an override as the mock does: on the exact path, else on the
  endpoint with a path id that owns the path. An exact endpoint under another
  path, such as `/banners/content` under `/banners`, no longer shows the
  override of the shorter path, for failures and latencies alike. Without it
  the panel matches the exact path only.
- New `AutomationLatencyNote`, `AutomationPanelController.latencies`,
  `latencyOf`, `setLatency`, `setResponse` and `clearOverride`.
  `AutomationRequestRow` takes `latency`, `describeOverride` takes named
  `failure` and `latency`, and `AutomationResponseSheet.onApply` takes the
  failure and the latency.

## 0.8.4

- A line under Response latency tells the delay of the chosen profile in
  milliseconds, such as `Answers in 150–400 ms`.
- The status row reads `Custom mock` when the tester changed the mock
  with no outcome or preset, such as a profile or the latency on the
  Sections tab. It reads `Default mock` only while nothing is changed.

## 0.8.3

- The Autorun, Sections and Log tabs show a search field, like the Flows tab.
  Autorun looks through the flow and outcome titles, Sections through the
  section titles, section names, request paths and request titles, Log through
  the method, the path and the status code.
- New `AutomationPanelSearchField` and `matchesSearchQuery`: the search field
  of a tab and the match of a query against the texts of one item.

## 0.8.2

- A step of the flow map holds its circle at the vertical centre of its card,
  with the rail above and below it.
- `AutomationPanelSheet` takes `hasGrabber`. The run sheet shows no grabber,
  because the tester cannot drag it.

## 0.8.1

- New `AutomationPanelStrings`: every text of the panel, in English. The
  widgets take their texts only from it.
- The walk plaque follows the walk controls design. Collapsed: a cross (Exit),
  the flow and the step, and a round Next step button. Open: a collapse button
  in the head, a scrolled body and pinned Exit and Next step buttons; Try again
  after a failure and Finish when no action is left. Only the head takes the
  drag. The corner radius moves with the height. `AutomationWalkPlaque` takes
  `flowTitle`, `collapsedStep`, `expandedStep`, `nextLabel`, `isFinishing` and
  `onNext`.
- At a fork the variant of the walk is the selected branch
  (`AutomationPanelController.selectedBranch`, `selectBranch`), and Next step
  takes it.
- `AutomationPanelController.finishWalk` ends a manual walk with the run sheet.
  A run of either mode saves `runs/<time>/report.json`. `AutomationRunSummary`
  holds `mode` and `report`.
- `AutomationPanelDefinition.onShare(File report)` replaces `onShareLogs`.
- The run sheet pins Share logs, Run again and Exit under the scrolled
  requests. Exit is the main button. `AutomationPanelSheet` takes a `footer`. `AutomationPanelButton`
  takes `leadingIcon` and `trailingIcon`.

## 0.8.0

- New `AutomationFlowPlayer`, `AutomationPlayerSettings`,
  `AutomationPlayerFinder`, `AutomationInputGate`, `AutomationInputPassThrough`
  and `AutomationTouchIndicator`: the steps of a flow run inside the app, with
  no driver. The package depends on `flutter_automation` for the locale marks.
- A walk blocks the finger and the system back button. The plaque shows the
  next action, Next step, the branches of a fork and a stop icon named Exit.
  The tester drags it down. The plaque has no Start over, Finish or answer
  chips. The controller no longer follows the journal. `AutomationWalkPlaque`
  reports a drag in `onDragged`, and the launcher moves the area that takes the
  finger with it. A long title wraps to a second line.
- The launcher sets `AutomationPanelController.isLauncherVisible`. The finger
  gate and the back button block only while it is true (`isInputBlocked`).
  The gate blocks pointers only: the soft keyboard still types into the app.
- New `AutomationAutorunPage` and `AutomationRunSummary`. The autorun shows the
  touch circle only while it plays its steps and ends with the run sheet. A
  failure shows the plaque with Try again (`isAutorunPlaying`). Any error of a
  step becomes the failure of the walk.
- `AutomationPanelController.startWalk(flow, variant, mode:)` calls
  `onRestartRequired` once, whatever the scenario held before. It takes the place of the flow map buttons Apply and start and Set
  state: the map has Restart and begin. New `playNext`, `runWalk`,
  `chooseBranch`, `exitWalk` and `resumeWalk`. `moveWalk`, `finishWalk`,
  `hideWalk` and `isWalkHidden` are removed.
- `AutomationPlayerSettings` has no `dateFormats` and `dateValueKeys`. The
  player reads them from the `AutomationCatalogue` that the runner builds, and
  `AutomationFlowPlayer` takes it in `catalogue`. A `dateText` finder fails
  when the locale has no format, as it does in the runner. The player holds the
  finger for a scroll without a drag for its `durationMs`.
- `AutomationPanelDefinition.onStart` is removed. It has `playerSettings` and
  `onShareLogs`.
- New `AutomationRestartNote`. `AutomationMockModeTile` is an
  `AutomationPanelSwitchTile`, and `showAutomationMockModeSheet` opens an
  `AutomationPanelSheet`. The package depends on `clock`.
- `AutomationPanelSheet` keeps its head still and scrolls the body only when
  the body does not fit, without stretch.

## 0.7.0

- Blocks, pages and a theme of their own for the QA panel of an app that runs
  on the mock.
- `AutomationPanelLauncher` shows the QA button and the walk strip. It takes
  `wrapButton` and `startPosition`.
- `AutomationPanelController` holds the overrides of the tester, follows the
  journal to move the manual walk and sends the system back button to the
  panel. The project creates it before `runApp`.
- `AutomationModeController` switches between server and mock.
