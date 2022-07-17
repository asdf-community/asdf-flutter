# asdf-flutter [![Build Status](https://travis-ci.com/oae/asdf-flutter.svg?branch=master)](https://travis-ci.com/oae/asdf-flutter)

[Flutter](https://flutter.dev/) plugin for the [asdf version manager](https://github.com/asdf-vm/asdf). This includes both **flutter** and **dart**.

## Install

```
asdf plugin-add flutter
```

## Prerequisites

* [jq](https://github.com/stedolan/jq)


## Configure

If you have problems with accessing to google, you can set the `FLUTTER_STORAGE_BASE_URL` environment variable to change it but structure must be same with Google. Default value is `https://storage.googleapis.com`.


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


