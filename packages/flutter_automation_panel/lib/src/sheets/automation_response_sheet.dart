import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_code_badge.dart';
import 'package:flutter_automation_panel/src/blocks/automation_latency_note.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button_group.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_chips.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_option.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_radio_tile.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_segments.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_sheet.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The sheet that sets the answer of one request: an error code, a backend
/// error code and a message, or no network, and the latency of the request.
///
/// The mock answer is the default. A tap on a chosen code clears it. Apply
/// with no error chosen keeps the mock answer and sets only the latency. Use
/// mock response calls [onApply] with `null` for both and removes every
/// override of the request.
///
/// A request with no latency of its own shows the latency of every request as
/// chosen. A tap on another profile gives the request its own latency, and a
/// tap on the latency of every request takes it away.
class AutomationResponseSheet extends StatefulWidget {
  /// HTTP method of the request.
  final String method;

  /// Path of the request.
  final String path;

  /// Status code of the mock answer, missing when the mock names none.
  final int? mockStatusCode;

  /// What the mock answer holds, in words.
  final String mockDescription;

  /// The failure the request has now, missing when it has none.
  final MockApiFailure? initial;

  /// The latency profile of the request alone now, missing when the request
  /// follows every request.
  final MockLatencyProfile? initialLatency;

  /// The latency profile of every request.
  final MockLatencyProfile globalLatency;

  /// Backend error codes the sheet offers as chips.
  final List<String> backendErrorCodes;

  /// Called with the failure and the latency profile the tester sets. A `null`
  /// failure keeps the mock answer, and a `null` profile follows every request.
  final void Function(MockApiFailure? failure, MockLatencyProfile? latency)
  onApply;

  /// Called when the tester closes the sheet.
  final VoidCallback onClose;

  const AutomationResponseSheet({
    required this.method,
    required this.path,
    required this.mockDescription,
    required this.onApply,
    required this.onClose,
    this.mockStatusCode,
    this.initial,
    this.initialLatency,
    this.globalLatency = MockLatencyProfile.realistic,
    this.backendErrorCodes = const [],
    super.key,
  });

  @override
  State<AutomationResponseSheet> createState() =>
      _AutomationResponseSheetState();
}

class _AutomationResponseSheetState extends State<AutomationResponseSheet> {
  static const _statusCodes = [400, 401, 404, 429, 500, 503];

  final TextEditingController _messageController = TextEditingController();

  int? _statusCode;
  String? _errorCode;
  bool _isNoNetwork = false;
  MockLatencyProfile? _latency;

  List<int> get _offeredStatusCodes {
    final chosen = _statusCode;

    return [
      ..._statusCodes,
      if (chosen != null && !_statusCodes.contains(chosen)) chosen,
    ];
  }

  List<String> get _offeredErrorCodes {
    final chosen = _errorCode;

    return [
      ...widget.backendErrorCodes,
      if (chosen != null && !widget.backendErrorCodes.contains(chosen)) chosen,
    ];
  }

  @override
  void initState() {
    super.initState();

    final initial = widget.initial;

    _statusCode = initial?.statusCode;
    _errorCode = initial?.errorCode;
    _isNoNetwork = initial?.isConnectionError ?? false;
    _messageController.text = initial?.message ?? '';
    _latency = widget.initialLatency;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);

    return AutomationPanelSheet(
      title: strings.response,
      onClose: widget.onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AutomationPanelTheme.gapMedium,
        children: [
          _PathLine(method: widget.method, path: widget.path),
          _MockResponse(
            statusCode: widget.mockStatusCode,
            description: widget.mockDescription,
          ),
          AutomationPanelLabel(text: strings.errorCode),
          AutomationPanelChips<int>(
            options: [
              for (final code in _offeredStatusCodes)
                AutomationPanelOption(value: code, label: '$code'),
            ],
            selected: _isNoNetwork ? null : _statusCode,
            selectedColor: theme.danger,
            customLabel: strings.custom,
            onChanged: _toggleStatusCode,
            onCustomPressed: _askForStatusCode,
          ),
          AutomationPanelLabel(text: strings.backendErrorCode),
          AutomationPanelChips<String>(
            options: [
              for (final code in _offeredErrorCodes)
                AutomationPanelOption(value: code, label: code),
            ],
            selected: _errorCode,
            selectedColor: theme.danger,
            isMono: true,
            customLabel: strings.custom,
            onChanged: _toggleErrorCode,
            onCustomPressed: _askForErrorCode,
          ),
          AutomationPanelLabel(text: strings.message),
          _MessageField(controller: _messageController),
          AutomationPanelRadioTile(
            title: strings.noNetwork,
            subtitle: strings.noNetworkNote,
            isSelected: _isNoNetwork,
            activeColor: theme.danger,
            onPressed: _toggleNoNetwork,
          ),
          AutomationPanelLabel(text: strings.requestLatency),
          AutomationPanelSegments<MockLatencyProfile>(
            options: [
              for (final profile in MockLatencyProfile.values)
                AutomationPanelOption(
                  value: profile,
                  label: strings.latencyLabel(profile),
                ),
            ],
            selected: _latency ?? widget.globalLatency,
            onChanged: _selectLatency,
          ),
          AutomationLatencyNote(
            profile: _latency ?? widget.globalLatency,
            isInherited: _latency == null,
          ),
          AutomationPanelButtonGroup(
            buttons: [
              AutomationPanelButton(
                label: strings.apply,
                kind: AutomationPanelButtonKind.primary,
                onPressed: _apply,
              ),
              AutomationPanelButton(
                label: strings.useMockResponse,
                onPressed: () => widget.onApply(null, null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _toggleStatusCode(int code) {
    if (code == _statusCode) {
      setState(() => _statusCode = null);

      return;
    }

    _selectStatusCode(code);
  }

  void _toggleErrorCode(String code) {
    if (code == _errorCode) {
      setState(() => _errorCode = null);

      return;
    }

    _selectErrorCode(code);
  }

  void _selectStatusCode(int code) {
    setState(() {
      _statusCode = code;
      _isNoNetwork = false;
    });
  }

  void _selectErrorCode(String code) {
    setState(() {
      _errorCode = code;
      _isNoNetwork = false;
    });
  }

  void _toggleNoNetwork() {
    setState(() => _isNoNetwork = !_isNoNetwork);
  }

  void _selectLatency(MockLatencyProfile profile) {
    setState(() => _latency = profile == widget.globalLatency ? null : profile);
  }

  Future<void> _askForStatusCode() async {
    final strings = AutomationPanelStrings.of(context);

    final text = await _askForText(strings.statusCode, TextInputType.number);

    final code = int.tryParse(text ?? '');

    if (code != null) {
      _selectStatusCode(code);
    }
  }

  Future<void> _askForErrorCode() async {
    final strings = AutomationPanelStrings.of(context);

    final text = await _askForText(
      strings.backendErrorCode,
      TextInputType.text,
    );

    if (text != null && text.isNotEmpty) {
      _selectErrorCode(text);
    }
  }

  Future<String?> _askForText(String title, TextInputType keyboardType) {
    return showDialog<String>(
      context: context,
      builder: (_) => _TextPrompt(title: title, keyboardType: keyboardType),
    );
  }

  void _apply() {
    widget.onApply(_tryBuildFailure(), _latency);
  }

  MockApiFailure? _tryBuildFailure() {
    if (_isNoNetwork) {
      return const MockApiFailure(isConnectionError: true);
    }

    final message = _messageController.text.trim();

    if (!_hasError(message)) {
      return null;
    }

    return MockApiFailure(
      statusCode: _statusCode ?? 500,
      errorCode: _errorCode,
      message: message.isEmpty ? null : message,
    );
  }

  bool _hasError(String message) {
    return _statusCode != null || _errorCode != null || message.isNotEmpty;
  }
}

class _PathLine extends StatelessWidget {
  final String method;
  final String path;

  const _PathLine({required this.method, required this.path});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Text(
      '$method $path'.trim(),
      style: theme.textStyle(size: 12, color: theme.textPath, isMono: true),
    );
  }
}

class _MockResponse extends StatelessWidget {
  final int? statusCode;
  final String description;

  const _MockResponse({required this.statusCode, required this.description});

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);
    final code = statusCode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(AutomationPanelTheme.buttonRadius),
      ),
      child: Row(
        spacing: 10,
        children: [
          if (code != null) AutomationCodeBadge(code: code),
          Expanded(
            child: Text(
              strings.mockResponseOf(description),
              style: theme.textStyle(size: 13, color: theme.textPath),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageField extends StatelessWidget {
  final TextEditingController controller;

  const _MessageField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);

    return SizedBox(
      height: AutomationPanelTheme.buttonHeight,
      child: TextField(
        controller: controller,
        style: theme.textStyle(size: 15),
        decoration: InputDecoration(hintText: strings.message),
      ),
    );
  }
}

class _TextPrompt extends StatefulWidget {
  final String title;
  final TextInputType keyboardType;

  const _TextPrompt({required this.title, required this.keyboardType});

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(strings.ok),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// {@category Widgets}
///
/// Shows the [AutomationResponseSheet] of one request and applies the choice
/// of the tester to [controller].
///
/// The [context] parameter is the context of the panel.
/// The [controller] parameter is the controller that holds the overrides.
/// The [path] parameter is the path of the request. The sheet shows the
/// overrides that [AutomationPanelController.failureOf] and
/// [AutomationPanelController.latencyOf] name for it.
/// The [mockDescription] parameter says what the mock answer holds.
/// The [method] parameter is the HTTP method, empty when it is unknown.
/// The [mockStatusCode] parameter is the status code of the mock answer.
Future<void> showAutomationResponseSheet({
  required BuildContext context,
  required AutomationPanelController controller,
  required String path,
  required String mockDescription,
  String method = '',
  int? mockStatusCode,
}) {
  return showAutomationPanelSheet<void>(
    context: context,
    builder: (sheetContext) {
      return AutomationResponseSheet(
        method: method,
        path: path,
        mockStatusCode: mockStatusCode,
        mockDescription: mockDescription,
        initial: controller.failureOf(path),
        initialLatency: controller.latencyOf(path),
        globalLatency: controller.mock.latency.profile,
        backendErrorCodes: controller.backendErrorCodesOf(path),
        onClose: () => Navigator.of(sheetContext).pop(),
        onApply: (failure, latency) {
          controller.setResponse(path, failure: failure, latency: latency);
          Navigator.of(sheetContext).pop();
        },
      );
    },
  );
}
