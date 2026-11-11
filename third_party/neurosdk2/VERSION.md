# neurosdk2 C headers

Copied unmodified (line endings normalized) from the `neurosdk2` Flutter
package **1.0.21** on pub.dev (`windows/include/neurosdk2/`). They are
identical to the copies in its `darwin/Classes/Neuro/`.

The app binds to these with `ffigen` (see `ffigen.yaml`) and loads the
`libneurosdk2` binary that the same package ships for each platform, so the
headers must be updated together with the `neurosdk2` version pin in
`pubspec.yaml`.

The headers are C++ (typed enums, default arguments), so ffigen parses them in
C++ mode; all bound functions are declared `extern "C"`.
