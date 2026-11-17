import 'package:flutter_automation_mock/src/contract/mock_api_responder.dart';
import 'package:flutter_automation_mock/src/scenario/automation_localized_text.dart';

/// {@category Utils}
///
/// One endpoint the mock backend owns.
///
/// A path the app extends with a trailing segment declares [hasPathId]; the
/// segment reaches the responder through `MockApiRequest.pathSegment`, and
/// through `MockApiRequest.pathId` when it parses as an id.
class MockApiEndpoint {
  /// Path of the endpoint, relative to the base url.
  final String path;

  /// Builds the answer to a request for [path].
  final MockApiResponder respond;

  /// Whether the app appends a trailing segment to [path].
  final bool hasPathId;

  /// Title of the request in the QA panel, missing when the path says it. A
  /// request without a title shows its path.
  final AutomationLocalizedText? title;

  /// Backend error codes that only this endpoint answers with. The QA panel
  /// offers them for this request beside the codes of every request.
  final List<String> backendErrorCodes;

  const MockApiEndpoint({
    required this.path,
    required this.respond,
    this.title,
    this.hasPathId = false,
    this.backendErrorCodes = const [],
  });
}
