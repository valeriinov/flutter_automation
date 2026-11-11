# Changelog

## 0.4.0

- Breaking: the core has no Dio dependency. `MockApiRequest` and
  `MockApiResponse` carry no Dio types; `MockApiHttpClientAdapter` moves to the
  new package `flutter_automation_mock_dio` as `MockDioHttpClientAdapter`.
- New library `mock_feature.dart`, free of Flutter imports: `MockFeature` with
  profiles and a field schema, `MockScenario`, `MockOverride`,
  `MockLatencyProfile` and the names of the mock commands.
- New `AutomationMock`: `init` before the project's dependency injection,
  `substitute` for any dependency, the `mock.apply`, `journal.read` and
  `locale.apply` commands with the project callbacks `onApply` and `onLocale`,
  and the scenario saved to a file and read at the next launch.
