# flutter_automation_mock_dio

`MockDioHttpClientAdapter`: a Dio `HttpClientAdapter` that answers the requests
of an app from the mock of
[`flutter_automation_mock`](../flutter_automation_mock).

## Libraries

| Import | Host-safe | Holds |
| --- | --- | --- |
| `package:flutter_automation_mock_dio/flutter_automation_mock_dio.dart` | No, imports Flutter and Dio | `MockDioHttpClientAdapter`, `MockDioRequest`. |

Nothing here runs on the host. A flow never imports this package.

## API

The adapter replaces the transport, the lowest point where the app can use a
fake. Every interceptor of the Dio still runs: auth headers, token refresh,
logging, error translation. Only the socket is fake.

```dart
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
```

- A path that an endpoint of the mock owns is answered from the mock.
- Any other path goes to `networkAdapter`, so a scenario that leaves a section
  out still uses the remote environment for it.
- A connection failure of the scenario raises `DioException.connectionError`,
  as a device without a connection does.
- A `Uint8List` body and a multipart body reach the responder through
  `MockApiRequest.bytes` and `MockApiRequest.body`.

## `pubspec.yaml` keys

None.
