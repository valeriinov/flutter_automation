import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_code_badge.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// One request: the code of its answer and its path. The path keeps its last
/// segment and shortens in the middle.
///
/// A request with a [failure] or a [latency] shows a red row that names the
/// override and holds a cross that removes it.
class AutomationRequestRow extends StatelessWidget {
  static const _crossWidth = 48.0;
  static const _overrideHeight = 52.0;

  /// HTTP method of the request.
  final String method;

  /// Path of the request.
  final String path;

  /// Status code of the answer the request gets, missing when unknown.
  final int? statusCode;

  /// The failure that replaces the answer, missing for the mock answer.
  final MockApiFailure? failure;

  /// The latency profile of the request alone, missing when the request
  /// follows every request.
  final MockLatencyProfile? latency;

  /// A line under the path of a row with no override, such as what answered
  /// the request.
  final String? note;

  /// Called when the tester taps the row.
  final VoidCallback? onPressed;

  /// Called when the tester taps the cross of an override.
  final VoidCallback? onClearOverride;

  const AutomationRequestRow({
    required this.method,
    required this.path,
    this.statusCode,
    this.failure,
    this.latency,
    this.note,
    this.onPressed,
    this.onClearOverride,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);

    if (failure == null && latency == null) {
      return _PlainRow(
        method: method,
        path: path,
        statusCode: statusCode,
        note: note,
        onPressed: onPressed,
      );
    }

    return _OverrideRow(
      method: method,
      path: path,
      description: describeOverride(
        strings: strings,
        failure: failure,
        latency: latency,
      ),
      onPressed: onPressed,
      onClearOverride: onClearOverride,
    );
  }

  /// The words that name the overrides of a request on an override row.
  ///
  /// The [failure] parameter is the failure of the request.
  /// The [latency] parameter is the latency profile of the request alone.
  /// The [strings] parameter holds the words.
  static String describeOverride({
    required AutomationPanelStrings strings,
    MockApiFailure? failure,
    MockLatencyProfile? latency,
  }) {
    return strings.overrideOf(
      [
        if (failure != null) _describeFailure(strings, failure),
        if (latency != null)
          strings.latencyOverrideOf(strings.latencyLabel(latency)),
      ].join(' · '),
    );
  }

  static String _describeFailure(
    AutomationPanelStrings strings,
    MockApiFailure failure,
  ) {
    if (failure.isConnectionError) {
      return strings.noNetwork;
    }

    final detail = failure.errorCode ?? failure.message ?? failure.messageKey;

    return detail == null
        ? '${failure.statusCode}'
        : '${failure.statusCode} $detail';
  }
}

class _PlainRow extends StatelessWidget {
  final String method;
  final String path;
  final int? statusCode;
  final String? note;
  final VoidCallback? onPressed;

  const _PlainRow({
    required this.method,
    required this.path,
    required this.statusCode,
    required this.note,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Material(
      color: theme.surfaceQuiet,
      borderRadius: BorderRadius.circular(AutomationPanelTheme.buttonRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AutomationPanelTheme.buttonRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AutomationPanelTheme.touchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              spacing: 10,
              children: [
                if (statusCode case final code?)
                  AutomationCodeBadge(code: code),
                Expanded(
                  child: _PathWithNote(method: method, path: path, note: note),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PathWithNote extends StatelessWidget {
  final String method;
  final String path;
  final String? note;

  const _PathWithNote({
    required this.method,
    required this.path,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final note = this.note;

    if (note == null) {
      return _PathText(method: method, path: path);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PathText(method: method, path: path),
          Text(
            note,
            style: theme.textStyle(
              size: 12,
              weight: FontWeight.w600,
              color: theme.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverrideRow extends StatelessWidget {
  final String method;
  final String path;
  final String description;
  final VoidCallback? onPressed;
  final VoidCallback? onClearOverride;

  const _OverrideRow({
    required this.method,
    required this.path,
    required this.description,
    required this.onPressed,
    required this.onClearOverride,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);
    final radius = BorderRadius.circular(AutomationPanelTheme.buttonRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.dangerSoft,
        borderRadius: radius,
        border: Border.all(color: theme.dangerLine),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AutomationRequestRow._overrideHeight,
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onPressed,
                borderRadius: radius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PathText(method: method, path: path),
                      Text(
                        description,
                        style: theme.textStyle(
                          size: 13,
                          weight: FontWeight.w600,
                          color: theme.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: AutomationRequestRow._crossWidth,
              height: AutomationRequestRow._overrideHeight,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: theme.dangerLine)),
              ),
              child: IconButton(
                onPressed: onClearOverride,
                tooltip: strings.removeOverride,
                icon: Icon(Icons.close, size: 20, color: theme.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathText extends StatelessWidget {
  final String method;
  final String path;

  const _PathText({required this.method, required this.path});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final style = theme.textStyle(
      size: 12,
      color: theme.textPath,
      isMono: true,
    );
    final cut = path.lastIndexOf('/') + 1;
    final prefix = path.substring(0, cut);
    final head = method.isEmpty ? prefix : '$method $prefix';
    final tail = path.substring(cut);

    return Row(
      children: [
        Flexible(
          child: Text(
            head,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(tail, style: style, maxLines: 1, softWrap: false),
      ],
    );
  }
}
