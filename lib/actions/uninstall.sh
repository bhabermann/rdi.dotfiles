#!/usr/bin/env bash
# Action wrapper for uninstall — called from setup

action_uninstall() {
  "$REPO_ROOT/scripts/uninstall.sh" "$@"
}
