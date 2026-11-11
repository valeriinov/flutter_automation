import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_automation_driver/driver_extension.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_mock_dio/flutter_automation_mock_dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:example/automation/screen_name_observer.dart';
import 'package:example/catalog/catalog_api.dart';
import 'package:example/example_app.dart';
import 'package:example/mock/catalog_mock_feature.dart';
import 'package:example/mock/example_mock_runtime.dart';
import 'package:example/mock/example_mock_settings.dart';

Future<void> main() async {
  final screenNameObserver = ScreenNameObserver();

  AutomationInstaller.maybeInstall(
    screenReader: () => {
      AutomationProtocol.screenNameKey: screenNameObserver.screenName,
    },
  );
  WidgetsFlutterBinding.ensureInitialized();

  final mock = await AutomationMock.init(
    isEnabled: isMockEnabled,
    scenarioDirectory: (await getTemporaryDirectory()).path,
    features: [catalogMockFeature],
  );

  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  final networkAdapter = dio.httpClientAdapter;

  dio.httpClientAdapter = mock.substitute(
    real: networkAdapter,
    fake: (mock) => MockDioHttpClientAdapter(
      transport: MockApiTransport(
        runtime: ExampleMockRuntime(mock),
        journal: mock.journal,
      ),
      networkAdapter: networkAdapter,
    ),
  );

  runApp(
    ExampleApp(
      catalogApi: CatalogApi(dio),
      screenNameObserver: screenNameObserver,
    ),
  );
}
