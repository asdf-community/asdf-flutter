#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

function get_operatingsystem() {
  local kernel_name
  kernel_name="$(uname -s)"
  case "${kernel_name}" in
    Linux)
      echo -n 'linux'
      ;;
    Darwin)
      echo -n 'macos'
      ;;
    *)
      echo "Sorry, ${kernel_name} is not supported." >&2
      exit 1
      ;;
  esac
}

OS="$(get_operatingsystem)"

if [ -z "${FLUTTER_STORAGE_BASE_URL:-}" ]; then
  FLUTTER_STORAGE_BASE_URL='https://storage.googleapis.com'
fi
