import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_automation_driver/src/automation_frame_readiness.dart';

const _windowSize = Size(400, 800);
const _imageSize = 40.0;

void main() {
  group('AutomationFrameReadiness Widget Tests', () {
    _automationFrameReadiness_should_findNoDefectInAReadyFrame();
    _automationFrameReadiness_should_countAnImageWithoutAFrame();
    _automationFrameReadiness_should_countAnEmptyText();
    _automationFrameReadiness_should_countAWhitespaceText();
    _automationFrameReadiness_should_leaveOutAnEmptyTextOffstage();
    _automationFrameReadiness_should_leaveOutAnEmptyTextField();
    _automationFrameReadiness_should_leaveOutTheEmptyTextsOfAnInputDecorator();
    _automationFrameReadiness_should_leaveOutAnImageUnderAnOpaqueRoute();
    _automationFrameReadiness_should_leaveOutAnImageOffstage();
    _automationFrameReadiness_should_leaveOutAnImageInTheCacheExtent();
    _automationFrameReadiness_should_nameTheTargetOfAKeyedSubtreeOnly();
    _automationFrameReadiness_should_nameTheItemsWithRectAndTarget();
    _automationFrameReadiness_should_capTheItemsPerKind();
  });
}

void _automationFrameReadiness_should_findNoDefectInAReadyFrame() {
  testWidgets(
    'AutomationFrameReadiness should find no defect in a ready frame',
    (tester) async {
      final decoded = await tester.runAsync(
        () => createTestImage(width: 2, height: 2),
      );

      await tester.pumpWidget(
        _buildApp([
          const Text('Hello'),
          Image(image: _TestImageProvider.decoded(decoded!)),
        ]),
      );
      await tester.pump();

      final sut = _read(tester);

      expect(sut.loadingImages, 0);
      expect(sut.emptyTexts, 0);
    },
  );
}

void _automationFrameReadiness_should_countAnImageWithoutAFrame() {
  testWidgets(
    'AutomationFrameReadiness should count an image without a frame',
    (tester) async {
      await tester.pumpWidget(
        _buildApp([Image(image: _TestImageProvider.loading())]),
      );
      await tester.pump();

      final sut = _read(tester);

      expect(sut.loadingImages, 1);
      expect(sut.emptyTexts, 0);
    },
  );
}

void _automationFrameReadiness_should_countAnEmptyText() {
  testWidgets('AutomationFrameReadiness should count an empty text', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp([const Text('Hello'), const Text('')]));

    final sut = _read(tester);

    expect(sut.emptyTexts, 1);
    expect(sut.loadingImages, 0);
  });
}

void _automationFrameReadiness_should_countAWhitespaceText() {
  testWidgets('AutomationFrameReadiness should count a whitespace text', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp([const Text('  ')]));

    expect(_read(tester).emptyTexts, 1);
  });
}

void _automationFrameReadiness_should_leaveOutAnEmptyTextOffstage() {
  testWidgets('AutomationFrameReadiness should leave out an offstage text', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp([const Offstage(child: Text(''))]));

    expect(_read(tester).emptyTexts, 0);
  });
}

void _automationFrameReadiness_should_leaveOutAnEmptyTextField() {
  testWidgets('AutomationFrameReadiness should leave out an empty text field', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp([
        SizedBox(
          width: 200,
          child: TextField(controller: TextEditingController()),
        ),
      ]),
    );

    expect(_read(tester).emptyTexts, 0);
  });
}

void
_automationFrameReadiness_should_leaveOutTheEmptyTextsOfAnInputDecorator() {
  const decorations = {
    'helperText': InputDecoration(helperText: ''),
    'errorText': InputDecoration(errorText: ''),
    'hintText': InputDecoration(hintText: ''),
  };

  for (final MapEntry(:key, :value) in decorations.entries) {
    testWidgets(
      'AutomationFrameReadiness should leave out an empty $key of an input '
      'decorator',
      (tester) async {
        await tester.pumpWidget(
          _buildApp([TextField(decoration: value), const Text('Hello')]),
        );

        expect(_read(tester).emptyTexts, 0);
      },
    );
  }
}

void _automationFrameReadiness_should_leaveOutAnImageUnderAnOpaqueRoute() {
  testWidgets(
    'AutomationFrameReadiness should leave out an image under an opaque route',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Image(image: _TestImageProvider.loading()),
        ),
      );

      expect(_read(tester).loadingImages, 1);
      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Text('Next')),
        ),
      );

      await tester.pumpAndSettle();

      expect(_read(tester).loadingImages, 0);
    },
  );
}

void _automationFrameReadiness_should_leaveOutAnImageOffstage() {
  testWidgets('AutomationFrameReadiness should leave out an image offstage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp([Offstage(child: Image(image: _TestImageProvider.loading()))]),
    );

    expect(_read(tester).loadingImages, 0);
  });
}

void _automationFrameReadiness_should_leaveOutAnImageInTheCacheExtent() {
  testWidgets(
    'AutomationFrameReadiness should leave out an image in the cache extent',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: 100,
                child: ListView(
                  itemExtent: 100,
                  children: [
                    const Text('Shown'),
                    const Text('Shown'),
                    Image(image: _TestImageProvider.loading()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Image, skipOffstage: false), findsOneWidget);
      expect(_read(tester).loadingImages, 0);
    },
  );
}

void _automationFrameReadiness_should_nameTheTargetOfAKeyedSubtreeOnly() {
  testWidgets(
    'AutomationFrameReadiness should name the target of a keyed subtree only',
    (tester) async {
      await tester.pumpWidget(
        _buildApp([
          Column(
            key: const PageStorageKey<String>('list.page'),
            children: [
              Container(
                key: const ValueKey<String>('list.row'),
                child: const Text(''),
              ),
            ],
          ),
        ]),
      );

      expect(_read(tester).emptyTextItems.single.target, isNull);
    },
  );
}

void _automationFrameReadiness_should_nameTheItemsWithRectAndTarget() {
  testWidgets(
    'AutomationFrameReadiness should name the items with rect and target',
    (tester) async {
      await tester.pumpWidget(
        _buildApp([
          KeyedSubtree(
            key: const ValueKey<String>('form.title'),
            child: const Text(''),
          ),
          Image(image: _TestImageProvider.loading()),
        ]),
      );

      final sut = _read(tester);
      final emptyText = sut.emptyTextItems.single;
      final loadingImage = sut.loadingImageItems.single;

      expect(emptyText.target, 'form.title');
      expect(emptyText.rect.left, _imageSize * 0);
      expect(emptyText.toJson(), {
        'rect': [
          emptyText.rect.left.round(),
          emptyText.rect.top.round(),
          emptyText.rect.width.round(),
          emptyText.rect.height.round(),
        ],
        'target': 'form.title',
      });
      expect(loadingImage.target, isNull);
    },
  );
}

void _automationFrameReadiness_should_capTheItemsPerKind() {
  testWidgets('AutomationFrameReadiness should cap the items per kind', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp([for (int index = 0; index < 7; index += 1) const Text('')]),
    );

    final sut = _read(tester);

    expect(sut.emptyTexts, 7);
    expect(sut.emptyTextItems, hasLength(AutomationFrameReadiness.maxItems));
  });
}

Widget _buildApp(List<Widget> children) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          for (final child in children)
            SizedBox(width: _imageSize * 5, child: child),
        ],
      ),
    ),
  );
}

AutomationFrameReadiness _read(WidgetTester tester) {
  return AutomationFrameReadiness.read(
    tester.binding.rootElement!,
    Offset.zero & _windowSize,
  );
}

final class _TestImageProvider extends ImageProvider<_TestImageProvider> {
  final ui.Image? _image;

  _TestImageProvider.decoded(ui.Image image) : _image = image;

  _TestImageProvider.loading() : _image = null;

  @override
  Future<_TestImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _TestImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final image = _image;

    return OneFrameImageStreamCompleter(
      image == null
          ? Completer<ImageInfo>().future
          : SynchronousFuture(ImageInfo(image: image)),
    );
  }
}
