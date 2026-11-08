import 'resource_launcher_stub.dart'
    if (dart.library.html) 'resource_launcher_web.dart'
    as platform;

Future<void> openLearningResource(String value) =>
    platform.openLearningResource(value);
