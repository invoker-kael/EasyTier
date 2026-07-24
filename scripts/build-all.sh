#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUSH=false
WINDOWS_ACTION=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --push) PUSH=true ;;
        --windows-action) WINDOWS_ACTION=true ;;
        -h|--help)
            echo "Usage: scripts/build-all.sh [--windows-action] [--push]"
            exit 0
            ;;
        *)
            echo "Usage: scripts/build-all.sh [--windows-action] [--push]" >&2
            exit 2
            ;;
    esac
    shift
done

for command in cargo docker pnpm java sdkmanager; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "Missing required command: ${command}" >&2
        exit 1
    }
done

docker buildx version >/dev/null

SOURCE_SHA="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
"${ROOT_DIR}/scripts/build-linux.sh"
"${ROOT_DIR}/scripts/build-linux-gui.sh"
"${ROOT_DIR}/scripts/build-android.sh"
"${ROOT_DIR}/scripts/build-docker.sh"

if [[ "${WINDOWS_ACTION}" == true ]]; then
    "${ROOT_DIR}/scripts/build-windows-action.sh"
fi

for commit_file in \
    "${ROOT_DIR}/artifacts/linux-amd64/SOURCE_COMMIT.txt" \
    "${ROOT_DIR}/artifacts/linux-gui-x86_64/SOURCE_COMMIT.txt" \
    "${ROOT_DIR}/artifacts/android-apk/SOURCE_COMMIT.txt"; do
    if [[ "$(cat "${commit_file}")" != "${SOURCE_SHA}" ]]; then
        echo "Source commit mismatch: ${commit_file}" >&2
        exit 1
    fi
done

if [[ "${WINDOWS_ACTION}" == true ]]; then
    WINDOWS_ROOT="${ROOT_DIR}/artifacts/github-actions/windows-x86_64/${SOURCE_SHA}"
    windows_commit_count=0
    while IFS= read -r commit_file; do
        windows_commit_count=$((windows_commit_count + 1))
        if [[ "$(cat "${commit_file}")" != "${SOURCE_SHA}" ]]; then
            echo "Source commit mismatch: ${commit_file}" >&2
            exit 1
        fi
    done < <(find "${WINDOWS_ROOT}" -type f -name SOURCE_COMMIT.txt)
    if [[ "${windows_commit_count}" -lt 2 ]]; then
        echo "Downloaded Windows artifacts are incomplete." >&2
        exit 1
    fi
fi

if [[ "${PUSH}" == true ]]; then
    "${ROOT_DIR}/scripts/push-docker.sh"
fi
