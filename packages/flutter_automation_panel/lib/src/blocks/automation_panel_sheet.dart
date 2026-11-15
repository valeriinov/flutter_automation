import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The content of a bottom sheet of the panel: a grabber, a title with a
/// cross, and the [child].
///
/// A sheet that needs another head, such as the end of a run, passes [header].
class AutomationPanelSheet extends StatelessWidget {
  /// Title of the sheet, missing when [header] stands in.
  final String? title;

  /// Head that replaces the title and the cross.
  final Widget? header;

  /// Called when the tester taps the cross.
  final VoidCallback? onClose;

  /// Content under the head.
  final Widget child;

  const AutomationPanelSheet({
    required this.child,
    this.title,
    this.header,
    this.onClose,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final title = this.title;
    final header = this.header;
    final systemBottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AutomationPanelTheme.gapLarge,
        AutomationPanelTheme.gapSmall,
        AutomationPanelTheme.gapLarge,
        max(24, systemBottom + AutomationPanelTheme.gapSmall),
      ),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AutomationPanelTheme.sheetRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AutomationPanelTheme.gapMedium,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          ?header,
          if (title != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textStyle(size: 18, weight: FontWeight.w700),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(10, 0),
                  child: IconButton(
                    onPressed: onClose,
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          child,
        ],
      ),
    );
  }
}

/// {@category Widgets}
///
/// Shows [builder] in a bottom sheet of the panel.
///
/// The sheet takes the theme of the panel, not the theme of the app. It needs
/// a [Navigator] above [context], so the panel shows it from its own
/// navigator.
///
/// The [context] parameter is the context of the panel.
/// The [builder] parameter builds the content, usually an
/// [AutomationPanelSheet].
/// Returns the value the sheet pops with.
Future<T?> showAutomationPanelSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final theme = AutomationPanelTheme.of(context);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: theme.scrim,
    elevation: 0,
    builder: (sheetContext) {
      return Theme(
        data: theme.toThemeData(),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(child: builder(sheetContext)),
        ),
      );
    },
  );
}
