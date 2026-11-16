import 'package:flutter/material.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';

/// {@category Widgets}
///
/// The search field at the top of a tab of the panel. The tab keeps the query
/// and filters its list with [matchesSearchQuery].
class AutomationPanelSearchField extends StatelessWidget {
  /// Text the empty field shows, such as what the search looks through.
  final String hint;

  /// Called with the text of the field after each change.
  final ValueChanged<String> onChanged;

  const AutomationPanelSearchField({
    required this.hint,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return SizedBox(
      height: AutomationPanelTheme.buttonHeight,
      child: TextField(
        onChanged: onChanged,
        style: theme.textStyle(size: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: theme.textStyle(size: 15, color: theme.textSecondary),
          prefixIcon: Icon(Icons.search, size: 20, color: theme.textSecondary),
        ),
      ),
    );
  }
}

/// {@category Utils}
///
/// Whether one of [words] holds [query], with no regard to case. An empty
/// query matches everything.
///
/// The [query] parameter is the text of an [AutomationPanelSearchField].
/// The [words] parameter is the texts of one item of the list.
bool matchesSearchQuery(String query, Iterable<String> words) {
  final wanted = query.trim().toLowerCase();

  if (wanted.isEmpty) {
    return true;
  }

  return words.any((word) => word.toLowerCase().contains(wanted));
}
