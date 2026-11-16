#!/usr/bin/env bash
# Version for CI builds, shared by the Android and iOS workflows so both
# platforms ship the same version and build number.
#
#   version  release version: the tag without its "v" on tag builds,
#            pubspec.yaml's version otherwise (e.g. 0.3.0 or 0.3.0-beta.1)
#   name     version shown in the app stores: numbers only (0.3.0), as
#            iOS requires
#   build    build number: the commit count, the same on every platform and
#            increasing with each commit (needs a full checkout)
#
# A tag must match pubspec.yaml (v0.3.0 or v0.3.0-beta.1 for 0.3.0), so the
# version in the code and the release never drift apart.
set -euo pipefail

pubspec="$(sed -nE 's/^version: *([^+ ]+).*/\1/p' pubspec.yaml)"
if [[ "${GITHUB_REF:-}" == refs/tags/v* ]]; then
  version="${GITHUB_REF_NAME#v}"
  if [[ "${version%%-*}" != "${pubspec%%-*}" ]]; then
    echo "::error::Tag $GITHUB_REF_NAME does not match pubspec.yaml version $pubspec; update pubspec.yaml first"
    exit 1
  fi
else
  version="$pubspec"
fi
name="${version%%-*}"
build="$(git rev-list --count HEAD)"

echo "Version $version (app version $name, build $build)"
{
  echo "version=$version"
  echo "name=$name"
  echo "build=$build"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"
