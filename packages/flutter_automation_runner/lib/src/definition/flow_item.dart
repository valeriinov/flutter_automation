/// {@category Utils}
///
/// One item of a variant's `items` list: a [FlowStep] written inline or a `Use`
/// of a block.
abstract interface class FlowItem {
  /// The item as the flow JSON holds it: a step object, a block name or a
  /// block reference object.
  Object toJson();
}
