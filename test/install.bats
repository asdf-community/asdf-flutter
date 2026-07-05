#!/usr/bin/env bats

# Unit tests for the stamp-invalidation logic in bin/install.
#
# These tests guard the "watch out" regression called out in ADR001: if the
# install script ever stops deleting engine-dart-sdk.stamp and
# flutter_tools.stamp on non-x86_64 Linux hosts, Flutter's self-heal
# (update_dart_sdk.sh) is never reached on first run and the bundled x86-64
# dart binary stays in place, reproducing "Exec format error" on aarch64.
#
# They also guard the inverse: on x86_64 Linux and on macOS the stamps must
# be left intact so the shipped dart-sdk/snapshot are reused as-is (avoiding
# an unnecessary ~220 MB re-download and tool rebuild).

setup() {
  ASDF_INSTALL_PATH="$(mktemp -d)"
  export ASDF_INSTALL_PATH
  mkdir -p "${ASDF_INSTALL_PATH}/bin/cache"
  : >"${ASDF_INSTALL_PATH}/bin/cache/engine-dart-sdk.stamp"
  : >"${ASDF_INSTALL_PATH}/bin/cache/flutter_tools.stamp"

  # Source the install script to pull in the function under test. bin/install
  # guards its top-level execution behind a BASH_SOURCE check, so sourcing it
  # only defines functions without invoking a download or the install flow.
  # shellcheck source=/dev/null
  source "$(dirname "$BATS_TEST_FILENAME")/../bin/install"
}

teardown() {
  rm -rf "${ASDF_INSTALL_PATH}"
}

stamp_exists() {
  [ -f "${ASDF_INSTALL_PATH}/bin/cache/$1" ]
}

# ---------------------------------------------------------------------------
# Linux x86_64 — stamps must be preserved (the bundled x64 SDK is correct).
# ---------------------------------------------------------------------------

@test "linux x86_64: stamps are preserved" {
  uname() { [ "$1" = "-s" ] && echo Linux || echo x86_64; }
  export -f uname

  invalidate_bundled_stamps_for_non_x64_linux

  stamp_exists "engine-dart-sdk.stamp"
  stamp_exists "flutter_tools.stamp"
}

# ---------------------------------------------------------------------------
# Linux aarch64 — both stamps must be removed (the regression guard).
# ---------------------------------------------------------------------------

@test "linux aarch64: engine-dart-sdk.stamp is removed" {
  uname() { [ "$1" = "-s" ] && echo Linux || echo aarch64; }
  export -f uname

  invalidate_bundled_stamps_for_non_x64_linux

  ! stamp_exists "engine-dart-sdk.stamp"
}

@test "linux aarch64: flutter_tools.stamp is removed" {
  uname() { [ "$1" = "-s" ] && echo Linux || echo aarch64; }
  export -f uname

  invalidate_bundled_stamps_for_non_x64_linux

  ! stamp_exists "flutter_tools.stamp"
}

# ---------------------------------------------------------------------------
# Linux riscv64 — both stamps must be removed (update_dart_sdk.sh maps
# riscv64 -> dart-sdk-linux-riscv64.zip; whether Flutter publishes that
# artifact is a separate concern, but the plugin-side invalidation must fire).
# ---------------------------------------------------------------------------

@test "linux riscv64: both stamps are removed" {
  uname() { [ "$1" = "-s" ] && echo Linux || echo riscv64; }
  export -f uname

  invalidate_bundled_stamps_for_non_x64_linux

  ! stamp_exists "engine-dart-sdk.stamp"
  ! stamp_exists "flutter_tools.stamp"
}

# ---------------------------------------------------------------------------
# macOS — stamps must be preserved regardless of arch. macOS selects the
# correct archive up front via releases_macos.json filtering, so no
# post-extraction stamp invalidation is needed.
# ---------------------------------------------------------------------------

@test "darwin arm64: stamps are preserved" {
  uname() { [ "$1" = "-s" ] && echo Darwin || echo arm64; }
  export -f uname

  invalidate_bundled_stamps_for_non_x64_linux

  stamp_exists "engine-dart-sdk.stamp"
  stamp_exists "flutter_tools.stamp"
}

@test "darwin x86_64: stamps are preserved" {
  uname() { [ "$1" = "-s" ] && echo Darwin || echo x86_64; }
  export -f uname

  invalidate_bundled_stamps_for_non_x64_linux

  stamp_exists "engine-dart-sdk.stamp"
  stamp_exists "flutter_tools.stamp"
}

# ---------------------------------------------------------------------------
# Guard against an unknown architecture slipping through the case statement.
# The default branch (`*`) must remove stamps — anything unrecognised should
# trigger Flutter's self-heal rather than silently keeping the wrong SDK.
# ---------------------------------------------------------------------------

@test "linux unknown arch: stamps are removed" {
  uname() { [ "$1" = "-s" ] && echo Linux || echo mips64; }
  export -f uname

  invalidate_bundled_stamps_for_non_x64_linux

  ! stamp_exists "engine-dart-sdk.stamp"
  ! stamp_exists "flutter_tools.stamp"
}
