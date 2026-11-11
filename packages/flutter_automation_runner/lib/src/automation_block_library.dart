import 'package:flutter_automation_runner/src/automation_localized_text.dart';
import 'package:flutter_automation_runner/src/automation_runner_exception.dart';
import 'package:flutter_automation_runner/src/automation_step_label.dart';

final RegExp _placeholder = RegExp(r'\{\{(\w+)\}\}');

const _titleKey = 'title';

/// {@category Utils}
///
/// Blocks that a flow variant draws on, read from the decoded block objects.
///
/// A journey has many ways through it, and they share almost each step. The
/// library holds each shared stretch once, and a variant lists the stretches it
/// walks. An author edits a step that changes in one place for each variant
/// that walks through it.
final class AutomationBlockLibrary {
  final Map<String, AutomationBlock> _blocks;

  const AutomationBlockLibrary({required Map<String, AutomationBlock> blocks})
    : _blocks = blocks;

  /// Reads the decoded block objects, keyed by block name.
  factory AutomationBlockLibrary.fromJson(Map<String, Object?> blocks) {
    return AutomationBlockLibrary(
      blocks: {
        for (final MapEntry(:key, :value) in blocks.entries)
          key: AutomationBlock.fromJson(key, value),
      },
    );
  }

  /// Expands the `use` list of a variant into raw step objects, each paired
  /// with the block that declared it.
  ///
  /// The [use] parameter holds block names, block references that carry their
  /// arguments, and inline steps, in the order a run walks them.
  List<AutomationExpandedStep> expand(List<Object?> use) =>
      use.expand(_expandEntry).toList(growable: false);

  /// Describes the `use` list of a variant: one entry per item, with the block
  /// that a stretch came from and what the reference passed it.
  ///
  /// Expansion of a variant flattens its blocks into one list of steps. The
  /// driver walks that list, and a reader of the journey has lost the blocks.
  ///
  /// The [use] parameter holds block names, block references that carry their
  /// arguments, and inline steps, in the order a run walks them.
  List<AutomationEntry> describe(List<Object?> use) =>
      use.map(_describeEntry).toList(growable: false);

  Iterable<AutomationExpandedStep> _expandEntry(Object? entry) {
    final (:block, :body) = _readUseEntry(entry);

    if (block == null) {
      return [(step: body, block: null)];
    }

    return _expandBlock(name: block, arguments: _readArguments(body));
  }

  Iterable<AutomationExpandedStep> _expandBlock({
    required String name,
    required Map<String, Object?> arguments,
  }) {
    final block = _resolveBlock(name: name, arguments: arguments);
    final values = {...block.params, ...arguments};

    return block.steps.map(
      (step) => (step: _substitute(step, values, name), block: name),
    );
  }

  AutomationEntry _describeEntry(Object? entry) {
    final (:block, :body) = _readUseEntry(entry);

    if (block == null) {
      final action = _readAction(body);

      return AutomationStepEntry(
        action: action,
        label: AutomationStepLabel.resolve(body, action),
        title: AutomationLocalizedText.tryRead(body, _titleKey, 'A "use" step'),
      );
    }

    final arguments = _readArguments(body);
    final resolved = _resolveBlock(name: block, arguments: arguments);

    return AutomationBlockEntry(
      name: block,
      stepCount: resolved.steps.length,
      arguments: arguments,
      title: resolved.title,
    );
  }

  AutomationBlock _resolveBlock({
    required String name,
    required Map<String, Object?> arguments,
  }) {
    final block = _blocks[name];

    if (block == null) {
      throw AutomationRunnerException(
        'No block "$name". Known blocks: '
        '${_blocks.keys.toList()..sort()}.',
      );
    }

    final unknown = arguments.keys.where(
      (key) => !block.params.containsKey(key),
    );

    if (unknown.isNotEmpty) {
      throw AutomationRunnerException(
        'Block "$name" has no ${unknown.toList()} to set. It reads '
        '${block.params.keys.toList()}.',
      );
    }

    return block;
  }

  /// Reads a `use` entry into the block it names, `null` for an inline step,
  /// and the object form of the entry, empty for a bare block name.
  static _UseEntry _readUseEntry(Object? entry) {
    if (entry is String) {
      return (block: entry, body: const {});
    }

    if (entry is! Map<String, Object?>) {
      throw const AutomationRunnerException(
        'A "use" entry is neither a block name, a block reference nor a step.',
      );
    }

    final block = entry['block'];

    return (block: block is String ? block : null, body: entry);
  }

  static Map<String, Object?> _readArguments(Map<String, Object?> entry) {
    final arguments = entry['with'];

    return arguments is Map<String, Object?> ? arguments : const {};
  }

  static String _readAction(Map<String, Object?> step) {
    final action = step['action'];

    if (action is String) {
      return action;
    }

    throw const AutomationRunnerException(
      'A "use" step has no string "action".',
    );
  }
}

/// {@category Utils}
///
/// One named stretch of a flow, reusable across its variants.
///
/// A block declares the parameters its steps read, so the stretch that names a
/// quantity is one block rather than one block per quantity.
final class AutomationBlock {
  /// Name of the block, which matches its file name.
  final String name;

  /// Parameters the steps read, mapped to the value used when a variant names
  /// none.
  final Map<String, Object?> params;

  /// Raw step objects that still hold their parameter placeholders.
  final List<Object?> steps;

  /// What the stretch is, in words for people, missing when the file names
  /// none.
  final AutomationLocalizedText? title;

  const AutomationBlock({
    required this.name,
    required this.params,
    required this.steps,
    required this.title,
  });

  /// Reads a block out of the decoded contents of its file.
  ///
  /// The [name] parameter is the file name without its extension, and the
  /// [json] parameter is the decoded file.
  factory AutomationBlock.fromJson(String name, Object? json) {
    if (json is! Map<String, Object?>) {
      throw AutomationRunnerException('Block "$name" is not a JSON object.');
    }

    final steps = json['steps'];

    if (steps is! List<Object?>) {
      throw AutomationRunnerException('Block "$name" has no "steps" list.');
    }

    final params = json['params'];

    return AutomationBlock(
      name: name,
      params: params is Map<String, Object?> ? params : const {},
      steps: steps,
      title: AutomationLocalizedText.tryRead(json, _titleKey, 'Block "$name"'),
    );
  }
}

/// {@category Utils}
///
/// One entry of a variant's `use` list, as a reader of the journey sees it:
/// either a whole block or a step written inline.
sealed class AutomationEntry {
  /// What the entry is, in words for people, missing when nothing names it.
  final AutomationLocalizedText? title;

  const AutomationEntry({required this.title});
}

/// {@category Utils}
///
/// A `use` entry that walks a block, with the arguments the reference passed
/// it.
final class AutomationBlockEntry extends AutomationEntry {
  /// Name of the block walked.
  final String name;

  /// How many steps the block expands to.
  final int stepCount;

  /// Arguments the reference's `with` map named, empty for a bare block name.
  final Map<String, Object?> arguments;

  const AutomationBlockEntry({
    required this.name,
    required this.stepCount,
    required this.arguments,
    required super.title,
  });
}

/// {@category Utils}
///
/// A `use` entry written as one step of its own, between the blocks.
final class AutomationStepEntry extends AutomationEntry {
  /// Driver call the step sends.
  final String action;

  /// Short words that show the step when nothing titles it.
  final String label;

  const AutomationStepEntry({
    required this.action,
    required this.label,
    required super.title,
  });
}

/// {@category Utils}
///
/// One raw step object of an expanded `use` list and the block that declared
/// it, `null` for a step written inline in the variant.
typedef AutomationExpandedStep = ({Object? step, String? block});

/// One entry of a `use` list, read into the block it names, `null` for an
/// inline step, and the object form of the entry.
typedef _UseEntry = ({String? block, Map<String, Object?> body});

Object? _substitute(
  Object? node,
  Map<String, Object?> values,
  String blockName,
) {
  if (node is String) {
    return _substituteString(node, values, blockName);
  }

  if (node is Map<String, Object?>) {
    return node.map(
      (key, value) => MapEntry(key, _substitute(value, values, blockName)),
    );
  }

  if (node is List<Object?>) {
    return node.map((item) => _substitute(item, values, blockName)).toList();
  }

  return node;
}

/// Replaces the placeholders of [source] with the values that a variant named.
///
/// A string that is nothing but one placeholder takes the type of the value. A
/// block therefore reads a timeout as a number, not as its digits.
Object? _substituteString(
  String source,
  Map<String, Object?> values,
  String blockName,
) {
  final whole = _placeholder.matchAsPrefix(source);

  if (whole != null && whole.end == source.length) {
    return values[whole.group(1)];
  }

  final resolved = source.replaceAllMapped(
    _placeholder,
    (match) => '${values[match.group(1)]}',
  );

  _failOnLeftoverPlaceholder(resolved, blockName);

  return resolved;
}

void _failOnLeftoverPlaceholder(String resolved, String blockName) {
  final leftover = _placeholder.firstMatch(resolved);

  if (leftover == null) {
    return;
  }

  throw AutomationRunnerException(
    'Block "$blockName" leaves ${leftover.group(0)} unresolved.',
  );
}
