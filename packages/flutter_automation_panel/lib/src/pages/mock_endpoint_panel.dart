import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_request_row.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// One endpoint of a mock api: a title and a request row that shows its
/// override.
///
/// The row shows [failure] and [latency], the overrides of the endpoint.
class MockEndpointPanel extends StatelessWidget {
  /// The endpoint the row stands for.
  final MockApiEndpoint endpoint;

  /// Name of the request in words, such as Send code.
  final String title;

  /// The failure of the endpoint, missing when the mock answers it.
  final MockApiFailure? failure;

  /// The latency profile of the endpoint alone, missing when it follows every
  /// request.
  final MockLatencyProfile? latency;

  /// Called when the tester taps the row.
  final VoidCallback onPressed;

  /// Called when the tester taps the cross of the override.
  final VoidCallback onClearOverride;

  const MockEndpointPanel({
    required this.endpoint,
    required this.title,
    required this.failure,
    required this.latency,
    required this.onPressed,
    required this.onClearOverride,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Text(title, style: theme.textStyle(size: 13, weight: FontWeight.w600)),
        AutomationRequestRow(
          method: '',
          path: endpoint.path,
          failure: failure,
          latency: latency,
          onPressed: onPressed,
          onClearOverride: onClearOverride,
        ),
      ],
    );
  }
}
