import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Builds the neurosdk2 callback shim (`native/fm_shim.cpp`, design D3)
/// into a code asset bound by `lib/headband/ffi/fm_shim.dart`.
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    await CBuilder.library(
      name: 'fm_shim',
      assetName: 'headband/ffi/fm_shim.dart',
      sources: ['native/fm_shim.cpp'],
      includes: ['third_party/neurosdk2/include'],
      language: Language.cpp,
      std: 'c++17',
      // Android doesn't ship libc++_shared.so in the APK; link it in.
      cppLinkStdLib: input.config.code.targetOS == OS.android
          ? 'c++_static'
          : null,
    ).run(input: input, output: output);
  });
}
