#!/usr/bin/env bash
set -euo pipefail

echo "=== Test Cycle 1: Initial Setup ==="
./setup install || { echo "FAILED: Initial setup"; exit 1; }

echo ""
echo "=== Test Cycle 2: Uninstall All ==="
echo -e "all\ny" | ./scripts/uninstall.sh || { echo "FAILED: Uninstall"; exit 1; }

echo ""
echo "=== Test Cycle 3: Re-install After Uninstall ==="
./setup install || { echo "FAILED: Re-install after uninstall"; exit 1; }

echo ""
echo "=== Test Cycle 4: Idempotent Install ==="
./setup install || { echo "FAILED: Idempotent install"; exit 1; }

echo ""
echo "=== All Test Cycles Passed! ==="
