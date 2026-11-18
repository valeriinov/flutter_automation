import 'package:collection/collection.dart';

import 'package:flutter_automation_atlas/src/atlas_source_hash.dart';

/// {@category Utils}
///
/// The declarations of one Dart file, read from its text without the analyzer.
///
/// A file splits into top-level declarations at a `;` or a body's closing
/// brace outside any bracket; a declaration's text is everything after the
/// previous one, its annotations included. A class, a mixin or an extension
/// type splits the same way into its members: one
/// [AtlasDeclarationKind.member] declaration per constructor, field,
/// method, getter and setter, keyed `<class>.<member>` with `new` for the
/// unnamed constructor, while the class declaration keeps its header,
/// superclass, mixins and annotations, and every member it cannot name, such
/// as an operator. A theme class instead gives one
/// [AtlasDeclarationKind.themeField] declaration per field: each piece
/// of the class naming a single field of the file belongs to that field, the
/// rest stays the class's own text. An enum and an extension stay whole.
///
/// A declaration hash leaves comments out, so a comment-only edit changes no
/// declaration.
final class AtlasDeclarations {
  /// The declarations in file order.
  final List<AtlasDeclaration> declarations;

  /// Creates the declarations of one file.
  const AtlasDeclarations({required this.declarations});

  /// Reads the declarations of the Dart [source].
  ///
  /// The [themeClassPattern] parameter matches the name of a theme class and
  /// the [themeValueClassPattern] parameter the name of a theme class whose
  /// members with parameters are fields too; both are absent when the project
  /// has no such class.
  static AtlasDeclarations read(
    String source, {
    String? themeClassPattern,
    String? themeValueClassPattern,
  }) {
    return _DeclarationsReader(
      source,
      themeClassPattern: themeClassPattern,
      themeValueClassPattern: themeValueClassPattern,
    ).read();
  }
}

/// {@category Utils}
///
/// What a [AtlasDeclaration] declares.
enum AtlasDeclarationKind {
  /// A class, a mixin or an extension type.
  classType,

  enumType,

  extension,

  typeAlias,

  /// A function, a getter or a setter.
  function,

  variable,

  /// A field of a theme class together with its mirrors in that class: the
  /// constructor parameter, the factory argument and the tailor mixin lines.
  themeField,

  /// A constructor, a field, a method, a getter or a setter of a class, a
  /// mixin or an extension type.
  member,
}

/// {@category Utils}
///
/// One declaration of a Dart file: a top-level declaration, a member of a
/// class, or a field of a theme class.
final class AtlasDeclaration {
  /// The declared name; a setter's name ends with `=`.
  final String name;

  final AtlasDeclarationKind kind;

  /// The hash of the declaration text without comments, normalized as
  /// [AtlasSourceHash.normalize] does.
  final String hash;

  /// The class declaring a [AtlasDeclarationKind.member] or a
  /// [AtlasDeclarationKind.themeField].
  final String? ownerName;

  /// Creates the declaration of [name].
  const AtlasDeclaration({
    required this.name,
    required this.kind,
    required this.hash,
    this.ownerName,
  });

  /// The name unique within a file: `<owner>.<name>` for a member or a theme
  /// field.
  String get key {
    final resolvedOwnerName = ownerName;

    return resolvedOwnerName == null ? name : '$resolvedOwnerName.$name';
  }
}

final class _Range {
  final int start;
  final int end;
  final int headerEnd;
  final bool isArrow;
  final int? bodyOpen;

  const _Range({
    required this.start,
    required this.end,
    required this.headerEnd,
    required this.bodyOpen,
    required this.isArrow,
  });
}

final class _ClassPieces {
  final remainder = <(int, int)>[];
  final members = <String, List<(int, int)>>{};

  void addRemainder(int start, int end) {
    remainder.add((start, end));
  }

  void addMember(String name, int start, int end) {
    members.putIfAbsent(name, () => []).add((start, end));
  }
}

final class _DeclarationsReader {
  static const _openings = {'(', '[', '{'};
  static const _closings = {')', ']', '}'};
  static const _directiveWords = {'import', 'export', 'part', 'library'};
  static const _equalsNeighbours = {'=', '!', '<', '>'};
  static const _separators = [',', ';', '&&', '||'];
  static const _commaSeparators = [','];
  static const _objectMemberNames = {'hashCode', 'runtimeType', 'toString'};
  static const _unnamedConstructorKey = 'new';
  static const _fieldTypeWords = {
    'Function',
    'final',
    'const',
    'static',
    'late',
    'var',
    'covariant',
  };
  static final _identifierPattern = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');
  static final _typedefPattern = RegExp(r'\btypedef\s+([A-Za-z_$][\w$]*)');
  static final _extensionTypePattern = RegExp(
    r'\bextension\s+type\s+(?:const\s+)?([A-Za-z_$][\w$]*)',
  );
  static final _extensionPattern = RegExp(
    r'\bextension\s+([A-Za-z_$][\w$]*)?[^]*?\bon\b([^]*)$',
  );
  static final _enumPattern = RegExp(r'\benum\s+([A-Za-z_$][\w$]*)');
  static final _classPattern = RegExp(r'\bclass\s+([A-Za-z_$][\w$]*)');
  static final _mixinPattern = RegExp(r'\bmixin\s+([A-Za-z_$][\w$]*)');
  static final _getterPattern = RegExp(r'\bget\s+([A-Za-z_$][\w$]*)\s*$');
  static final _setterPattern = RegExp(r'\bset\s+([A-Za-z_$][\w$]*)\s*\(\)');
  static final _functionPattern = RegExp(r'([A-Za-z_$][\w$]*)\s*\(\)[^()]*$');
  static final _variablePattern = RegExp(r'([A-Za-z_$][\w$]*)\s*$');
  static final _namedArgumentPattern = RegExp(
    r'^\s*([A-Za-z_$][\w$]*)\s*:(?!:)',
  );
  static final _whitespacePattern = RegExp(r'\s+');
  static final _annotationNamePattern = RegExp(r'[\w$.]+');
  static final _nonWhitespacePattern = RegExp(r'\S');
  static final _initializerListPattern = RegExp(r'\)\s*:');
  static final _nextVariablePattern = RegExp(
    r'^\s*([A-Za-z_$][\w$]*)\s*(?:=(?!=)|$)',
  );

  final String _uncommented;
  final String _masked;

  final RegExp? _themeClassPattern;
  final RegExp? _themeValueClassPattern;

  _DeclarationsReader(
    String source, {
    required String? themeClassPattern,
    required String? themeValueClassPattern,
  }) : _uncommented = AtlasSourceHash.maskComments(source),
       _masked = AtlasSourceHash.mask(source),
       _themeClassPattern = themeClassPattern == null
           ? null
           : RegExp(themeClassPattern),
       _themeValueClassPattern = themeValueClassPattern == null
           ? null
           : RegExp(themeValueClassPattern);

  AtlasDeclarations read() {
    final ranges = _splitDeclarations(
      0,
      _masked.length,
    ).where((range) => !_isDirective(range)).toList();
    final themeFieldNames = _readThemeFieldNames(ranges);

    return AtlasDeclarations(
      declarations: [
        for (final range in ranges)
          ..._readDeclarations(range, themeFieldNames),
      ],
    );
  }

  bool _isDirective(_Range range) {
    final words = _readHeader(range).trim().split(_whitespacePattern);

    return _directiveWords.contains(words.firstOrNull);
  }

  Set<String> _readThemeFieldNames(List<_Range> ranges) {
    return {
      for (final range in ranges)
        if (_isThemeClass(range)) ..._readFieldNames(range),
    };
  }

  List<AtlasDeclaration> _readDeclarations(
    _Range range,
    Set<String> themeFieldNames,
  ) {
    final header = _readHeader(range);
    final className = _tryReadClassName(header);

    if (className != null && _isThemeClass(range)) {
      return _readThemeClass(range, className, themeFieldNames);
    }

    if (className != null) {
      return _readClass(range, className);
    }

    return [_readOtherDeclaration(range, header)];
  }

  Iterable<String> _readFieldNames(_Range range) {
    final className = _tryReadClassName(_readHeader(range)) ?? '';
    final isPrivateStyles =
        _themeValueClassPattern?.hasMatch(className) ?? false;

    return _splitBody(range)
        .where((member) => isPrivateStyles || !_hasParameters(member))
        .map(_tryReadMemberName)
        .nonNulls
        .where((name) => name != className)
        .where((name) => !_objectMemberNames.contains(name));
  }

  bool _isThemeClass(_Range range) {
    final name = _tryReadClassName(_readHeader(range));

    return name != null &&
        range.bodyOpen != null &&
        (_themeClassPattern?.hasMatch(name) ?? false);
  }

  List<AtlasDeclaration> _readThemeClass(
    _Range range,
    String className,
    Set<String> themeFieldNames,
  ) {
    final pieces = _createClassPieces(range);

    for (final member in _splitBody(range)) {
      _attributeMember(member, themeFieldNames, pieces);
    }

    return _createClassDeclarations(
      className,
      pieces,
      AtlasDeclarationKind.themeField,
    );
  }

  List<AtlasDeclaration> _readClass(_Range range, String className) {
    final isEnum = _isEnum(_readHeader(range));

    if (isEnum || range.bodyOpen == null) {
      return [
        AtlasDeclaration(
          name: className,
          kind: isEnum
              ? AtlasDeclarationKind.enumType
              : AtlasDeclarationKind.classType,
          hash: _hashRange(range.start, range.end),
        ),
      ];
    }

    final pieces = _createClassPieces(range);

    for (final member in _splitBody(range)) {
      _addMemberPieces(member, className, pieces);
    }

    return _createClassDeclarations(
      className,
      pieces,
      AtlasDeclarationKind.member,
    );
  }

  AtlasDeclaration _readOtherDeclaration(_Range range, String header) {
    final extensionMatch = _tryReadExtension(header);

    if (extensionMatch != null) {
      return AtlasDeclaration(
        name: _readExtensionName(extensionMatch),
        kind: AtlasDeclarationKind.extension,
        hash: _hashRange(range.start, range.end),
      );
    }

    final typedefMatch = _typedefPattern.firstMatch(header);
    final (name, kind) = typedefMatch != null
        ? (
            _readTypedefName(range, typedefMatch),
            AtlasDeclarationKind.typeAlias,
          )
        : _readFunctionOrVariable(range);

    return AtlasDeclaration(
      name: name,
      kind: kind,
      hash: _hashRange(range.start, range.end),
    );
  }

  bool _hasParameters(_Range member) {
    return _stripBracketedAndTypeArguments(_readHeader(member)).contains('(');
  }

  String? _tryReadClassName(String header) {
    if (_tryReadExtension(header) != null) {
      return null;
    }

    return _tryMatchClassName(header)?[1];
  }

  void _attributeMember(
    _Range member,
    Set<String> themeFieldNames,
    _ClassPieces pieces,
  ) {
    final memberName = _tryReadMemberName(member);

    if (memberName != null && themeFieldNames.contains(memberName)) {
      pieces.addMember(memberName, member.start, member.end);

      return;
    }

    _attribute(member.start, member.end, themeFieldNames, pieces);
  }

  bool _isEnum(String header) {
    return _classPattern.firstMatch(header) == null &&
        _enumPattern.firstMatch(header) != null;
  }

  _ClassPieces _createClassPieces(_Range range) {
    final bodyOpen = range.bodyOpen ?? range.end;

    return _ClassPieces()
      ..addRemainder(range.start, bodyOpen + 1)
      ..addRemainder(range.end - 1, range.end);
  }

  List<_Range> _splitBody(_Range range) {
    final bodyOpen = range.bodyOpen;

    if (bodyOpen == null) {
      return [];
    }

    return _splitDeclarations(bodyOpen + 1, range.end - 1);
  }

  void _addMemberPieces(_Range member, String className, _ClassPieces pieces) {
    final keys = _readMemberKeys(member, className);

    if (keys.isEmpty) {
      pieces.addRemainder(member.start, member.end);

      return;
    }

    for (final key in keys) {
      pieces.addMember(key, member.start, member.end);
    }
  }

  List<AtlasDeclaration> _createClassDeclarations(
    String className,
    _ClassPieces pieces,
    AtlasDeclarationKind memberKind,
  ) {
    return [
      AtlasDeclaration(
        name: className,
        kind: AtlasDeclarationKind.classType,
        hash: _hashPieces(pieces.remainder),
      ),
      for (final MapEntry(key: memberName, value: memberPieces)
          in pieces.members.entries)
        AtlasDeclaration(
          name: memberName,
          kind: memberKind,
          hash: _hashPieces(memberPieces),
          ownerName: className,
        ),
    ];
  }

  String _readExtensionName(RegExpMatch match) {
    final name = match[1];

    if (name != null && name != 'on') {
      return name;
    }

    final onType = (match[2] ?? '').trim().replaceAll(_whitespacePattern, ' ');

    return 'extension on $onType';
  }

  String _readTypedefName(_Range range, RegExpMatch typedefMatch) {
    if (range.headerEnd < range.end && !range.isArrow) {
      return typedefMatch[1] ?? '';
    }

    return _readFunctionOrVariable(range).$1;
  }

  String _hashRange(int start, int end) {
    return AtlasSourceHash.hashSource(_uncommented.substring(start, end));
  }

  RegExpMatch? _tryReadExtension(String header) {
    if (_extensionTypePattern.hasMatch(header)) {
      return null;
    }

    return _extensionPattern.firstMatch(header);
  }

  RegExpMatch? _tryMatchClassName(String header) {
    return _extensionTypePattern.firstMatch(header) ??
        _classPattern.firstMatch(header) ??
        _mixinPattern.firstMatch(header) ??
        _enumPattern.firstMatch(header);
  }

  String? _tryReadMemberName(_Range member) {
    final flat = _stripBracketedAndTypeArguments(
      _readHeader(member),
    ).trimRight();
    final getterName = _getterPattern.firstMatch(flat)?[1];

    if (getterName != null) {
      return getterName;
    }

    if (flat.contains('(')) {
      return _functionPattern.firstMatch(flat)?[1];
    }

    return _variablePattern.firstMatch(flat)?[1];
  }

  List<_Range> _splitDeclarations(int start, int end) {
    final ranges = <_Range>[];
    int rangeStart = start;
    int? expressionStart;
    int depth = 0;
    int index = start;

    while (index < end) {
      final char = _masked[index];

      if (depth == 0 && _isInitializerEquals(index)) {
        expressionStart ??= index;
      }

      if (depth == 0 && char == ';') {
        ranges.add(
          _createRange(rangeStart, index + 1, expressionStart ?? index, null),
        );

        rangeStart = index + 1;
        expressionStart = null;
        index += 1;
        continue;
      }

      if (depth == 0 &&
          char == '{' &&
          _isBodyOpen(rangeStart, expressionStart)) {
        final close = _findClose(index);

        ranges.add(_createRange(rangeStart, close, null, index));

        rangeStart = close;
        expressionStart = null;
        index = close;
        continue;
      }

      depth += _readDepthChange(char);
      index += 1;
    }

    ranges.add(_createRange(rangeStart, end, expressionStart, null));

    return ranges.where((range) => !_isBlank(range.start, range.end)).toList();
  }

  List<String> _readMemberKeys(_Range member, String className) {
    final signature = _readMemberSignature(member);
    final getterName = _getterPattern.firstMatch(signature)?[1];

    if (getterName != null) {
      return [getterName];
    }

    final setterName = _setterPattern.firstMatch(signature)?[1];

    if (setterName != null) {
      return ['$setterName='];
    }

    if (!signature.contains('(')) {
      return _readFieldKeys(member, signature);
    }

    final functionName = _functionPattern.firstMatch(signature)?[1];

    return switch (functionName) {
      null => const [],
      _ when _fieldTypeWords.contains(functionName) => _readFieldKeys(
        member,
        signature,
      ),
      _ when functionName == className => const [_unnamedConstructorKey],
      _ => [functionName],
    };
  }

  String _hashPieces(List<(int, int)> pieces) {
    return AtlasSourceHash.hashSource(
      pieces
          .map((piece) => _uncommented.substring(piece.$1, piece.$2))
          .join('\n'),
    );
  }

  (String, AtlasDeclarationKind) _readFunctionOrVariable(_Range range) {
    final flat = _stripBracketedAndTypeArguments(
      _readHeader(range),
    ).trimRight();
    final getterName = _getterPattern.firstMatch(flat)?[1];

    if (getterName != null) {
      return (getterName, AtlasDeclarationKind.function);
    }

    final setterName = _setterPattern.firstMatch(flat)?[1];

    if (setterName != null) {
      return ('$setterName=', AtlasDeclarationKind.function);
    }

    if (flat.contains('(')) {
      return (
        _functionPattern.firstMatch(flat)?[1] ?? flat,
        AtlasDeclarationKind.function,
      );
    }

    return (
      _variablePattern.firstMatch(flat)?[1] ?? flat,
      AtlasDeclarationKind.variable,
    );
  }

  bool _isInitializerEquals(int index) {
    if (_masked[index] != '=') {
      return false;
    }

    final previous = index > 0 ? _masked[index - 1] : '';
    final next = index + 1 < _masked.length ? _masked[index + 1] : '';

    return !_equalsNeighbours.contains(previous) && next != '=';
  }

  bool _isBodyOpen(int rangeStart, int? expressionStart) {
    if (expressionStart == null) {
      return true;
    }

    final header = _stripBracketedAndTypeArguments(
      _masked.substring(rangeStart, expressionStart),
    );

    return _initializerListPattern.hasMatch(header);
  }

  _Range _createRange(int start, int end, int? expressionStart, int? bodyOpen) {
    final headerEnd = bodyOpen ?? expressionStart ?? end;

    return _Range(
      start: start,
      end: end,
      headerEnd: headerEnd,
      bodyOpen: bodyOpen,
      isArrow: _masked.startsWith('=>', headerEnd),
    );
  }

  bool _isBlank(int start, int end) {
    return _masked.substring(start, end).trim().isEmpty;
  }

  String _readMemberSignature(_Range member) {
    final signature = _stripBracketedAndTypeArguments(
      _readHeader(member),
    ).trimRight();
    final initializerList = _initializerListPattern.firstMatch(signature);

    return initializerList == null
        ? signature
        : signature.substring(0, initializerList.start + 1);
  }

  List<String> _readFieldKeys(_Range member, String signature) {
    final initializerEnd = _masked.lastIndexOf(';', member.end);
    final nextVariables = member.headerEnd < initializerEnd
        ? _splitElements(member.headerEnd, initializerEnd, _commaSeparators)
              .skip(1)
              .map(
                (element) => _nextVariablePattern.firstMatch(
                  _masked.substring(element.$1, element.$2),
                )?[1],
              )
        : const <String?>[];

    return [
      ...signature
          .split(',')
          .map((part) => _variablePattern.firstMatch(part)?[1]),
      ...nextVariables,
    ].nonNulls.toList();
  }

  String _stripBracketedAndTypeArguments(String text) {
    final output = StringBuffer();
    int depth = 0;
    int angleDepth = 0;

    for (final char in text.split('')) {
      final change = _readDepthChange(char);
      final angleChange = depth == 0 ? _readAngleChange(char, angleDepth) : 0;
      final isTypeArgument = angleDepth > 0 || angleChange != 0;

      if (!isTypeArgument && _isOutsideBrackets(depth, change)) {
        output.write(char);
      }

      depth += change;
      angleDepth += angleChange;
    }

    return output.toString();
  }

  String _readHeader(_Range range) {
    final header = _masked.substring(range.start, range.headerEnd);
    final output = StringBuffer();
    int index = 0;

    while (index < header.length) {
      final annotationEnd = _tryFindAnnotationEnd(header, index);

      if (annotationEnd == null) {
        output.write(header[index]);

        index += 1;
        continue;
      }

      output.write(' ' * (annotationEnd - index));

      index = annotationEnd;
    }

    return output.toString();
  }

  int _readAngleChange(String char, int angleDepth) {
    if (char == '<') {
      return 1;
    }

    return char == '>' && angleDepth > 0 ? -1 : 0;
  }

  bool _isOutsideBrackets(int depth, int change) {
    return depth == 0 || (depth == 1 && change < 0);
  }

  int? _tryFindAnnotationEnd(String header, int index) {
    if (header[index] != '@') {
      return null;
    }

    final nameMatch = _annotationNamePattern.matchAsPrefix(header, index + 1);
    final nameEnd = nameMatch?.end ?? index + 1;
    final argumentsStart = header.indexOf(_nonWhitespacePattern, nameEnd);

    if (argumentsStart < 0 || header[argumentsStart] != '(') {
      return nameEnd;
    }

    return _findCloseIn(header, argumentsStart);
  }

  int _findCloseIn(String text, int openIndex) {
    int depth = 0;
    int index = openIndex;

    while (index < text.length) {
      depth += _readDepthChange(text[index]);
      index += 1;

      if (depth == 0) {
        return index;
      }
    }

    return index;
  }

  void _attribute(
    int start,
    int end,
    Set<String> themeFieldNames,
    _ClassPieces pieces,
  ) {
    final label = _namedArgumentPattern.firstMatch(
      _masked.substring(start, end),
    )?[1];

    if (label != null && themeFieldNames.contains(label)) {
      pieces.addMember(label, start, end);

      return;
    }

    final names = _readNames(start, end).intersection(themeFieldNames);

    if (names.length <= 1) {
      _addPiece(pieces, names.firstOrNull, start, end);

      return;
    }

    _attributeNested(start, end, themeFieldNames, pieces);
  }

  Set<String> _readNames(int start, int end) {
    return _identifierPattern
        .allMatches(_masked.substring(start, end))
        .map((match) => match[0])
        .nonNulls
        .toSet();
  }

  void _addPiece(_ClassPieces pieces, String? fieldName, int start, int end) {
    if (fieldName == null) {
      pieces.addRemainder(start, end);

      return;
    }

    pieces.addMember(fieldName, start, end);
  }

  void _attributeNested(
    int start,
    int end,
    Set<String> themeFieldNames,
    _ClassPieces pieces,
  ) {
    int segmentStart = start;
    int index = start;

    while (index < end) {
      if (!_openings.contains(_masked[index])) {
        index += 1;
        continue;
      }

      final close = _findClose(index);

      pieces.addRemainder(segmentStart, index + 1);

      for (final (elementStart, elementEnd) in _splitElements(
        index + 1,
        close - 1,
        _separators,
      )) {
        _attribute(elementStart, elementEnd, themeFieldNames, pieces);
      }

      segmentStart = close - 1;
      index = close;
    }

    pieces.addRemainder(segmentStart, end);
  }

  int _findClose(int openIndex) {
    int depth = 0;
    int index = openIndex;

    while (index < _masked.length) {
      depth += _readDepthChange(_masked[index]);
      index += 1;

      if (depth == 0) {
        return index;
      }
    }

    return index;
  }

  List<(int, int)> _splitElements(int start, int end, List<String> separators) {
    final elements = <(int, int)>[];
    int elementStart = start;
    int depth = 0;
    int index = start;

    while (index < end) {
      final separatorLength = depth == 0
          ? _readSeparatorLength(index, separators)
          : 0;

      if (separatorLength > 0) {
        elements.add((elementStart, index));

        index += separatorLength;
        elementStart = index;
        continue;
      }

      depth += _readDepthChange(_masked[index]);
      index += 1;
    }

    elements.add((elementStart, end));

    return elements;
  }

  int _readSeparatorLength(int index, List<String> separators) {
    final separator = separators.firstWhereOrNull(
      (separator) => _masked.startsWith(separator, index),
    );

    return separator?.length ?? 0;
  }

  int _readDepthChange(String char) {
    if (_openings.contains(char)) {
      return 1;
    }

    return _closings.contains(char) ? -1 : 0;
  }
}
