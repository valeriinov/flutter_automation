/// {@category Utils}
///
/// One entry of a variant's `use` list: a [FlowStep] written inline or a `Use`
/// of a block.
abstract interface class FlowItem {
  /// The entry as the flow JSON holds it: a step object, a block name or a
  /// block reference object.
  Object toJson();
}
