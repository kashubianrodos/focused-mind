import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/headband/ffi/neurosdk_library.dart';

import '../../support/native_libs.dart';

void main() {
  // Loading neurosdk2 in the test host blocks in its Bluetooth start-up, so
  // the bundled binary is checked with nm here and loaded only in the app.
  test('the bundled neurosdk2 exports every bound function', () async {
    final path = vendorLibraryPath('neurosdk2', 'darwin/libneurosdk2.dylib');
    final nm = await Process.run('nm', ['-gU', '-arch', 'arm64', path]);
    expect(nm.exitCode, 0, reason: '${nm.stderr}');
    final exported = {
      for (final line in (nm.stdout as String).split('\n'))
        if (line.trim().isNotEmpty) line.trim().split(' ').last,
    };
    final missing = NeuroSdkLibrary.symbols
        .where((s) => !exported.contains('_$s'))
        .toList();
    expect(missing, isEmpty);
  });

  test('a missing function gives a clear error', () {
    expect(
      () => NeuroSdkLibrary.open(
        path: '/usr/lib/libSystem.B.dylib',
        required: ['malloc', 'createScanner'],
      ),
      throwsA(
        isA<NeuroSdkLoadException>().having(
          (e) => e.message,
          'message',
          contains('missing createScanner'),
        ),
      ),
    );
  });

  test('a missing library gives a clear error', () {
    expect(
      () => NeuroSdkLibrary.open(path: '/nonexistent/libneurosdk2.dylib'),
      throwsA(isA<NeuroSdkLoadException>()),
    );
  });
}
