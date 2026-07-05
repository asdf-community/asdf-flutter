---
id: adrs-adr001
title: "ADR001: Linux ARM64 Support"
# prettier-ignore
description: Architecture Decision Record (ADR) for Linux ARM64 support, fixing an exec format error on aarch64 hosts caused by the bundled x64 dart-sdk
---

## Context

Flutter publishes a single Linux release tarball per version/channel. That tarball
bundles an **x86-64 dart-sdk** under `bin/cache/dart-sdk/` along with two stamp files
that record the engine revision the SDK was built against:

- `bin/cache/engine-dart-sdk.stamp` — records the engine hash for the dart-sdk
- `bin/cache/flutter_tools.stamp` — records the compile key for the flutter_tools
  snapshot (revision + tool args)

Flutter's bootstrap flow (`bin/internal/shared.sh`) computes a `compilekey` from the
current git revision and compares it against `flutter_tools.stamp`. Only when the
stamp is missing, empty, or mismatched does `upgrade_flutter()` invoke
`bin/internal/update_dart_sdk.sh`, which:

1. Reads the engine hash from `bin/cache/engine.stamp` (and `bin/cache/engine.realm`,
   used to construct the download URL).
2. Compares it against `engine-dart-sdk.stamp`; if they differ (or the stamp is
   absent) it re-downloads the dart-sdk.
3. Detects the host architecture via `uname -m`, mapping:
   - `x86_64` → `x64`
   - `riscv64` → `riscv64`
   - anything else (including `aarch64`) → `arm64`
4. Fetches the matching `dart-sdk-linux-<arch>.zip` from the Flutter engine
   bucket and replaces `bin/cache/dart-sdk/`.

On a Linux aarch64 host, the asdf-flutter plugin (before this change) extracted
the official Linux tarball verbatim. Because both shipped stamps matched on
first run, `update_dart_sdk.sh` was never invoked, and the bundled x86-64
`dart` binary remained in place. The first `flutter` invocation then failed:

```
/home/.../bin/internal/shared.sh: line 273:
/home/.../bin/cache/dart-sdk/bin/dart: cannot execute binary file: Exec format error
```

The user-visible symptom — "Exec format error" originating from `shared.sh`
rather than from the plugin's `install` script — made the failure mode
difficult to diagnose: the install itself reported success, and the error only
surfaced on first run, pointing at Flutter internals rather than at the
architecture mismatch.

This was investigated and verified on:

- Host: `aarch64` Linux (kernel reports `aarch64` via `uname -m`)
- Version: `3.44.4-stable`
- Bundled dart binary: `ELF 64-bit LSB pie executable, x86-64` (confirmed via
  `file` on `bin/cache/dart-sdk/bin/dart`)
- Engine bucket: `dart-sdk-linux-arm64.zip` for the same engine hash returns
  HTTP 200, i.e. Flutter does publish an arm64 dart-sdk — it just isn't shipped
  inside the Linux tarball.
  (`dart-sdk-linux-riscv64.zip` returns 404 for the same engine hash, so
  Flutter does not currently publish a riscv64 dart-sdk despite the script
  mapping `riscv64` → that filename.)

Note that macOS is unaffected because the asdf-flutter `install` script already
filters `releases_macos.json` by `dart_sdk_arch` (`arm64` on Apple Silicon,
`x64` otherwise). `releases_linux.json` exposes no `dart_sdk_arch` field at all
— every entry has `dart_sdk_arch == "x64"` and the archive filename carries no
architecture suffix — so the same filtering approach cannot be reused for
Linux. (Verified against `releases_linux.json`: all 719 entries across all
channels have `dart_sdk_arch == "x64"` and no arch suffix in `archive`.)

## Decision

We will **not** attempt to pick an architecture-specific Linux archive (none
exists). Instead, after extracting the official Linux tarball, on any non-x86_64
host we will delete both `bin/cache/engine-dart-sdk.stamp` and
`bin/cache/flutter_tools.stamp` so that Flutter's own self-heal runs on first
invocation and replaces the bundled dart-sdk with one matching the host
architecture.

Concretely, a helper function `invalidate_bundled_stamps_for_non_x64_linux`
is added to `bin/install` and called at the end of the `install` function:

```bash
invalidate_bundled_stamps_for_non_x64_linux() {
  if [ "$(uname -s)" == "Linux" ]; then
    case "$(uname -m)" in
      x86_64) ;;
      *)
        rm -f "${ASDF_INSTALL_PATH}/bin/cache/engine-dart-sdk.stamp"
        rm -f "${ASDF_INSTALL_PATH}/bin/cache/flutter_tools.stamp"
        ;;
    esac
  fi
}
```

It is extracted into its own function so it can be unit-tested in isolation
(see `test/install.bats`) without performing a full 1.4 GB download.

Both stamps are removed (rather than only `engine-dart-sdk.stamp`) because
`update_dart_sdk.sh` is only reachable inside the `upgrade_flutter()` branch
that fires when `flutter_tools.stamp` is invalid. Removing only
`engine-dart-sdk.stamp` leaves the bootstrap short-circuit intact and the
x86-64 binary in place — verified during diagnosis.

This approach deliberately delegates architecture detection to Flutter's
`update_dart_sdk.sh`, which already handles `aarch64` and `riscv64` correctly,
rather than duplicating that logic in the plugin.

## Consequences

Positive:

- Linux aarch64 hosts now run `flutter` and `dart` natively on first invocation.
  Verified end-to-end: `flutter --version` reports
  `Flutter 3.44.4 • channel stable` and `dart --version` reports
  `Dart SDK version: 3.12.2 (stable) (...) on "linux_arm64"` (the
  `on "linux_arm64"` suffix confirms the native arm64 SDK is in use); the
  bundled `dart` binary is replaced with an `ELF 64-bit ... ARM aarch64`
  executable.
- Linux riscv64 hosts would benefit from the same fix if Flutter publishes a
  `dart-sdk-linux-riscv64.zip` for the engine version in use —
  `update_dart_sdk.sh` already maps `riscv64` → that filename. As of engine
  `a10d8ac38d` (3.44.4-stable) that zip returns 404, so riscv64 support is
  aspirational and depends on Flutter publishing the artifact.
- The plugin keeps using a single archive per Linux version — no need to parse a
  non-existent `dart_sdk_arch` field on Linux or special-case channels.
- Architecture detection lives in exactly one place (Flutter's own script), so
  future architectures Flutter adds support for are picked up automatically.

Negative:

- The first `flutter` invocation on a non-x86_64 Linux host incurs an extra
  download (~220 MB for `dart-sdk-linux-arm64.zip`) plus a flutter_tools
  rebuild before any command can run. This is a one-time cost per install but
  is noticeable.
- The fix depends on Flutter's internal stamp protocol staying as described.
  If a future Flutter release changes how `flutter_tools.stamp` is computed or
  stops gating `update_dart_sdk.sh` behind it, this workaround may silently
  regress back to shipping an x86-64 binary on arm64 hosts. The failure mode
  would be the original "Exec format error" again.
- Deleting `flutter_tools.stamp` also forces a rebuild of `flutter_tools.snapshot`
  from source on first run. This is unavoidable: the shipped snapshot was built
  for the x86-64 dart VM and cannot be reused once the dart-sdk is replaced
  with the arm64 one.
