#!/usr/bin/env bash
# Action wrapper for install — called from setup

action_install() {
  "$REPO_ROOT/scripts/install.sh" "$@"
}
