#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ROOT="${OUTPUT_ROOT:-${ROOT_DIR}/artifacts}"
OUTPUT_DIR="${OUTPUT_ROOT}/linux-gui-x86_64"
TARGET="x86_64-unknown-linux-gnu"

for command in git pnpm; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "Missing required command: ${command}" >&2
        exit 1
    }
done

cd "${ROOT_DIR}"
pnpm -r install
pnpm -r --workspace-concurrency=1 build
(
    cd easytier-gui
    pnpm tauri build --target "${TARGET}"
)

mkdir -p "${OUTPUT_DIR}"
bundle_dirs=(
    "${ROOT_DIR}/target/${TARGET}/release/bundle"
    "${ROOT_DIR}/easytier-gui/src-tauri/target/${TARGET}/release/bundle"
)
found_bundle=false
for bundle_dir in "${bundle_dirs[@]}"; do
    if [[ -d "${bundle_dir}" ]]; then
        while IFS= read -r -d '' bundle; do
            install -m 0644 "${bundle}" "${OUTPUT_DIR}/"
            found_bundle=true
        done < <(find "${bundle_dir}" -type f \( -name '*.deb' -o -name '*.rpm' -o -name '*.AppImage' \) -print0)
    fi
done

if [[ "${found_bundle}" != true ]]; then
    echo "No Linux GUI bundle was produced." >&2
    exit 1
fi

git rev-parse HEAD > "${OUTPUT_DIR}/SOURCE_COMMIT.txt"
echo "Linux GUI artifacts written to: ${OUTPUT_DIR}"
