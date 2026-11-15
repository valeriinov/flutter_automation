/// {@category Utils}
///
/// One choice of a segmented control, a chip row or a radio list.
final class AutomationPanelOption<T> {
  /// Value the choice stands for.
  final T value;

  /// Text of the choice.
  final String label;

  /// Hint under the label, missing when the choice needs none.
  final String? description;

  const AutomationPanelOption({
    required this.value,
    required this.label,
    this.description,
  });
}
