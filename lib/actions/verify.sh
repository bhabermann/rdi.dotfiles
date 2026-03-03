#!/usr/bin/env bash
# Action wrapper for verify — called from setup

action_verify() {
  "$REPO_ROOT/scripts/verify.sh" "$@"
}
