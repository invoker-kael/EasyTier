#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ROOT="${OUTPUT_ROOT:-${ROOT_DIR}/artifacts}"
OUTPUT_DIR="${OUTPUT_ROOT}/android-apk"
ANDROID_NDK_VERSION="${ANDROID_NDK_VERSION:-26.0.10792818}"
ANDROID_API="${ANDROID_API:-34}"
BUILD_JOBS="${BUILD_JOBS:-12}"

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

TOOLCHAIN_BIN="${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin"
SYSROOT="${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
if [[ ! -d "${TOOLCHAIN_BIN}" || ! -d "${SYSROOT}" ]]; then
    echo "Android NDK toolchain is incomplete under ${NDK_HOME}." >&2
    exit 1
fi

export PATH="${TOOLCHAIN_BIN}:${PATH}"
export CARGO_BUILD_JOBS="${BUILD_JOBS}"
export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.parallel=true -Dorg.gradle.workers.max=${BUILD_JOBS}"

cd "${ROOT_DIR}"
pnpm -r install
pnpm -r --workspace-concurrency=1 build

for arch in aarch64 armv7 i686 x86_64; do
    case "${arch}" in
        aarch64) target="aarch64-linux-android"; clang="aarch64-linux-android${ANDROID_API}-clang" ;;
        armv7) target="armv7-linux-androideabi"; clang="armv7a-linux-androideabi${ANDROID_API}-clang" ;;
        i686) target="i686-linux-android"; clang="i686-linux-android${ANDROID_API}-clang" ;;
        x86_64) target="x86_64-linux-android"; clang="x86_64-linux-android${ANDROID_API}-clang" ;;
    esac
    target_env="${target^^}"
    target_env="${target_env//-/_}"
    (
        cd easytier-gui
        env \
            "BINDGEN_EXTRA_CLANG_ARGS=--target=${target} --sysroot=${SYSROOT}" \
            "CC_${target//-/_}=${clang}" \
            "CARGO_TARGET_${target_env}_LINKER=${clang}" \
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
