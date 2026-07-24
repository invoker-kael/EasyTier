#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ROOT="${OUTPUT_ROOT:-${ROOT_DIR}/artifacts}"
TARGET="x86_64-pc-windows-gnu"
TARGET_DIR="${OUTPUT_ROOT}/cargo-target/windows-x64"
OUTPUT_DIR="${OUTPUT_ROOT}/windows-x86_64"
MINGW_LINKER="${MINGW_LINKER:-x86_64-w64-mingw32-gcc}"
PACKET_IMPORT_LIBRARY="${ROOT_DIR}/easytier/third_party/x86_64/Packet.lib"
PACKET_LIBRARY_DIR="${TARGET_DIR}/third-party-libs"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

require_command cargo
require_command git
require_command protoc
require_command "${MINGW_LINKER}"

MINGW_GCC_INCLUDE_DIR="${MINGW_GCC_INCLUDE_DIR:-$(${MINGW_LINKER} -print-file-name=include)}"
if [[ ! -f "${MINGW_GCC_INCLUDE_DIR}/mm_malloc.h" ]]; then
    echo "Missing MinGW GCC headers: ${MINGW_GCC_INCLUDE_DIR}/mm_malloc.h" >&2
    echo "Install mingw-w64, or set MINGW_GCC_INCLUDE_DIR." >&2
    exit 1
fi

if [[ ! -f "${PACKET_IMPORT_LIBRARY}" ]]; then
    echo "Missing Packet import library: ${PACKET_IMPORT_LIBRARY}" >&2
    exit 1
fi

if ! rustup target list --installed | grep -qx "${TARGET}"; then
    echo "Missing Rust target: ${TARGET}" >&2
    echo "Install it with: rustup target add ${TARGET}" >&2
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
mkdir -p "${PACKET_LIBRARY_DIR}"
# MinGW resolves -lPacket as libPacket.a; Packet.lib itself is a compatible
# import archive, so stage it under the GNU linker naming convention.
install -m 0644 "${PACKET_IMPORT_LIBRARY}" "${PACKET_LIBRARY_DIR}/libPacket.a"

git_commit="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
git_describe="$(git -C "${ROOT_DIR}" describe --tags --always --dirty)"
package_version="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "${ROOT_DIR}/easytier/Cargo.toml" | head -n 1)"

echo "Building EasyTier ${package_version} (${git_describe}) for Windows x64..."
CARGO_TARGET_DIR="${TARGET_DIR}" \
    CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="${MINGW_LINKER}" \
    CC_x86_64_pc_windows_gnu="${MINGW_LINKER}" \
    BINDGEN_EXTRA_CLANG_ARGS_x86_64_pc_windows_gnu="--target=x86_64-w64-windows-gnu -I${MINGW_GCC_INCLUDE_DIR} -I/usr/x86_64-w64-mingw32/include" \
    RUSTFLAGS="${RUSTFLAGS:-} -Lnative=${PACKET_LIBRARY_DIR}" \
    cargo build \
        --manifest-path "${ROOT_DIR}/Cargo.toml" \
        --release \
        --locked \
        --target "${TARGET}" \
        --package easytier \
        --features mimalloc

release_dir="${TARGET_DIR}/${TARGET}/release"
install -m 0755 "${release_dir}/easytier-core.exe" "${OUTPUT_DIR}/easytier-core.exe"
install -m 0755 "${release_dir}/easytier-cli.exe" "${OUTPUT_DIR}/easytier-cli.exe"

find "${ROOT_DIR}/easytier/third_party/x86_64" \
    -maxdepth 1 \
    -type f \
    \( -name '*.dll' -o -name '*.sys' \) \
    -exec install -m 0644 {} "${OUTPUT_DIR}/" \;

printf '%s\n' "${git_commit}" > "${OUTPUT_DIR}/SOURCE_COMMIT.txt"
{
    printf 'package_version=%s\n' "${package_version}"
    printf 'git_describe=%s\n' "${git_describe}"
    printf 'target=%s\n' "${TARGET}"
} > "${OUTPUT_DIR}/VERSION.txt"

echo "Windows artifacts written to: ${OUTPUT_DIR}"
