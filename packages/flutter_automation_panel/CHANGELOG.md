# Changelog

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
