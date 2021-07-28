# asdf-flutter [![Build Status](https://travis-ci.com/oae/asdf-flutter.svg?branch=master)](https://travis-ci.com/oae/asdf-flutter)

[Flutter](https://flutter.dev/) plugin for the [asdf version manager](https://github.com/asdf-vm/asdf). This includes both **flutter** and **dart**.

## Install

```
asdf plugin-add flutter
```

## Configure

If you have problems with accessing to google, you can set the `FLUTTER_STORAGE_BASE_URL` environment variable to change it but structure must be same with Google. Default value is `https://storage.googleapis.com`.

## Troubleshooting

### Bad CPU type in executable

Because this plugin uses [jq](https://github.com/stedolan/jq) you have to enable [Rosetta](https://support.apple.com/en-us/HT211861) to be able to execute non arm optimized software.

Apple will prompt you to install Rosetta if you open a GUI application but not if you're using the terminal. Thus you have to enable Rosetta manually:

```bash
softwareupdate --install-rosetta
```


