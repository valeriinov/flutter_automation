/// {@category Utils}
///
/// Name that an app gives one of its own spans or marks in a traced frame.
///
/// The enum that an app keeps its span names in implements it. A call site then
/// names a span by its member, and the timeline reads [label] back.
abstract interface class AutomationTimelineLabel {
  /// The name of the span or the mark in the timeline.
  String get label;
}
