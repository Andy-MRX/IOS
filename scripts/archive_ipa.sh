#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/archive_ipa.sh \
    --development-team TEAMID \
    --bundle-id com.yourcompany.PulseDeck \
    --export-options export/ExportOptions-AppStore.plist

Optional:
  --archive-path build/PulseDeck.xcarchive
  --export-path build/export

Notes:
  - Must be run on macOS with Xcode installed
  - Expects a valid signing setup
  - Does not bypass provisioning or code signing requirements
EOF
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "IPA archive/export must run on macOS with Xcode." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is not available. Install Xcode command line tools first." >&2
  exit 1
fi

DEVELOPMENT_TEAM=""
BUNDLE_ID=""
EXPORT_OPTIONS=""
ARCHIVE_PATH="build/PulseDeck.xcarchive"
EXPORT_PATH="build/export"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --development-team)
      DEVELOPMENT_TEAM="$2"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    --export-options)
      EXPORT_OPTIONS="$2"
      shift 2
      ;;
    --archive-path)
      ARCHIVE_PATH="$2"
      shift 2
      ;;
    --export-path)
      EXPORT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${DEVELOPMENT_TEAM}" || -z "${BUNDLE_ID}" || -z "${EXPORT_OPTIONS}" ]]; then
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"
mkdir -p "$(dirname "${ARCHIVE_PATH}")" "${EXPORT_PATH}"

xcodebuild \
  -project PulseDeck.xcodeproj \
  -scheme PulseDeck \
  -configuration Release \
  -destination generic/platform=iOS \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
  PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}" \
  clean archive \
  -archivePath "${ARCHIVE_PATH}"

xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}"

echo "Archive created at ${ARCHIVE_PATH}"
echo "Export output written to ${EXPORT_PATH}"
