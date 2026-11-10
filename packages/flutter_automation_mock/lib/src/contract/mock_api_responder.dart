import 'dart:async';
import 'package:flutter_automation_mock/src/contract/mock_api_request.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_response.dart';

/// Builds the answer to a request that matched the endpoint of this responder.
typedef MockApiResponder =
    FutureOr<MockApiResponse> Function(MockApiRequest request);
