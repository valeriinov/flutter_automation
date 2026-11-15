# Changelog

## 0.7.0

- Blocks, pages and a theme of their own for the QA panel of an app that runs
  on the mock.
- `AutomationPanelLauncher` shows the QA button and the walk strip. It takes
  `wrapButton` and `startPosition`.
- `AutomationPanelController` holds the overrides of the tester, follows the
  journal to move the manual walk and sends the system back button to the
  panel. The project creates it before `runApp`.
- `AutomationModeController` switches between server and mock.
