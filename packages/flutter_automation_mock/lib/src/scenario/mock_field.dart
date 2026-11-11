import 'package:flutter_automation_mock/src/scenario/mock_field_type.dart';

/// {@category Utils}
///
/// One field of a [MockFeature] settings object, described for a form.
///
/// A generic editor builds one input per field from this description, so a
/// tool can change a scenario without code of the project.
final class MockField {
  /// Key of the field in the settings JSON.
  final String name;

  /// Kind of value the field holds.
  final MockFieldType type;

  /// Values the field accepts, for [MockFieldType.option] and the items of
  /// [MockFieldType.optionList].
  final List<String> options;

  /// Creates the description of one settings field.
  ///
  /// The [name] parameter is the key of the field in the settings JSON.
  /// The [type] parameter is the kind of value the field holds.
  /// The [options] parameter lists the accepted values of an option field.
  const MockField({
    required this.name,
    required this.type,
    this.options = const [],
  });
}
