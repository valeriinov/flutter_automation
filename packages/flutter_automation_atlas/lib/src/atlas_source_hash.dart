import 'dart:convert';
import 'dart:io';

import 'package:flutter_automation_atlas/src/atlas_content_hash.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_settings.dart';

/// {@category Utils}
///
/// The hash an app source file is compared by: the content hash of its source
/// with what paints nothing taken out.
///
/// The hash skips each `.automationTarget(...)` call. A target only names an
/// element for an agent. The hash also skips each import directive of a
/// `flutter_automation*` package and of the automation module and the targets
/// folder of the project ([AtlasStaleSettings.automationDirectory] and
/// [AtlasStaleSettings.targetsDirectory]), by `package:` or relative URI.
///
/// The hash skips whitespace and the comma that ends an argument list. The
/// `dart format` command reflows the lines around a call that it adds or
/// removes. String literals keep each character.
final class AtlasSourceHash {
  static const _sourceDirectory = 'lib/';
  static const _folderSeparator = '/';
  static const _packageImport = r"""package:flutter_automation[a-z_]*/[^'"]*""";

  final RegExp _automationDirectivePattern;

  /// The hash that skips the imports of the folders of [settings].
  AtlasSourceHash(AtlasStaleSettings settings)
    : _automationDirectivePattern = _buildDirectivePattern([
        settings.automationDirectory,
        settings.targetsDirectory,
      ]);

  /// Hashes the [text] of declarations, which holds no directive, normalized
  /// as [normalize] does.
  static String hashDeclarations(String text) {
    return AtlasContentHash.hashBytes(
      utf8.encode(_DartSourceNormalizer(text).normalize()),
    );
  }

  /// The [source] with every comment and every string literal character
  /// outside an interpolated name replaced by a space, so an offset into the
  /// result is the same offset into [source].
  static String mask(String source) {
    return _DartSourceNormalizer(source).mask(isLiteralMasked: true);
  }

  /// The [source] with every comment replaced by spaces, so an offset into
  /// the result is the same offset into [source].
  static String maskComments(String source) {
    return _DartSourceNormalizer(source).mask(isLiteralMasked: false);
  }

  /// Hashes the [source] of a Dart file.
  String hashSource(String source) {
    return AtlasContentHash.hashBytes(utf8.encode(normalize(source)));
  }

  /// Hashes the Dart file at [path], `null` when there is no file.
  String? tryHashFile(String path) {
    final file = File(path);

    if (!file.existsSync()) {
      return null;
    }

    return hashSource(file.readAsStringSync());
  }

  /// The [source] without automation target calls and directives, whitespace
  /// outside string literals and commas closing a list.
  String normalize(String source) {
    return _DartSourceNormalizer(
      source.replaceAll(_automationDirectivePattern, ''),
    ).normalize();
  }

  static RegExp _buildDirectivePattern(List<String> directories) {
    final uris = [
      for (final folder in directories.map(_readImportFolder).toSet())
        if (folder.isNotEmpty)
          """(?:[^'"]*/)?${RegExp.escape(folder)}/[^'"]*""",
      _packageImport,
    ];

    return RegExp(
      """^\\s*import\\s+['"](?:${uris.join('|')})['"]\\s*;[^\\n]*\$""",
      multiLine: true,
    );
  }

  // A directory of the project is `lib/<folder>/`; an import names it as
  // `package:<app>/<folder>/` or by a path relative to the importing file.
  static String _readImportFolder(String directory) {
    final folder = directory.startsWith(_sourceDirectory)
        ? directory.substring(_sourceDirectory.length)
        : directory;

    return folder.endsWith(_folderSeparator)
        ? folder.substring(0, folder.length - _folderSeparator.length)
        : folder;
  }
}

final class _DartSourceNormalizer {
  static const _targetCall = '.automationTarget(';
  static const _closingBrackets = {')', ']', '}'};
  static const _quotes = {"'", '"'};
  static const _lineCommentStart = '//';
  static const _blockCommentStart = '/*';
  static const _blockCommentEnd = '*/';
  static const _interpolationStart = r'${';
  static final _whitespacePattern = RegExp(r'\s');
  static final _identifierPattern = RegExp(r'[A-Za-z0-9_$]');
  static final _interpolatedNamePattern = RegExp(
    r'\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*',
  );
  static final _nonIdentifierPattern = RegExp(r'[^A-Za-z0-9_.]');

  final String _source;

  const _DartSourceNormalizer(this._source);

  String normalize() {
    final output = StringBuffer();
    int index = 0;

    while (index < _source.length) {
      index = _appendNext(output, index);
    }

    return output.toString();
  }

  String mask({required bool isLiteralMasked}) {
    final output = StringBuffer();
    int index = 0;

    while (index < _source.length) {
      index = _appendNextMasked(
        output,
        index,
        isLiteralMasked: isLiteralMasked,
      );
    }

    return output.toString();
  }

  int _appendNext(StringBuffer output, int index) {
    if (_source.startsWith(_targetCall, index)) {
      return _skipParentheses(index + _targetCall.length - 1);
    }

    final literalEnd = _tryFindLiteralEnd(index);

    if (literalEnd != null) {
      output.write(_source.substring(index, literalEnd));

      return literalEnd;
    }

    final commentEnd = _tryFindCommentEnd(index);

    if (commentEnd != null) {
      output.write(_stripWhitespace(_source.substring(index, commentEnd)));

      return commentEnd;
    }

    final char = _source[index];

    if (!_isWhitespace(char) && !_isClosingComma(index)) {
      output.write(char);
    }

    return index + 1;
  }

  int _appendNextMasked(
    StringBuffer output,
    int index, {
    required bool isLiteralMasked,
  }) {
    final literalEnd = _tryFindLiteralEnd(index);

    if (literalEnd != null) {
      final literal = _source.substring(index, literalEnd);

      output.write(isLiteralMasked ? _maskLiteral(literal) : literal);

      return literalEnd;
    }

    final commentEnd = _tryFindCommentEnd(index);

    if (commentEnd != null) {
      output.write(' ' * (commentEnd - index));

      return commentEnd;
    }

    output.write(_source[index]);

    return index + 1;
  }

  int _skipParentheses(int openIndex) {
    int depth = 0;
    int index = openIndex;

    while (index < _source.length) {
      final skippedEnd = _tryFindLiteralEnd(index) ?? _tryFindCommentEnd(index);

      if (skippedEnd != null) {
        index = skippedEnd;
        continue;
      }

      depth += _readDepthChange(_source[index]);
      index += 1;

      if (depth == 0) {
        return index;
      }
    }

    return index;
  }

  String _stripWhitespace(String text) {
    return text.replaceAll(_whitespacePattern, '');
  }

  bool _isClosingComma(int index) {
    if (_source[index] != ',') {
      return false;
    }

    int next = index + 1;

    while (next < _source.length && _isWhitespace(_source[next])) {
      next += 1;
    }

    return next < _source.length && _closingBrackets.contains(_source[next]);
  }

  String _maskLiteral(String literal) {
    final masked = StringBuffer();
    int index = 0;

    for (final match in _interpolatedNamePattern.allMatches(literal)) {
      masked
        ..write(' ' * (match.start - index))
        ..write(match[0]?.replaceAll(_nonIdentifierPattern, ' '));

      index = match.end;
    }

    masked.write(' ' * (literal.length - index));

    return masked.toString();
  }

  int _readDepthChange(String char) {
    return switch (char) {
      '(' => 1,
      ')' => -1,
      _ => 0,
    };
  }

  bool _isWhitespace(String char) {
    return _whitespacePattern.hasMatch(char);
  }

  int? _tryFindLiteralEnd(int index) {
    final char = _source[index];

    if (_quotes.contains(char)) {
      return _findStringEnd(index, isRaw: false);
    }

    if (char == 'r' && _isRawStringStart(index)) {
      return _findStringEnd(index + 1, isRaw: true);
    }

    return null;
  }

  bool _isRawStringStart(int index) {
    final next = index + 1 < _source.length ? _source[index + 1] : '';
    final previous = index > 0 ? _source[index - 1] : '';

    return _quotes.contains(next) && !_identifierPattern.hasMatch(previous);
  }

  int _findStringEnd(int quoteIndex, {required bool isRaw}) {
    final quote = _source[quoteIndex];
    final tripleQuote = quote * 3;
    final isTriple = _source.startsWith(tripleQuote, quoteIndex);
    final closing = isTriple ? tripleQuote : quote;
    int index = quoteIndex + closing.length;

    while (index < _source.length) {
      if (_source.startsWith(closing, index)) {
        return index + closing.length;
      }

      index = _skipStringCharacter(index, isRaw: isRaw);
    }

    return index;
  }

  int _skipStringCharacter(int index, {required bool isRaw}) {
    if (isRaw) {
      return index + 1;
    }

    if (_source[index] == r'\') {
      return index + 2;
    }

    if (_source.startsWith(_interpolationStart, index)) {
      return _skipInterpolation(index + _interpolationStart.length);
    }

    return index + 1;
  }

  int _skipInterpolation(int start) {
    int depth = 1;
    int index = start;

    while (index < _source.length && depth > 0) {
      final skippedEnd = _tryFindLiteralEnd(index) ?? _tryFindCommentEnd(index);

      if (skippedEnd != null) {
        index = skippedEnd;
        continue;
      }

      depth += _readBraceDepthChange(_source[index]);
      index += 1;
    }

    return index;
  }

  int? _tryFindCommentEnd(int index) {
    if (_source.startsWith(_lineCommentStart, index)) {
      final lineEnd = _source.indexOf('\n', index);

      return lineEnd < 0 ? _source.length : lineEnd;
    }

    if (_source.startsWith(_blockCommentStart, index)) {
      final commentEnd = _source.indexOf(
        _blockCommentEnd,
        index + _blockCommentStart.length,
      );

      return commentEnd < 0
          ? _source.length
          : commentEnd + _blockCommentEnd.length;
    }

    return null;
  }

  int _readBraceDepthChange(String char) {
    return switch (char) {
      '{' => 1,
      '}' => -1,
      _ => 0,
    };
  }
}
