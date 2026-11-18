import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_automation_atlas/src/atlas_declarations.dart';

import 'test_utils/read_test_declarations.dart';

const _twoWidgetsSource = '''
import 'package:flutter/material.dart';

part 'two_widgets.g.dart';

/// Shows [OtherCard] nowhere.
class FirstCard extends StatelessWidget {
  const FirstCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Text('\${context.appDimensExt.gapLg} first');
  }
}

@Register(as: CardRepository)
class SecondCard extends State<FirstCard> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
''';
const _ownerSource = '''
/// Loads the carts.
class CartsOwner extends Owner<CartsState> {
  final CartsUseCase _useCase;
  final int pageSize = 20, firstPage = 1;
  final void Function(String title)? onTitleLoaded;
  final ({int page, int size}) _limits;

  CartsOwner(this._useCase, {this.onTitleLoaded})
    : _limits = (page: 1, size: 20),
      super(const CartsState()) {
    loadCarts();
  }

  factory CartsOwner.empty() => CartsOwner(const CartsUseCase());

  // Whether a page is loading.
  bool get isLoading => state.isLoading;

  set title(String value) {}

  /* Reads the first page. */
  Future<void> loadCarts() async {
    await _useCase.readCarts(_limits.page);
  }

  @override
  bool operator ==(Object other) => identical(this, other);
}
''';
const _genericFunctionsSource = '''
Future<T?> showCard<T>({required Widget child}) {
  return _show<T>(child);
}

T? _readFirst<T extends Object>(List<T> items) => items.firstOrNull;

Map<String, List<int>> readGroups() => {};

Future<void> loadAll() async {}

void reset() {}
''';

void main() {
  group('AtlasDeclarations Tests', () {
    _atlasDeclarations_should_keepNeighbourClassOnBuildEdit();
    _atlasDeclarations_should_readClassKinds();
    _atlasDeclarations_should_nameGenericFunctionByItsOwnName();
    _atlasDeclarations_should_readEveryMemberOfClass();
    _atlasDeclarations_should_changeOnlyAddedPrivateMethod();
    _atlasDeclarations_should_changeNothingOnCommentEdit();
  });
}

void _atlasDeclarations_should_keepNeighbourClassOnBuildEdit() {
  test('AtlasDeclarations should keep neighbour class on build edit', () {
    final changedKeys = _readChangedKeys(
      _twoWidgetsSource,
      _twoWidgetsSource.replaceFirst('first', 'changed'),
    );

    expect(changedKeys, {'FirstCard.build'});
  });
}

void _atlasDeclarations_should_readClassKinds() {
  test('AtlasDeclarations should read class kinds', () {
    final declarations = readTestDeclarations(_twoWidgetsSource).declarations;

    expect(declarations.map((declaration) => declaration.key), [
      'FirstCard',
      'FirstCard.new',
      'FirstCard.build',
      'SecondCard',
      'SecondCard.build',
    ]);
    expect(declarations.map((declaration) => declaration.kind), [
      AtlasDeclarationKind.classType,
      AtlasDeclarationKind.member,
      AtlasDeclarationKind.member,
      AtlasDeclarationKind.classType,
      AtlasDeclarationKind.member,
    ]);
  });
}

void _atlasDeclarations_should_nameGenericFunctionByItsOwnName() {
  test('AtlasDeclarations should name generic function by its own name', () {
    final declarations = readTestDeclarations(
      _genericFunctionsSource,
    ).declarations;

    expect(declarations.map((declaration) => declaration.key), [
      'showCard',
      '_readFirst',
      'readGroups',
      'loadAll',
      'reset',
    ]);
    expect(
      declarations.map((declaration) => declaration.kind),
      everyElement(AtlasDeclarationKind.function),
    );
  });
}

void _atlasDeclarations_should_readEveryMemberOfClass() {
  test('AtlasDeclarations should read every member of class', () {
    final declarations = readTestDeclarations(_ownerSource).declarations;

    expect(declarations.map((declaration) => declaration.key), [
      'CartsOwner',
      'CartsOwner._useCase',
      'CartsOwner.pageSize',
      'CartsOwner.firstPage',
      'CartsOwner.onTitleLoaded',
      'CartsOwner._limits',
      'CartsOwner.new',
      'CartsOwner.empty',
      'CartsOwner.isLoading',
      'CartsOwner.title=',
      'CartsOwner.loadCarts',
    ]);
  });
}

void _atlasDeclarations_should_changeOnlyAddedPrivateMethod() {
  test('AtlasDeclarations should change only added private method', () {
    final changedKeys = _readChangedKeys(
      _twoWidgetsSource,
      _twoWidgetsSource.replaceFirst(
        '  @override\n  Widget build(BuildContext context) {\n'
            '    return Text(',
        '  String _readTitle() => \'first\';\n\n'
            '  @override\n  Widget build(BuildContext context) {\n'
            '    return Text(',
      ),
    );

    expect(changedKeys, {'FirstCard._readTitle'});
  });
}

void _atlasDeclarations_should_changeNothingOnCommentEdit() {
  test('AtlasDeclarations should change nothing on comment edit', () {
    final editedSource = _ownerSource
        .replaceFirst('/// Loads the carts.', '/// Loads every cart.')
        .replaceFirst('// Whether a page is loading.', '// Whether loading.')
        .replaceFirst('/* Reads the first page. */', '');
    final changedKeys = _readChangedKeys(_ownerSource, editedSource);

    expect(editedSource, isNot(_ownerSource));
    expect(changedKeys, isEmpty);
  });
}

Set<String> _readChangedKeys(String source, String editedSource) {
  final hashes = _readHashes(source);
  final editedHashes = _readHashes(editedSource);

  return {
    ...hashes.keys,
    ...editedHashes.keys,
  }.where((key) => hashes[key] != editedHashes[key]).toSet();
}

Map<String, String> _readHashes(String source) {
  return {
    for (final declaration in readTestDeclarations(source).declarations)
      declaration.key: declaration.hash,
  };
}
