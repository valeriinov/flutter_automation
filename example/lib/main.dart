import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_automation_driver/driver_extension.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock_dio/flutter_automation_mock_dio.dart';
import 'package:flutter_automation_panel/flutter_automation_panel.dart';
import 'package:path_provider/path_provider.dart';

import 'package:example/automation/screen_name_observer.dart';
import 'package:example/catalog/catalog_api.dart';
import 'package:example/example_app.dart';
import 'package:example/mock/catalog_mock_section.dart';
import 'package:example/mock/mock_catalog_api.dart';
import 'package:example/mock/example_mock_settings.dart';
import 'package:example/panel/example_panel.dart';

const _failureMessages = {
  'rateLimited': AutomationLocalizedText({
    'en': 'Too many requests. Try again later.',
    'uk': 'Забагато запитів. Спробуйте пізніше.',
  }),
};

Future<void> main() async {
  final screenNameObserver = ScreenNameObserver();
  final locale = ValueNotifier(const Locale('en'));

  AutomationInstaller.maybeInstall(
    screenReader: () => {
      AutomationProtocol.screenNameKey: screenNameObserver.screenName,
    },
    localeApplier: (languageCode) => locale.value = Locale(languageCode),
  );

  final launchLanguageCode = AutomationInstaller.launchLanguageCode;

  if (launchLanguageCode != null) {
    locale.value = Locale(launchLanguageCode);
  }

  WidgetsFlutterBinding.ensureInitialized();

  MockScenarioBackend? backend;

  final bootstrap = await AutomationModeBootstrap.restore(
    directory: '${(await getApplicationSupportDirectory()).path}/automation',
    isSwitchable: kReleaseMode,
  );

  final isOnMock = isMockEnabled && bootstrap.isOnMock;

  final mock = await AutomationMock.init(
    isEnabled: isOnMock,
    scenarioDirectory: (await getTemporaryDirectory()).path,
    stateStore: bootstrap.store,
    sections: isOnMock ? [catalogMockSection] : const [],
    onScenarioApplied: (scenario) => backend?.rebuild(),
    onScenarioUpdated: (scenario) => backend?.rebuild(),
  );

  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  final networkAdapter = dio.httpClientAdapter;

  dio.httpClientAdapter = mock.substitute(
    real: networkAdapter,
    fake: (mock) {
      final scenarioBackend = MockScenarioBackend(
        readScenario: () => mock.scenario,
        buildApis: () => [MockCatalogApi(mock)],
        buildFailureBody: (failure, request) => {
          'code': failure.errorCode,
          'message': failure.resolveMessage(
            request,
            readText: (key, languageCode) =>
                _failureMessages[key]?.texts[languageCode],
            defaultLanguageCode: 'en',
          ),
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
      isRestartRequired: bootstrap.isRestartRequired,
      modeController: isMockEnabled ? bootstrap.createModeController() : null,
      panelController: isOnMock
          ? await buildExamplePanel(
              mock: mock,
              isRestartRequired: bootstrap.isRestartRequired,
            )
          : null,
    ),
  );
}
