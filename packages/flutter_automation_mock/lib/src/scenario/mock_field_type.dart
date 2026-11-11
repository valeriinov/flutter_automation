/// {@category Utils}
///
/// Kind of value one [MockField] holds.
enum MockFieldType {
  /// `true` or `false`.
  boolean,

  /// A whole number.
  integer,

  /// A fractional number.
  decimal,

  /// Free text.
  text,

  /// One value out of the field options.
  option,

  /// A list of values out of the field options.
  optionList,

  /// A nested JSON object the form shows as raw JSON.
  object,
}
