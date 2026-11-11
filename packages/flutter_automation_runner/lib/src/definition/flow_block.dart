import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/definition/flow_item.dart';
import 'package:flutter_automation_runner/src/definition/flow_json_value.dart';
import 'package:flutter_automation_runner/src/definition/flow_param.dart';
import 'package:flutter_automation_runner/src/definition/flow_step.dart';

/// {@category Utils}
///
/// Builds the steps of a block out of its parameters.
typedef FlowBlockBuilder = List<FlowStep> Function(FlowParams params);

/// {@category Utils}
///
/// One named stretch of a flow, reusable across its variants.
///
/// A block is a function of its parameters. The runner builds the function once
/// with placeholders, and each `Use` fills them in when it expands the block.
final class FlowBlock {
  /// Name of the block, the one a `Use` and a report name.
  final String name;

  /// What the stretch is, in words for people, missing when it has none.
  final AutomationLocalizedText? title;

  /// Parameters the steps read, mapped to the value used when a `Use` names
  /// none.
  final Map<String, Object?> params;

  /// The function that builds the steps.
  final FlowBlockBuilder build;

  const FlowBlock({
    required this.name,
    required this.build,
    this.title,
    this.params = const {},
  });

  /// The block as the flow JSON holds it, with its placeholders in place.
  Map<String, Object?> toJson() {
    final steps = build(
      FlowParams(blockName: name, names: params.keys.toSet()),
    );

    return {
      'title': ?title?.toJson(),
      if (params.isNotEmpty) 'params': writeFlowJsonValue(params),
      'steps': steps.map((step) => step.toJson()).toList(),
    };
  }
}

/// {@category Utils}
///
/// A `use` entry that walks a [block] with the given [arguments].
final class Use implements FlowItem {
  /// Block the entry walks.
  final FlowBlock block;

  /// Values for parameters of the block, empty for the defaults.
  final Map<String, Object?> arguments;

  const Use(this.block, {this.arguments = const {}});

  @override
  Object toJson() {
    if (arguments.isEmpty) {
      return block.name;
    }

    return {'block': block.name, 'with': writeFlowJsonValue(arguments)};
  }
}
