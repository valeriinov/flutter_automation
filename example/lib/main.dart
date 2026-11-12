import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_automation_driver/driver_extension.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock_dio/flutter_automation_mock_dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:example/automation/saved_language_file.dart';
import 'package:example/automation/screen_name_observer.dart';
import 'package:example/catalog/catalog_api.dart';
import 'package:example/example_app.dart';
import 'package:example/mock/catalog_mock_section.dart';
import 'package:example/mock/mock_catalog_api.dart';
import 'package:example/mock/example_mock_settings.dart';

Future<void> main() async {
  final screenNameObserver = ScreenNameObserver();
  final savedLanguage = SavedLanguageFile(Directory.systemTemp.path);
  final locale = ValueNotifier(Locale(savedLanguage.read() ?? 'en'));

  AutomationInstaller.maybeInstall(
    screenReader: () => {
      AutomationProtocol.screenNameKey: screenNameObserver.screenName,
    },
    localeApplier: (languageCode) async {
      locale.value = Locale(languageCode);

      await savedLanguage.save(languageCode);
    },
  );
  WidgetsFlutterBinding.ensureInitialized();

  MockScenarioBackend? backend;

  final mock = await AutomationMock.init(
    isEnabled: isMockEnabled,
    scenarioDirectory: (await getTemporaryDirectory()).path,
    sections: isMockEnabled ? [catalogMockSection] : const [],
    onScenarioApplied: (scenario) => backend?.rebuild(),
  );

  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  final networkAdapter = dio.httpClientAdapter;

  dio.httpClientAdapter = mock.substitute(
    real: networkAdapter,
    fake: (mock) {
      final scenarioBackend = MockScenarioBackend(
        readScenario: () => mock.scenario,
        buildApis: () => [MockCatalogApi(mock)],
        buildFailureBody: (failure) => {
          'code': failure.errorCode,
          'message': failure.message,
        },
      );

      backend = scenarioBackend;

      return MockDioHttpClientAdapter(
        transport: MockApiTransport(
          backend: scenarioBackend,
          journal: mock.journal,
        ),
        networkAdapter: networkAdapter,
      );
    },
  );

  runApp(
    ExampleApp(
      catalogApi: CatalogApi(dio),
      screenNameObserver: screenNameObserver,
      locale: locale,
    ),
  );
}
