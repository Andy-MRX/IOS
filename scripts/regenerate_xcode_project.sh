#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "PulseDeck.xcodeproj regeneration requires macOS with XcodeGen." >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is not installed. Install it first, for example: brew install xcodegen" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"
xcodegen generate --spec project.yml

echo "Regenerated PulseDeck.xcodeproj from project.yml"
