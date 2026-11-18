import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_headless.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_runner_catalogue.dart';

import 'fake_atlas_project.dart';
import 'test_automation_pubspec.dart';

const testFlutterVersion = '3.47.5';

final class TestAtlasRoot {
  final Directory directory;
  final FakeAtlasProject project;
  final AtlasLocations paths;
  final Map<String, Object?> _flows = {};
  final Map<String, Object?> _blocks = {};

  TestAtlasRoot(this.directory, this.project, {String? store})
    : paths = AtlasLocations(directory.path, project, store: store) {
    writeText(paths.resolve('pubspec.yaml'), testAutomationPubspec);
    AtlasRunnerCatalogue.seed(
      directory.path,
      AtlasRunnerCatalogue(flows: _flows, blocks: _blocks),
    );
  }

  static Future<void> run(FutureOr<void> Function(TestAtlasRoot root) body) {
    return runWith(body);
  }

  static Future<void> runWith(
    FutureOr<void> Function(TestAtlasRoot root) body, {
    FakeAtlasProject? project,
    String? store,
  }) {
    final fakeProject = project ?? FakeAtlasProject();

    return _run(
      (directory) => TestAtlasRoot(directory, fakeProject, store: store),
      body,
    );
  }

  static Future<void> _run(
    TestAtlasRoot Function(Directory directory) create,
    FutureOr<void> Function(TestAtlasRoot root) body,
  ) async {
    final directory = await Directory.systemTemp.createTemp('atlas-');

    try {
      await body(create(directory));
    } finally {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
  }

  void writeText(String path, String content) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  void writeFlow(String name, Map<String, Object?> json) {
    _flows[name] = json;
  }

  void writeFlowGroup(String name, Map<String, Object?> group) {
    _flows[name] = {...?_flows[name] as Map<String, Object?>?, 'group': group};
  }

  void writeBlock(String name, Map<String, Object?> json) {
    _blocks[name] = json;
  }

  void writeSource(String path, String content) {
    writeText(paths.resolve(path), content);
  }

  void deleteSource(String path) {
    File(paths.resolve(path)).deleteSync();
  }

  void writePublishedVariants(Map<String, Object?> json) {
    writeText(paths.publishedVariantsPath, jsonEncode(json));
  }

  void writeTranslations(String locale, Map<String, Object?> json) {
    project.translationsByLocale[locale] = json;
  }

  void deletePublishedVariants() {
    File(paths.publishedVariantsPath).deleteSync();
  }

  void writeShot(String shot, List<int> bytes) {
    File(paths.resolveShotPath(shot))
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }

  void writeHeadlessReport(
    AtlasHeadlessReport report, {
    required String flow,
    required String variant,
    String? locale,
    bool isBaseline = false,
  }) {
    writeText(
      paths.resolveHeadlessReportPath(
        flow: flow,
        variant: variant,
        locale: locale ?? paths.defaultLocale,
        isBaseline: isBaseline,
      ),
      jsonEncode(report.toJson()),
    );
  }

  void writeFlutterConfig() {
    writeSource('.fvmrc', jsonEncode({'flutter': testFlutterVersion}));
  }

  Future<Directory> createCaptureDirectory() {
    return Directory(p.join(directory.path, 'capture')).create();
  }
}
