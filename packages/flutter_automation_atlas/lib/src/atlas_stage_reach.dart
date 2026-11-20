import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_declarations.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_stale_settings.dart';

/// {@category Utils}
///
/// The map from a widget class to the declarations of the app source it
/// reaches, built from the resolved `lib/` code.
///
/// An edge follows a resolved reference: a constructor call reaches the
/// constructor and the construction of its class, that is the class header, its
/// instance fields, its `@override` members and the construction of its `lib/`
/// superclass and mixins; a member access reaches the member and its class
/// header; a type use reaches the class header only. The construction of a
/// theme class ([AtlasStaleSettings.themeClassPattern]) reaches its header and
/// the construction of its `lib/` mixins only, and its constructors reach no
/// field: a theme field is reached only through an access to it, together with
/// the arguments a theme constructor takes for it, which belong to that field
/// rather than to the factory method passing them. An interface reaches the
/// class an annotation of [AtlasStaleSettings.registrationAnnotations]
/// registers as it and that class's constructors, and each interface member the
/// implementing member, through a DI edge; the implementation's overrides of
/// interface members are left out of its construction. A class a
/// self-registration annotation registers reaches its constructors through a DI
/// edge. The type a method of a module class registers — its `as:` type, or
/// else its return type, the value type of a `Future` — reaches the method
/// through a DI edge, from every declaration naming that type when it is
/// declared outside `lib/`. A widget owns its `State` classes, and a widget the
/// top-level `main` function constructs is owned by `main` too; the walk from a
/// widget enters no other widget class nor its `State`, since a widget visible
/// on the stage is a root of its own, but enters the widget's own superclasses.
/// A root reaches every member of its own classes and every function owning it.
/// The generated registration files
/// ([AtlasStaleSettings.excludedSuffix]) are left out: they mention every
/// registered class, and the annotations give its edges.
///
/// Reached ids are [AtlasDeclarations] ids: a member those declarations
/// do not keep apart, such as an operator or an enum constant, is its class.
final class AtlasStageReach {
  static const _pathSeparator = '::';
  static const _memberSeparator = '.';
  static const _constructionSuffix = '.<new>';
  static const _dartExtension = '.dart';
  static const _packageConfigPath = '.dart_tool/package_config.json';
  static const _flutterPackageName = 'flutter';
  static const _dartSdkPath = 'bin/cache/dart-sdk';

  final _ReachGraph _graph;

  const AtlasStageReach._(this._graph);

  /// Resolves every Dart file under `lib/` of [paths] and builds the map.
  ///
  /// Reads the package configuration from the nearest `.dart_tool` folder at
  /// or above the project root, since a workspace member keeps it at the
  /// workspace root.
  ///
  /// Fails with [AtlasException] when no package configuration exists, a file
  /// does not resolve or the package configuration names no Flutter SDK.
  static Future<AtlasStageReach> read(AtlasLocations paths) async {
    final rootPath = p.normalize(p.absolute(paths.rootPath));
    final sourcePath = p.normalize(
      p.join(rootPath, AutomationCoverageManifest.appSourceDirectory),
    );
    final collection = AnalysisContextCollection(
      includedPaths: [sourcePath],
      sdkPath: _readSdkPath(rootPath),
    );

    try {
      final session = collection.contextFor(sourcePath).currentSession;
      final builder = _ReachBuilder(paths);

      for (final file in _listSources(
        sourcePath,
        paths.project.staleSettings.excludedSuffix,
      )) {
        builder.addUnit(
          p.relative(file.path, from: rootPath),
          await _resolve(session, file),
        );
      }

      return AtlasStageReach._(builder.build());
    } finally {
      await collection.dispose();
    }
  }

  /// The id of the declaration with [key] in the file at [path].
  static String idOf(String path, String key) {
    return '$path$_pathSeparator$key';
  }

  /// The declarations every widget class named [widgetName] reaches, its own
  /// included; empty when no widget class has that name.
  AtlasReachedDeclarations reachFrom(String widgetName) {
    final directIds = <String>{};
    final allIds = <String>{};

    for (final rootId in _readRootIds(widgetName)) {
      final allowedIds = _readRootWithStatesAndSuperclasses(rootId);
      final rootDirectIds = _walk(
        allowedIds.expand(_readStartIds),
        allowedIds,
        isDiFollowed: false,
      );

      directIds.addAll(rootDirectIds);
      allIds.addAll(_walk(rootDirectIds, allowedIds, isDiFollowed: true));
    }

    final ids = _project(directIds);

    return AtlasReachedDeclarations(
      ids: ids,
      diIds: _project(allIds).difference(ids),
    );
  }

  /// Whether [name] — of a top-level declaration or of an extension member —
  /// is declared in more than one project file, or in a project file and a
  /// library some project file imports.
  bool isNameDeclaredMoreThanOnce(String name) {
    final paths = _graph.pathsByName[name] ?? const <String>{};

    return paths.length > 1 || _isAlsoImported(name, paths);
  }

  static String _readSdkPath(String rootPath) {
    final configFile = _findPackageConfig(rootPath);
    final config = AtlasJson.decodeObject(
      configFile.readAsStringSync(),
      _packageConfigPath,
    );
    final flutterRootUri = _tryReadFlutterPackage(
      config['packages'],
    )?['rootUri'];

    if (flutterRootUri is! String) {
      throw const AtlasException(
        '$_packageConfigPath names no flutter package.',
      );
    }

    final flutterPackagePath = configFile.uri
        .resolve(flutterRootUri)
        .toFilePath();

    return p.normalize(p.join(flutterPackagePath, '..', '..', _dartSdkPath));
  }

  static File _findPackageConfig(String rootPath, [String? directory]) {
    final current = directory ?? rootPath;
    final file = File(p.join(current, _packageConfigPath));

    if (file.existsSync()) {
      return file;
    }

    final parent = p.dirname(current);

    if (parent == current) {
      throw AtlasException(
        'No $_packageConfigPath in $rootPath or a folder above it; run '
        '`pub get`.',
      );
    }

    return _findPackageConfig(rootPath, parent);
  }

  static Iterable<File> _listSources(
    String sourcePath,
    String? excludedSuffix,
  ) {
    return Directory(sourcePath)
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              p.extension(file.path) == _dartExtension &&
              (excludedSuffix == null || !file.path.endsWith(excludedSuffix)),
        );
  }

  static Future<ResolvedUnitResult> _resolve(
    AnalysisSession session,
    File file,
  ) async {
    final result = await session.getResolvedUnit(file.path);

    if (result is! ResolvedUnitResult) {
      throw AtlasException('Cannot resolve ${file.path}.');
    }

    return result;
  }

  Iterable<String> _readRootIds(String widgetName) {
    return (_graph.classIdsByName[widgetName] ?? const []).where(
      _graph.widgetIds.contains,
    );
  }

  Set<String> _readRootWithStatesAndSuperclasses(String rootId) {
    final allowedIds = <String>{};
    final pendingIds = Queue.of([rootId]);

    while (pendingIds.isNotEmpty) {
      final id = pendingIds.removeFirst();

      if (!allowedIds.add(id)) {
        continue;
      }

      allowedIds
        ..addAll(_graph.stateIds[id] ?? const [])
        ..addAll(_graph.ownerFunctionIds[id] ?? const []);

      final superclassId = _graph.superclassIds[id];

      if (superclassId != null && _graph.widgetIds.contains(superclassId)) {
        pendingIds.add(superclassId);
      }
    }

    return allowedIds;
  }

  List<String> _readStartIds(String id) {
    if (_graph.functionIds.contains(id)) {
      return [id];
    }

    return [_constructionIdOf(id), ...?_graph.memberIds[id]];
  }

  Set<String> _walk(
    Iterable<String> startIds,
    Set<String> allowedIds, {
    required bool isDiFollowed,
  }) {
    final reachedIds = <String>{};
    final pendingIds = Queue.of(startIds);

    while (pendingIds.isNotEmpty) {
      final id = pendingIds.removeFirst();

      if (!reachedIds.add(id)) {
        continue;
      }

      pendingIds.addAll(
        [
          ...?_graph.edges[id],
          if (isDiFollowed) ...?_graph.diEdges[id],
        ].where((neighbourId) => _canEnter(neighbourId, allowedIds)),
      );
    }

    return reachedIds;
  }

  Set<String> _project(Set<String> ids) {
    return {
      for (final id in ids)
        _graph.declarationIds.contains(id) ? id : _readClassId(id),
    };
  }

  bool _isAlsoImported(String name, Set<String> paths) {
    return paths.isNotEmpty && _graph.importedNames.contains(name);
  }

  static Map<String, Object?>? _tryReadFlutterPackage(Object? packages) {
    if (packages is! List) {
      return null;
    }

    return packages
        .map((package) => AtlasJson.readObject(package, _packageConfigPath))
        .firstWhereOrNull(_isFlutterPackage);
  }

  static String _constructionIdOf(String classId) {
    return '$classId$_constructionSuffix';
  }

  bool _canEnter(String id, Set<String> allowedIds) {
    final classId = _readClassId(id);

    return !_graph.widgetIds.contains(classId) || allowedIds.contains(classId);
  }

  static bool _isFlutterPackage(Map<String, Object?> package) {
    return package['name'] == _flutterPackageName;
  }

  String _readClassId(String id) {
    return _graph.ownerIds[id] ?? id;
  }

  static String _memberIdOf(String classId, String name) {
    return '$classId$_memberSeparator$name';
  }
}

/// {@category Utils}
///
/// The declarations a widget visible on a stage reaches, as two disjoint sets
/// of [AtlasStageReach.idOf] ids.
final class AtlasReachedDeclarations {
  /// Ids reached without a DI edge.
  final Set<String> ids;

  /// Ids reached only through a DI edge.
  final Set<String> diIds;

  /// Creates the reached declarations.
  const AtlasReachedDeclarations({required this.ids, required this.diIds});
}

final class _ReachGraph {
  final edges = <String, Set<String>>{};
  final diEdges = <String, Set<String>>{};
  final ownerIds = <String, String>{};
  final memberIds = <String, List<String>>{};
  final classIdsByName = <String, List<String>>{};
  final widgetIds = <String>{};
  final stateIds = <String, List<String>>{};
  final ownerFunctionIds = <String, List<String>>{};
  final functionIds = <String>{};
  final superclassIds = <String, String>{};
  final declarationIds = <String>{};
  final pathsByName = <String, Set<String>>{};
  final importedNames = <String>{};
}

typedef _ClassLike = ({
  String name,
  InstanceElement? element,
  List<ClassMember> members,
  List<AstNode?> header,
});

final class _ReachBuilder {
  static const _flutterLibraryPrefix = 'package:flutter/';
  static const _widgetClassName = 'Widget';
  static const _stateClassName = 'State';
  static const _overrideName = 'override';
  static const _mainFunctionName = 'main';
  static const _unnamedConstructorName = 'new';
  static const _setterSuffix = '=';
  static const _memberSeparator = '.';
  static const _packageScheme = 'package';

  final AtlasLocations _paths;
  final AtlasStaleSettings _settings;
  final _graph = _ReachGraph();
  final _readImportedLibraries = <LibraryElement>{};
  final _idsByElement = <Element, String>{};
  final _references = <String, List<Element>>{};
  final _classElements = <String, InterfaceElement>{};
  final _memberNames = <String, Set<String>>{};
  final _instanceFieldIds = <String, List<String>>{};
  final _overrides = <String, List<(String, String)>>{};
  final _registrations = <(String, Element)>[];
  final _selfRegistrationIds = <String>[];
  final _moduleRegistrations = <(String, Element)>[];
  final _externalModuleMethodIds = <Element, List<String>>{};
  final _constructorIds = <String, List<String>>{};
  final _mainIds = <String>[];
  final _diMemberNames = <String, Set<String>>{};
  final _themeArgumentReferences = <Element, List<Element>>{};
  final _factoryFieldIds = <Element, List<String>>{};
  final _factoryArguments = <AstNode>{};
  final _themeClassIds = <String>{};

  _ReachBuilder(this._paths) : _settings = _paths.project.staleSettings;

  void addUnit(String path, ResolvedUnitResult result) {
    _graph.declarationIds.addAll(
      _paths
          .readDeclarations(result.content)
          .declarations
          .map((declaration) => AtlasStageReach.idOf(path, declaration.key)),
    );
    result.unit.accept(
      _ThemeArgumentVisitor(
        this,
        path,
        _settings.themeExtensionPattern,
        _settings.themeFactorySuffix,
      ),
    );
    _addNames(path, result);
    _addImportedNames(result);

    for (final declaration in result.unit.declarations) {
      _addDeclaration(path, declaration);
    }
  }

  void addFactoryArgument(
    String factoryId,
    FieldElement field,
    NamedArgument argument,
  ) {
    final id = AtlasStageReach._memberIdOf(factoryId, argument.name.lexeme);

    if (!_references.containsKey(id)) {
      _addNode(id, null, [], ownerId: factoryId);
    }

    _references[id]?.addAll(_readReferences([argument.argumentExpression]));
    _factoryFieldIds.putIfAbsent(field.baseElement, () => []).add(id);
    _factoryArguments.add(argument.argumentExpression);
  }

  void addThemeArgument(FieldElement field, NamedArgument argument) {
    _themeArgumentReferences
        .putIfAbsent(field.baseElement, () => [])
        .addAll(_readReferences([argument.argumentExpression]));
  }

  _ReachGraph build() {
    for (final (methodId, registeredElement) in _moduleRegistrations) {
      _addModuleEdge(methodId, registeredElement);
    }

    _references.forEach(_addReferenceEdges);
    _themeArgumentReferences.forEach(_addThemeArgumentEdges);
    _classElements.forEach(_addWidget);
    _mainIds.forEach(_addMainOwnership);

    for (final (implementationId, interfaceElement) in _registrations) {
      _addDiEdges(implementationId, interfaceElement);
    }

    for (final classId in _selfRegistrationIds) {
      _addConstructorEdges(classId, classId);
    }

    _classElements.forEach(_addConstructionEdges);
    _factoryFieldIds.forEach(_addFactoryFieldEdges);

    return _graph;
  }

  void _addNames(String path, ResolvedUnitResult result) {
    final names = {
      for (final declaration
          in _paths.readDeclarations(result.content).declarations)
        declaration.key.split(_memberSeparator).first,
      for (final extension
          in result.unit.declarations.whereType<ExtensionDeclaration>())
        ..._readMemberNames(extension.body.members),
    };

    for (final name in names) {
      _graph.pathsByName.putIfAbsent(name, () => {}).add(path);
    }
  }

  void _addImportedNames(ResolvedUnitResult result) {
    final projectPackage = result.libraryElement.uri.pathSegments.firstOrNull;

    for (final library in result.libraryFragment.importedLibraries) {
      final uri = library.uri;
      final isProjectLibrary =
          uri.isScheme(_packageScheme) &&
          uri.pathSegments.firstOrNull == projectPackage;

      if (isProjectLibrary || !_readImportedLibraries.add(library)) {
        continue;
      }

      _graph.importedNames.addAll(library.exportNamespace.definedNames2.keys);
    }
  }

  void _addDeclaration(String path, CompilationUnitMember declaration) {
    switch (declaration) {
      case ClassDeclaration():
        _addClass(path, declaration);
      case MixinDeclaration():
        _addClassLike(path, (
          name: declaration.name.lexeme,
          element: declaration.declaredFragment?.element,
          members: declaration.body.members,
          header: [
            ...declaration.metadata,
            declaration.onClause,
            declaration.implementsClause,
          ],
        ));
      case EnumDeclaration():
        _addEnum(path, declaration);
      case ExtensionDeclaration():
        _addClassLike(path, (
          name:
              declaration.name?.lexeme ??
              'extension on ${declaration.onClause?.extendedType.toSource()}',
          element: declaration.declaredFragment?.element,
          members: declaration.body.members,
          header: [...declaration.metadata, declaration.onClause],
        ));
      case ExtensionTypeDeclaration():
        _addClassLike(path, (
          name: declaration.namePart.typeName.lexeme,
          element: declaration.declaredFragment?.element,
          members: declaration.body.members,
          header: [
            ...declaration.metadata,
            declaration.namePart,
            declaration.implementsClause,
          ],
        ));
      case FunctionDeclaration():
        _addFunction(path, declaration);
      case TopLevelVariableDeclaration():
        _addTopLevelVariables(path, declaration);
      case TypeAlias():
        _addNode(
          AtlasStageReach.idOf(path, declaration.name.lexeme),
          declaration.declaredFragment?.element,
          _readReferences([declaration]),
        );
    }
  }

  void _addModuleEdge(String methodId, Element registeredElement) {
    final baseElement = registeredElement.baseElement;
    final registeredId = _idsByElement[baseElement];

    if (registeredId == null) {
      _externalModuleMethodIds.putIfAbsent(baseElement, () => []).add(methodId);

      return;
    }

    _addEdge(registeredId, methodId, isDi: true);
  }

  void _addThemeArgumentEdges(Element field, List<Element> references) {
    final fieldId = _idsByElement[field];

    if (fieldId != null) {
      _addReferenceEdges(fieldId, references);
    }
  }

  void _addWidget(String classId, InterfaceElement element) {
    final superclassElement = element.supertype?.element;
    final superclassId = superclassElement == null
        ? null
        : _idsByElement[superclassElement.baseElement];
    final supertypes = element.allSupertypes;
    final stateType = supertypes.firstWhereOrNull(
      (type) => _isFlutterClass(type, _stateClassName),
    );

    if (superclassId != null) {
      _graph.superclassIds[classId] = superclassId;
    }

    if (supertypes.any((type) => _isFlutterClass(type, _widgetClassName))) {
      _graph.widgetIds.add(classId);
    }

    if (stateType != null) {
      _addState(classId, stateType);
    }
  }

  void _addMainOwnership(String mainId) {
    final widgetIds = (_graph.edges[mainId] ?? const <String>{})
        .map((id) => _graph.ownerIds[id] ?? id)
        .where(_graph.widgetIds.contains);

    for (final widgetId in widgetIds) {
      _graph.ownerFunctionIds.putIfAbsent(widgetId, () => []).add(mainId);
    }
  }

  void _addDiEdges(String implementationId, Element interfaceElement) {
    final interfaceId = _idsByElement[interfaceElement.baseElement];
    final interfaceClass = _classElements[interfaceId];

    if (interfaceId == null || interfaceClass == null) {
      return;
    }

    final interfaceIds = [
      interfaceId,
      ...interfaceClass.allSupertypes
          .map((type) => _idsByElement[type.element.baseElement])
          .nonNulls,
    ];

    _diMemberNames[implementationId] = {
      for (final id in interfaceIds) ...?_memberNames[id],
    };

    _addEdge(
      interfaceId,
      AtlasStageReach._constructionIdOf(implementationId),
      isDi: true,
    );
    _addConstructorEdges(interfaceId, implementationId);

    for (final id in interfaceIds) {
      _addDiMemberEdges(id, implementationId);
    }
  }

  void _addConstructionEdges(String classId, InterfaceElement element) {
    final constructionId = AtlasStageReach._constructionIdOf(classId);
    final isThemeClass = _themeClassIds.contains(classId);
    final diMemberNames = _diMemberNames[classId] ?? const <String>{};
    final overrideIds = (_overrides[classId] ?? const [])
        .where((override) => !diMemberNames.contains(override.$2))
        .map((override) => override.$1);
    final supertypeIds = [?element.supertype, ...element.mixins]
        .map((type) => _idsByElement[type.element.baseElement])
        .nonNulls
        .map(AtlasStageReach._constructionIdOf);

    for (final id in [
      if (!isThemeClass) ...?_instanceFieldIds[classId],
      if (!isThemeClass) ...overrideIds,
      ...supertypeIds,
    ]) {
      _addEdge(constructionId, id);
    }
  }

  void _addFactoryFieldEdges(Element field, List<String> argumentIds) {
    final fieldId = _idsByElement[field];

    if (fieldId == null) {
      return;
    }

    for (final argumentId in argumentIds) {
      _addEdge(fieldId, argumentId);
    }
  }

  Iterable<String> _readMemberNames(List<ClassMember> members) {
    return members.expand(
      (member) => switch (member) {
        MethodDeclaration(:final name) => [name.lexeme],
        FieldDeclaration(:final fields) => fields.variables.map(
          (variable) => variable.name.lexeme,
        ),
        _ => const <String>[],
      },
    );
  }

  void _addClass(String path, ClassDeclaration declaration) {
    final name = declaration.namePart.typeName.lexeme;
    final classId = AtlasStageReach.idOf(path, name);
    final interfaceElement = _tryReadRegisteredInterface(declaration.metadata);

    _addClassLike(path, (
      name: name,
      element: declaration.declaredFragment?.element,
      members: declaration.body.members,
      header: [
        ...declaration.metadata,
        declaration.namePart,
        declaration.extendsClause,
        declaration.withClause,
        declaration.implementsClause,
      ],
    ));

    if (_hasAnnotation(declaration.metadata, {_settings.moduleAnnotation})) {
      _addModuleRegistrations(classId, declaration.body.members);
    }

    if (interfaceElement != null) {
      _registrations.add((classId, interfaceElement));

      return;
    }

    if (_hasAnnotation(
      declaration.metadata,
      _settings.selfRegistrationAnnotations,
    )) {
      _selfRegistrationIds.add(classId);
    }
  }

  void _addEnum(String path, EnumDeclaration declaration) {
    final name = declaration.namePart.typeName.lexeme;
    final enumId = AtlasStageReach.idOf(path, name);

    _addClassLike(path, (
      name: name,
      element: declaration.declaredFragment?.element,
      members: declaration.body.members,
      header: [
        ...declaration.metadata,
        declaration.withClause,
        declaration.implementsClause,
      ],
    ));

    for (final constant in declaration.body.constants) {
      final id = AtlasStageReach._memberIdOf(enumId, constant.name.lexeme);

      _addNode(
        id,
        constant.declaredFragment?.element,
        _readReferences([constant]),
        ownerId: enumId,
      );
      _addEdge(id, AtlasStageReach._constructionIdOf(enumId));
      _memberNames[enumId]?.add(constant.name.lexeme);
    }
  }

  void _addFunction(String path, FunctionDeclaration declaration) {
    final name = _readFunctionName(declaration);
    final id = AtlasStageReach.idOf(path, name);

    _addNode(
      id,
      declaration.declaredFragment?.element,
      _readReferences([declaration]),
    );
    _graph.functionIds.add(id);

    if (name == _mainFunctionName) {
      _mainIds.add(id);
    }
  }

  void _addTopLevelVariables(
    String path,
    TopLevelVariableDeclaration declaration,
  ) {
    for (final variable in declaration.variables.variables) {
      _addNode(
        AtlasStageReach.idOf(path, variable.name.lexeme),
        variable.declaredFragment?.element,
        _readReferences([
          declaration.variables.type,
          variable.initializer,
          ...declaration.metadata,
        ]),
      );
    }
  }

  void _addReferenceEdges(String id, List<Element> references) {
    for (final reference in references) {
      final targetId = _tryResolve(reference);

      if (targetId != null && targetId != id) {
        _addEdge(id, targetId);
      }

      for (final methodId
          in _externalModuleMethodIds[reference.baseElement] ?? const []) {
        _addEdge(id, methodId, isDi: true);
      }
    }
  }

  bool _isFlutterClass(InterfaceType type, String name) {
    return type.element.name == name &&
        type.element.library.uri.toString().startsWith(_flutterLibraryPrefix);
  }

  void _addState(String stateId, InterfaceType stateType) {
    final widgetElement = stateType.typeArguments.firstOrNull?.element;
    final widgetId = widgetElement == null
        ? null
        : _idsByElement[widgetElement.baseElement];

    _graph.widgetIds.add(stateId);

    if (widgetId != null) {
      _graph.stateIds.putIfAbsent(widgetId, () => []).add(stateId);
    }
  }

  void _addConstructorEdges(String registeredId, String classId) {
    for (final constructorId in _constructorIds[classId] ?? const <String>[]) {
      _addEdge(registeredId, constructorId, isDi: true);
    }
  }

  void _addDiMemberEdges(String interfaceId, String implementationId) {
    for (final name in _memberNames[interfaceId] ?? const <String>{}) {
      final implementationMemberId = AtlasStageReach._memberIdOf(
        implementationId,
        name,
      );

      if (_graph.ownerIds.containsKey(implementationMemberId)) {
        _addEdge(
          AtlasStageReach._memberIdOf(interfaceId, name),
          implementationMemberId,
          isDi: true,
        );
      }
    }
  }

  void _addModuleRegistrations(String classId, List<ClassMember> members) {
    final methods = members.whereType<MethodDeclaration>().where(
      (method) => !Identifier.isPrivateName(method.name.lexeme),
    );

    for (final method in methods) {
      final registeredElement =
          _tryReadRegisteredInterface(method.metadata) ??
          _tryReadRegisteredType(method.returnType?.type);

      if (registeredElement != null) {
        _moduleRegistrations.add((
          AtlasStageReach._memberIdOf(classId, method.name.lexeme),
          registeredElement,
        ));
      }
    }
  }

  bool _isThemeClassName(String name) {
    final pattern = _settings.themeClassPattern;

    return pattern != null && RegExp(pattern).hasMatch(name);
  }

  bool _hasAnnotation(NodeList<Annotation> metadata, Set<String> names) {
    return metadata.any((annotation) => names.contains(annotation.name.name));
  }

  void _addClassLike(String path, _ClassLike classLike) {
    final classId = AtlasStageReach.idOf(path, classLike.name);
    final element = classLike.element;
    final constructionId = AtlasStageReach._constructionIdOf(classId);

    _addNode(classId, element, _readReferences(classLike.header));

    if (_isThemeClassName(classLike.name)) {
      _themeClassIds.add(classId);
    }

    if (element is InterfaceElement) {
      _classElements[classId] = element;

      _graph.classIdsByName.putIfAbsent(classLike.name, () => []).add(classId);
    }

    _graph.ownerIds[constructionId] = classId;

    _addEdge(constructionId, classId);

    _memberNames[classId] = {};

    for (final member in classLike.members) {
      _addMember(classId, member);
    }
  }

  String _readFunctionName(FunctionDeclaration declaration) {
    final name = declaration.name.lexeme;

    return declaration.isSetter ? '$name$_setterSuffix' : name;
  }

  String? _tryResolve(Element element) {
    final baseElement = element.baseElement;

    return _idsByElement[baseElement] ?? _tryResolveIndirectly(baseElement);
  }

  Element? _tryReadRegisteredInterface(NodeList<Annotation> metadata) {
    final arguments = metadata
        .where(
          (annotation) =>
              _settings.registrationAnnotations.contains(annotation.name.name),
        )
        .expand(
          (annotation) => annotation.arguments?.arguments ?? <Expression>[],
        )
        .whereType<NamedArgument>();
    final interfaceExpression = arguments
        .firstWhereOrNull(
          (argument) => argument.name.lexeme == _settings.registrationArgument,
        )
        ?.argumentExpression;

    return switch (interfaceExpression) {
      SimpleIdentifier(:final element) => element,
      TypeLiteral(:final type) => type.element,
      _ => null,
    };
  }

  Element? _tryReadRegisteredType(DartType? returnType) {
    if (returnType is InterfaceType && returnType.isDartAsyncFuture) {
      return returnType.typeArguments.firstOrNull?.element;
    }

    return returnType?.element;
  }

  void _addMember(String classId, ClassMember member) {
    switch (member) {
      case FieldDeclaration():
        _addFields(classId, member);
      case MethodDeclaration():
        _addMethod(classId, member);
      case ConstructorDeclaration():
        final id = AtlasStageReach._memberIdOf(
          classId,
          member.name?.lexeme ?? _unnamedConstructorName,
        );

        _addNode(
          id,
          member.declaredFragment?.element,
          _themeClassIds.contains(classId) ? [] : _readReferences([member]),
          ownerId: classId,
        );
        _addEdge(id, AtlasStageReach._constructionIdOf(classId));
        _constructorIds.putIfAbsent(classId, () => []).add(id);
      case PrimaryConstructorBody():
        return;
    }
  }

  String? _tryResolveIndirectly(Element element) {
    switch (element) {
      case PropertyAccessorElement(:final variable)
          when _idsByElement.containsKey(variable.baseElement):
        return _idsByElement[variable.baseElement];
      case FieldFormalParameterElement(:final field):
        return field == null ? null : _idsByElement[field.baseElement];
      case ConstructorElement(:final enclosingElement):
        final classId = _idsByElement[enclosingElement.baseElement];

        return classId == null
            ? null
            : AtlasStageReach._constructionIdOf(classId);
      default:
        final enclosingElement = element.enclosingElement;

        return enclosingElement is InstanceElement
            ? _idsByElement[enclosingElement.baseElement]
            : null;
    }
  }

  void _addFields(String classId, FieldDeclaration declaration) {
    for (final variable in declaration.fields.variables) {
      final name = variable.name.lexeme;
      final id = AtlasStageReach._memberIdOf(classId, name);

      _memberNames[classId]?.add(name);
      _addNode(
        id,
        variable.declaredFragment?.element,
        _readReferences([
          declaration.fields.type,
          variable.initializer,
          ...declaration.metadata,
        ]),
        ownerId: classId,
      );

      if (!declaration.isStatic) {
        _instanceFieldIds.putIfAbsent(classId, () => []).add(id);
      }
    }
  }

  void _addMethod(String classId, MethodDeclaration declaration) {
    final name = declaration.name.lexeme;
    final id = AtlasStageReach._memberIdOf(
      classId,
      declaration.isSetter ? '$name$_setterSuffix' : name,
    );

    _memberNames[classId]?.add(name);
    _addNode(
      id,
      declaration.declaredFragment?.element,
      _readReferences([declaration]),
      ownerId: classId,
    );

    if (_isInstanceOverride(declaration)) {
      _overrides.putIfAbsent(classId, () => []).add((id, name));
    }
  }

  void _addNode(
    String id,
    Element? element,
    List<Element> references, {
    String? ownerId,
  }) {
    _references[id] = references;

    if (element != null) {
      _idsByElement[element.baseElement] = id;
    }

    if (ownerId != null) {
      _graph.ownerIds[id] = ownerId;

      _graph.memberIds.putIfAbsent(ownerId, () => []).add(id);
      _addEdge(id, ownerId);
    }
  }

  List<Element> _readReferences(Iterable<AstNode?> nodes) {
    final collector = _ReferenceCollector(_factoryArguments);

    for (final node in nodes) {
      node?.accept(collector);
    }

    return collector.elements;
  }

  bool _isInstanceOverride(MethodDeclaration declaration) {
    return !declaration.isStatic &&
        declaration.metadata.any(
          (annotation) => annotation.name.name == _overrideName,
        );
  }

  void _addEdge(String fromId, String toId, {bool isDi = false}) {
    (isDi ? _graph.diEdges : _graph.edges)
        .putIfAbsent(fromId, () => {})
        .add(toId);
  }
}

final class _ReferenceCollector extends GeneralizingAstVisitor<void> {
  final elements = <Element>[];
  final Set<AstNode> _skippedNodes;

  _ReferenceCollector(this._skippedNodes);

  @override
  void visitNode(AstNode node) {
    if (_skippedNodes.contains(node)) {
      return;
    }

    elements.addAll(_readElements(node).nonNulls);
    super.visitNode(node);
  }

  List<Element?> _readElements(AstNode node) {
    return switch (node) {
      CompoundAssignmentExpression(:final readElement, :final writeElement) &&
          MethodReferenceExpression(:final element) =>
        [readElement, writeElement, element],
      CompoundAssignmentExpression(:final readElement, :final writeElement) => [
        readElement,
        writeElement,
      ],
      MethodReferenceExpression(:final element) => [element],
      SimpleIdentifier(:final element) => [element],
      NamedType(:final element) => [element],
      ConstructorName(:final element) => [element],
      Annotation(:final element) => [element],
      SuperConstructorInvocation(:final element) => [element],
      RedirectingConstructorInvocation(:final element) => [element],
      PatternField(:final element) => [element],
      DotShorthandConstructorInvocation(:final element) => [element],
      _ => const [],
    };
  }
}

final class _ThemeArgumentVisitor extends RecursiveAstVisitor<void> {
  final _ReachBuilder _builder;
  final String _path;
  final RegExp? _themeExtensionPattern;
  final String? _factorySuffix;
  String? _className;

  _ThemeArgumentVisitor(
    this._builder,
    this._path,
    String? themeExtensionPattern,
    this._factorySuffix,
  ) : _themeExtensionPattern = themeExtensionPattern == null
          ? null
          : RegExp(themeExtensionPattern);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _className = node.namePart.typeName.lexeme;

    super.visitClassDeclaration(node);

    _className = null;
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final createdClass = node.constructorName.element?.enclosingElement;

    if (createdClass != null && _isThemeExtension(createdClass)) {
      node.argumentList.arguments.whereType<NamedArgument>().forEach(
        (argument) => _addArgument(createdClass, argument),
      );
    }

    super.visitInstanceCreationExpression(node);
  }

  bool _isThemeExtension(InterfaceElement createdClass) {
    return _themeExtensionPattern?.hasMatch(createdClass.name ?? '') ?? false;
  }

  bool _isFactory(String className) {
    final suffix = _factorySuffix;

    return suffix != null && className.endsWith(suffix);
  }

  void _addArgument(InterfaceElement createdClass, NamedArgument argument) {
    final field = createdClass.getField(argument.name.lexeme);
    final className = _className;

    if (field == null) {
      return;
    }

    if (className != null && _isFactory(className)) {
      _builder.addFactoryArgument(
        AtlasStageReach.idOf(_path, className),
        field,
        argument,
      );

      return;
    }

    _builder.addThemeArgument(field, argument);
  }
}
