#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ROOT="${OUTPUT_ROOT:-${ROOT_DIR}/artifacts}"
OUTPUT_DIR="${OUTPUT_ROOT}/android-apk"
ANDROID_NDK_VERSION="${ANDROID_NDK_VERSION:-26.0.10792818}"

for command in git java pnpm sdkmanager; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "Missing required command: ${command}" >&2
        exit 1
    }
done

if [[ -z "${ANDROID_HOME:-}" || ! -d "${ANDROID_HOME}" ]]; then
    echo "ANDROID_HOME must point to an installed Android SDK." >&2
    exit 1
fi

export NDK_HOME="${NDK_HOME:-${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}}"
if [[ ! -d "${NDK_HOME}" ]]; then
    echo "Android NDK ${ANDROID_NDK_VERSION} is missing at ${NDK_HOME}." >&2
    exit 1
fi

cd "${ROOT_DIR}"
pnpm -r install
pnpm -r --workspace-concurrency=1 build

for arch in aarch64 armv7 i686 x86_64; do
    (
        cd easytier-gui
        pnpm tauri android build --apk --target "${arch}" --split-per-abi
    )
done

mkdir -p "${OUTPUT_DIR}"
found_apk=false
while IFS= read -r -d '' apk; do
    install -m 0644 "${apk}" "${OUTPUT_DIR}/"
    found_apk=true
done < <(find "${ROOT_DIR}/easytier-gui/src-tauri/gen/android/app/build/outputs/apk" -type f -name '*.apk' -print0)

if [[ "${found_apk}" != true ]]; then
    echo "No Android APK was produced." >&2
    exit 1
fi

git rev-parse HEAD > "${OUTPUT_DIR}/SOURCE_COMMIT.txt"
echo "Android APK artifacts written to: ${OUTPUT_DIR}"
