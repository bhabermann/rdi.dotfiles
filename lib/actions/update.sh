#!/usr/bin/env bash
# Action wrapper for update — called from setup

action_update() {
  "$REPO_ROOT/scripts/update.sh" "$@"
}
