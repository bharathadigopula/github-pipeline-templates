#!/usr/bin/env bash

#==============================================================================
# OCI CLI INSTALLATION
#==============================================================================

set -euo pipefail

: "${OCI_CLI_VERSION:?OCI_CLI_VERSION is required}"
: "${GITHUB_PATH:?GITHUB_PATH is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"

install_directory="$RUNNER_TEMP/oci-cli"
python3 -m venv "$install_directory"
"$install_directory/bin/python" -m pip install --disable-pip-version-check --quiet "oci-cli==$OCI_CLI_VERSION"
printf '%s\n' "$install_directory/bin" >> "$GITHUB_PATH"
"$install_directory/bin/oci" --version