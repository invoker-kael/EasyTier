#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ROOT="${OUTPUT_ROOT:-${ROOT_DIR}/artifacts}"
TARGET="x86_64-unknown-linux-musl"
TARGET_DIR="${OUTPUT_ROOT}/cargo-target/linux-amd64"
OUTPUT_DIR="${OUTPUT_ROOT}/linux-amd64"
MUSL_CC="${MUSL_CC:-x86_64-linux-musl-gcc}"
MUSL_INCLUDE_DIR="${MUSL_INCLUDE_DIR:-/usr/include/x86_64-linux-musl}"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

require_command cargo
require_command git
require_command protoc
require_command "${MUSL_CC}"

if [[ ! -f "${MUSL_INCLUDE_DIR}/stddef.h" ]]; then
    echo "Missing musl headers: ${MUSL_INCLUDE_DIR}/stddef.h" >&2
    echo "Install musl-tools and musl-dev, or set MUSL_INCLUDE_DIR." >&2
    exit 1
fi

if ! rustup target list --installed | grep -qx "${TARGET}"; then
    echo "Missing Rust target: ${TARGET}" >&2
    echo "Install it with: rustup target add ${TARGET}" >&2
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"

git_commit="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
git_describe="$(git -C "${ROOT_DIR}" describe --tags --always --dirty)"
package_version="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "${ROOT_DIR}/easytier/Cargo.toml" | head -n 1)"

echo "Building EasyTier ${package_version} (${git_describe}) for Linux amd64..."
CARGO_TARGET_DIR="${TARGET_DIR}" \
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER="${MUSL_CC}" \
    CC_x86_64_unknown_linux_musl="${MUSL_CC}" \
    BINDGEN_EXTRA_CLANG_ARGS_x86_64_unknown_linux_musl="--target=x86_64-linux-musl -I${MUSL_INCLUDE_DIR}" \
    cargo build \
    --manifest-path "${ROOT_DIR}/Cargo.toml" \
    --release \
    --locked \
    --target "${TARGET}" \
    --package easytier \
    --features jemalloc

release_dir="${TARGET_DIR}/${TARGET}/release"
install -m 0755 "${release_dir}/easytier-core" "${OUTPUT_DIR}/easytier-core"
install -m 0755 "${release_dir}/easytier-cli" "${OUTPUT_DIR}/easytier-cli"

printf '%s\n' "${git_commit}" > "${OUTPUT_DIR}/SOURCE_COMMIT.txt"
{
    printf 'package_version=%s\n' "${package_version}"
    printf 'git_describe=%s\n' "${git_describe}"
    printf 'target=%s\n' "${TARGET}"
} > "${OUTPUT_DIR}/VERSION.txt"

echo "Linux artifacts written to: ${OUTPUT_DIR}"
