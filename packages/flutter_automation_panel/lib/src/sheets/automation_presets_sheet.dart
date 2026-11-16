import 'package:flutter/material.dart';
import 'package:flutter_automation_mock/flutter_automation_mock.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_button.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_sheet.dart';
import 'package:flutter_automation_panel/src/panel/automation_panel_controller.dart';
import 'package:flutter_automation_panel/src/sheets/automation_confirm_sheet.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The sheet of the saved presets: the tester saves the current scenario under
/// a name, applies a saved one or deletes it.
class AutomationPresetsSheet extends StatefulWidget {
  /// The controller whose scenario the presets hold.
  final AutomationPanelController controller;

  /// Called when the tester closes the sheet.
  final VoidCallback onClose;

  const AutomationPresetsSheet({
    required this.controller,
    required this.onClose,
    super.key,
  });

  @override
  State<AutomationPresetsSheet> createState() => _AutomationPresetsSheetState();
}

class _AutomationPresetsSheetState extends State<AutomationPresetsSheet> {
  final TextEditingController _nameController = TextEditingController();

  List<String> _names = const [];
  bool _isNameRejected = false;

  AutomationStateStore? get _store => widget.controller.mock.stateStore;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);

    return AutomationPanelSheet(
      title: strings.presets,
      onClose: widget.onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AutomationPanelTheme.gapSmall,
        children: [
          SizedBox(
            height: AutomationPanelTheme.buttonHeight,
            child: TextField(
              controller: _nameController,
              style: theme.textStyle(size: 15),
              decoration: InputDecoration(hintText: strings.presetName),
              onChanged: (_) => setState(() => _isNameRejected = false),
            ),
          ),
          if (_isNameRejected)
            Text(
              strings.presetNameRule,
              style: theme.textStyle(size: 13, color: theme.danger),
            ),
          AutomationPanelButton(
            label: strings.saveCurrentState,
            kind: AutomationPanelButtonKind.primary,
            onPressed: _save,
          ),
          for (final name in _names)
            _PresetRow(
              name: name,
              onApply: () => _confirmApply(name),
              onDelete: () => _confirmDelete(name),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final names = await _store?.listPresets() ?? const <String>[];

    if (mounted) {
      setState(() => _names = names);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      return;
    }

    try {
      await _store?.savePreset(name, widget.controller.mock.scenario.toJson());
    } on ArgumentError {
      setState(() => _isNameRejected = true);

      return;
    }

    await _reload();
  }

  Future<void> _confirmApply(String name) async {
    final preset = await _store?.readPreset(name) ?? const {};
    final scenario = MockScenario.fromJson(preset);
    final isChanged = widget.controller.isChanged;
    final restarts = widget.controller.needsRestartFor(scenario);

    if (!isChanged && !restarts) {
      return _apply(name, scenario);
    }

    if (!mounted) {
      return;
    }

    final strings = AutomationPanelStrings.of(context);

    return showAutomationConfirmSheet(
      context: context,
      title: strings.applyPresetQuestion(name),
      message: [
        if (isChanged) strings.applyPresetMessage,
        if (restarts) strings.appRestarts,
      ].join(' '),
      confirmLabel: strings.apply,
      onConfirmPressed: () => _apply(name, scenario),
    );
  }

  Future<void> _apply(String name, MockScenario scenario) async {
    await widget.controller.updateScenario(scenario, title: name);

    widget.onClose();
  }

  Future<void> _confirmDelete(String name) {
    final strings = AutomationPanelStrings.of(context);

    return showAutomationConfirmSheet(
      context: context,
      title: strings.deletePresetQuestion(name),
      message: strings.deletePresetMessage,
      confirmLabel: strings.delete,
      onConfirmPressed: () => _delete(name),
    );
  }

  Future<void> _delete(String name) async {
    await _store?.deletePreset(name);
    await _reload();
  }
}

class _PresetRow extends StatelessWidget {
  final String name;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  const _PresetRow({
    required this.name,
    required this.onApply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AutomationPanelStrings.of(context);
    final theme = AutomationPanelTheme.of(context);

    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(AutomationPanelTheme.buttonRadius),
        border: Border.all(color: theme.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onApply,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.centerLeft,
                child: Text(name, style: theme.textStyle(size: 15)),
              ),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: strings.deletePreset,
            icon: Icon(Icons.delete_outline, color: theme.danger),
          ),
        ],
      ),
    );
  }
}
