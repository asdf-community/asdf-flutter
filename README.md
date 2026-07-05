# asdf-flutter [![Build Status](https://travis-ci.com/oae/asdf-flutter.svg?branch=master)](https://travis-ci.com/oae/asdf-flutter)

[Flutter](https://flutter.dev/) plugin for the [asdf version manager](https://github.com/asdf-vm/asdf). This includes both **flutter** and **dart**.

## Dependencies

- [jq](https://jqlang.github.io/jq/download/)

## Install

```
asdf plugin add flutter
```

## Configure

If you have problems with accessing to google, you can set the `FLUTTER_STORAGE_BASE_URL` environment variable to change it but structure must be same with Google. Default value is `https://storage.googleapis.com`.

## FVM support

[FVM](https://fvm.app/) is one of major version manager for Flutter.

asdf uses a `.tool-versions` file for auto-switching between software versions. To ease migration, you can have it read an existing `.fvm/fvm_config.json` or `.fvmrc` file to find out what version of Flutter should be used. To do this, add the following to `$HOME/.asdfrc`:

```
legacy_version_file = yes
```

## Troubleshooting

### VSCode
<img width="668" alt="image" src="https://user-images.githubusercontent.com/877327/158042623-290554da-0b9d-4fe0-b91b-c85b9c48e2d1.png">

To fix the "Could not find a Flutter SDK" error, you can set the `FLUTTER_ROOT` environment variable in your `.bashrc` or `.zshrc` file:
```bash
export FLUTTER_ROOT="$(asdf where flutter)"
```

### Bad CPU type in executable

Because this plugin uses [jq](https://github.com/stedolan/jq) you have to enable [Rosetta](https://support.apple.com/en-us/HT211861) to be able to execute non arm optimized software.

Apple will prompt you to install Rosetta if you open a GUI application but not if you're using the terminal. Thus you have to enable Rosetta manually:

```bash
softwareupdate --install-rosetta
```

### `cannot execute binary file: Exec format error` on Linux ARM64

The official Linux release tarball ships with an **x86-64** `dart-sdk` bundled
under `bin/cache/dart-sdk/`, regardless of host architecture. On an `aarch64`
(or `riscv64`) host this binary cannot run, and the first `flutter` invocation
fails with:

```
.../bin/internal/shared.sh: line 273:
.../bin/cache/dart-sdk/bin/dart: cannot execute binary file: Exec format error
```

Note that this error surfaces from Flutter's own bootstrap script, not from the
plugin's `install` step — the install itself reports success. Flutter ships two
stamp files (`engine-dart-sdk.stamp` and `flutter_tools.stamp`) that match on
first run, which causes Flutter's self-heal (`update_dart_sdk.sh`, the script
that would normally detect the host architecture and fetch a matching
dart-sdk) to be skipped entirely.

The plugin now works around this by deleting both stamps after extraction on
non-x86_64 Linux hosts, so that `update_dart_sdk.sh` runs on first invocation
and fetches the correct dart-sdk (e.g. `dart-sdk-linux-arm64.zip`). The first
`flutter` command will incur a one-time download (~220 MB) to replace the
bundled dart-sdk.

See [ADR001: Linux ARM64 Support](./docs/adr/adr001-linux-arm64-support.md)
for the full diagnosis and rationale.

