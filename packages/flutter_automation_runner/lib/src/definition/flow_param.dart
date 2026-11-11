import 'package:flutter_automation_runner/src/automation_runner_exception.dart';

/// {@category Utils}
///
/// A block parameter as a step reads it: the placeholder that a variant's
/// `with` map fills in when the run expands the block.
///
/// A whole-string placeholder takes the type of the value. A placeholder inside
/// a longer string, written with string interpolation, takes the text of the
/// value.
final class FlowParam {
  /// Name of the parameter, as the block declares it in its `params`.
  final String name;

  const FlowParam(this.name);

  /// The `{{name}}` text that the flow JSON holds in place of the value.
  String get placeholder => '{{$name}}';

  @override
  String toString() => placeholder;
}

/// {@category Utils}
///
/// The parameters of one [FlowBlock], handed to the function that builds its
/// steps.
final class FlowParams {
  final Set<String> _names;
  final String _blockName;

  /// Creates the parameters of the block [blockName] that declares [names].
  ///
  /// The [blockName] parameter names the block in an error.
  /// The [names] parameter holds the declared parameter names.
  const FlowParams({required String blockName, required Set<String> names})
    : _blockName = blockName,
      _names = names;

  /// The parameter [name].
  ///
  /// Throws an [AutomationRunnerException] when the block declares no such
  /// parameter, so a misspelled name fails when the flow is built.
  FlowParam operator [](String name) {
    if (!_names.contains(name)) {
      throw AutomationRunnerException(
        'Block "$_blockName" reads "$name" and declares only '
        '${_names.toList()}.',
      );
    }

    return FlowParam(name);
  }
}
