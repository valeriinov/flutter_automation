/// {@category Utils}
///
/// The files and the names the atlas compares to tell what code a stage
/// depends on.
final class AtlasStaleSettings {
  /// The folder of the mock; a capture leaves its files out of the manifest,
  /// since the replay of the journal compares what the mock answers.
  final String mockDirectory;

  /// The folder of the automation targets; a change there never stales a
  /// stage.
  final String targetsDirectory;

  /// The folder of the automation module; `normalize-manifests` drops a path
  /// of it that no longer exists.
  final String automationDirectory;

  /// The files and folders, by path prefix, whose change never stales a
  /// stage: the analytics records are compared through the journal, and the
  /// endpoint list through the replay.
  final List<String> uncomparedPaths;

  /// How a stage finds the file of its screen; absent when the project has no
  /// route list, and a stage then names no source file of its own.
  final AtlasRouteSettings? routes;

  /// The files the walk from a screen to its sources stops at, because they
  /// import nearly every screen.
  final List<String> stopPaths;

  /// The pattern of the name of a theme class, whose fields are declarations
  /// of their own; absent when the project has none.
  final String? themeClassPattern;

  /// The pattern of the name of a theme class whose members with parameters
  /// are fields too; absent when the project has none.
  final String? themeValueClassPattern;

  /// The pattern of the name of a theme extension class; a value a widget
  /// passes to its constructor reaches the field it fills. Absent when the
  /// project has none, and the walk then follows no theme argument.
  final String? themeExtensionPattern;

  /// The suffix of the name of the class that builds a theme extension; a
  /// value it passes reaches the field it fills through the class. Absent when
  /// the project has none.
  final String? themeFactorySuffix;

  /// The suffix of the generated files the reach of a widget leaves out;
  /// absent when the reach leaves none out.
  final String? excludedSuffix;

  /// The annotations that register a class for dependency injection.
  final Set<String> registrationAnnotations;

  /// The annotations that register the annotated class as a whole.
  final Set<String> selfRegistrationAnnotations;

  /// The annotation of a class that registers what its methods return.
  final String moduleAnnotation;

  /// The name of the annotation argument that gives the registered type.
  final String registrationArgument;

  const AtlasStaleSettings({
    required this.mockDirectory,
    required this.targetsDirectory,
    required this.automationDirectory,
    required this.stopPaths,
    this.routes,
    this.uncomparedPaths = const [],
    this.themeClassPattern,
    this.themeValueClassPattern,
    this.themeExtensionPattern,
    this.themeFactorySuffix,
    this.excludedSuffix,
    this.registrationAnnotations = const {},
    this.selfRegistrationAnnotations = const {},
    this.moduleAnnotation = '',
    this.registrationArgument = '',
  });
}

/// {@category Utils}
///
/// The files that tell which source file shows the screen of a route.
final class AtlasRouteSettings {
  /// The generated file that lists a route class for each screen.
  final String routesPath;

  /// The pattern of a route class in [routesPath]; group 1 is the screen
  /// class and group 2 the route class.
  final String routePattern;

  /// The file that imports every screen; the walk from a route looks for the
  /// file of its screen class among the files it imports.
  final String routerPath;

  const AtlasRouteSettings({
    required this.routesPath,
    required this.routePattern,
    required this.routerPath,
  });
}
