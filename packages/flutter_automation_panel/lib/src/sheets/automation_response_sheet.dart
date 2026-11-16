import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_code_badge.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button_group.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_chips.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_option.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_radio_tile.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_label.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_sheet.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The sheet that sets the answer of one request: an error code, a backend
/// error code and a message, or no network.
///
/// The mock answer is the default. Nothing selects it: the button
/// [onApply] with `null` removes the override.
class AutomationResponseSheet extends StatefulWidget {
  /// HTTP method of the request.
  final String method;

  /// Path of the request.
  final String path;

  /// Status code of the mock answer, missing when the mock names none.
  final int? mockStatusCode;

  /// What the mock answer holds, in words.
  final String mockDescription;

  /// The override the request has now, missing when it has none.
  final MockApiFailure? initial;

  /// Backend error codes the sheet offers as chips.
  final List<String> backendErrorCodes;

  /// Called with the override the tester sets, or `null` for the mock answer.
  final ValueChanged<MockApiFailure?> onApply;

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return AutomationPanelSheet(
      title: AutomationPanelStrings.response,
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
          const AutomationPanelLabel(text: AutomationPanelStrings.errorCode),
          AutomationPanelChips<int>(
            options: [
              for (final code in _offeredStatusCodes)
                AutomationPanelOption(value: code, label: '$code'),
            ],
            selected: _isNoNetwork ? null : _statusCode,
            selectedColor: theme.danger,
            customLabel: AutomationPanelStrings.custom,
            onChanged: _selectStatusCode,
            onCustomPressed: _askForStatusCode,
          ),
          const AutomationPanelLabel(
            text: AutomationPanelStrings.backendErrorCode,
          ),
          AutomationPanelChips<String>(
            options: [
              for (final code in _offeredErrorCodes)
                AutomationPanelOption(value: code, label: code),
            ],
            selected: _errorCode,
            selectedColor: theme.danger,
            isMono: true,
            customLabel: AutomationPanelStrings.custom,
            onChanged: _selectErrorCode,
            onCustomPressed: _askForErrorCode,
          ),
          const AutomationPanelLabel(text: AutomationPanelStrings.message),
          _MessageField(controller: _messageController),
          AutomationPanelRadioTile(
            title: AutomationPanelStrings.noNetwork,
            subtitle: AutomationPanelStrings.noNetworkNote,
            isSelected: _isNoNetwork,
            activeColor: theme.danger,
            onPressed: _toggleNoNetwork,
          ),
          AutomationPanelButtonGroup(
            buttons: [
              AutomationPanelButton(
                label: AutomationPanelStrings.apply,
                kind: AutomationPanelButtonKind.primary,
                onPressed: _apply,
              ),
              AutomationPanelButton(
                label: AutomationPanelStrings.useMockResponse,
                onPressed: () => widget.onApply(null),
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

  Future<void> _askForStatusCode() async {
    final text = await _askForText(
      AutomationPanelStrings.statusCode,
      TextInputType.number,
    );

    final code = int.tryParse(text ?? '');

    if (code != null) {
      _selectStatusCode(code);
    }
  }

  Future<void> _askForErrorCode() async {
    final text = await _askForText(
      AutomationPanelStrings.backendErrorCode,
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
    if (_isNoNetwork) {
      widget.onApply(const MockApiFailure(isConnectionError: true));

      return;
    }

    final message = _messageController.text.trim();

    widget.onApply(
      MockApiFailure(
        statusCode: _statusCode ?? 500,
        errorCode: _errorCode,
        message: message.isEmpty ? null : message,
      ),
    );
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
              AutomationPanelStrings.mockResponseOf(description),
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
    final theme = AutomationPanelTheme.of(context);

    return SizedBox(
      height: AutomationPanelTheme.buttonHeight,
      child: TextField(
        controller: controller,
        style: theme.textStyle(size: 15),
        decoration: const InputDecoration(
          hintText: AutomationPanelStrings.message,
        ),
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
          child: const Text(AutomationPanelStrings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text(AutomationPanelStrings.ok),
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
/// override that [AutomationPanelController.failureOf] names for it.
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
        backendErrorCodes: controller.definition.backendErrorCodes,
        onClose: () => Navigator.of(sheetContext).pop(),
        onApply: (failure) {
          controller.setFailure(path, failure);
          Navigator.of(sheetContext).pop();
        },
      );
    },
  );
}
