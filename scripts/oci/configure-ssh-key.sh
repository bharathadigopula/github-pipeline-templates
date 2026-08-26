#!/usr/bin/env bash

#==============================================================================
# HOST SSH KEY CONFIGURATION
#==============================================================================

set -euo pipefail

: "${SSH_PRIVATE_KEY:?SSH_PRIVATE_KEY is required}"

install -d -m 700 "$HOME/.ssh"
printf '%s\n' "$SSH_PRIVATE_KEY" > "$HOME/.ssh/host_key"
chmod 600 "$HOME/.ssh/host_key"
ssh-keygen -y -f "$HOME/.ssh/host_key" >/dev/null