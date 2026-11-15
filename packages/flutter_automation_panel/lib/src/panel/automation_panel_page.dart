import 'package:flutter/widgets.dart';

/// {@category Widgets}
///
/// One tab of the panel: its label and the content it builds.
///
/// The package ships the pages of the flow catalogue, the sections of the mock
/// and the journal. A project adds a page of its own with the same type.
@immutable
final class AutomationPanelPage {
  /// Label of the tab.
  final String label;

  /// Builds the content of the tab.
  final WidgetBuilder builder;

  const AutomationPanelPage({required this.label, required this.builder});
}
