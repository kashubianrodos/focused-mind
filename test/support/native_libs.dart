import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

/// Loads BrainBit's prebuilt macOS libraries into the test process by full
/// path. In the app, CocoaPods bundles them and the packages open them by
/// leaf name; once loaded here, those leaf-name opens resolve to the same
/// image, so the real vendor code runs under `flutter test`.
void loadVendorLibraries() {
  if (!Platform.isMacOS) {
    throw UnsupportedError('Vendor library tests run on macOS only');
  }
  DynamicLibrary.open(
    vendorLibraryPath('em_st_artifacts', 'macos/libEmStArtifacts.dylib'),
  );
}

String vendorLibraryPath(String package, String relative) {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final packages = (config['packages'] as List).cast<Map<String, Object?>>();
  final entry = packages.firstWhere((p) => p['name'] == package);
  final rootUri = entry['rootUri'] as String;
  final root = Uri.parse(rootUri.endsWith('/') ? rootUri : '$rootUri/');
  final base = root.isAbsolute
      ? root
      : Uri.directory(Directory('.dart_tool').absolute.path).resolveUri(root);
  return base.resolve(relative).toFilePath();
}
