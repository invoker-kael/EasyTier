#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ROOT="${OUTPUT_ROOT:-${ROOT_DIR}/artifacts}"
LINUX_DIR="${OUTPUT_ROOT}/linux-amd64"
CONTEXT_DIR="${OUTPUT_ROOT}/docker-context"
DOCKERFILE="${ROOT_DIR}/.github/workflows/Dockerfile"
command -v docker >/dev/null 2>&1 || {
    echo "Missing required command: docker" >&2
    exit 1
}

if [[ ! -x "${LINUX_DIR}/easytier-core" || ! -x "${LINUX_DIR}/easytier-cli" ]]; then
    echo "Linux artifacts are missing. Run scripts/build-linux.sh first." >&2
    exit 1
fi

if [[ -z "${DOCKER_USERNAME:-}" ]]; then
    echo "DOCKER_USERNAME is required, for example: DOCKER_USERNAME=your-user" >&2
    exit 1
fi

if [[ ! -f "${DOCKERFILE}" ]]; then
    echo "Dockerfile not found: ${DOCKERFILE}" >&2
    exit 1
fi

commit_tag="$(git -C "${ROOT_DIR}" rev-parse --short HEAD)"
DOCKER_REPOSITORY="${DOCKER_REPOSITORY:-easytier-custom}"
image_name="${DOCKER_USERNAME}/${DOCKER_REPOSITORY}"

mkdir -p "${CONTEXT_DIR}/easytier-linux-x86_64"
install -m 0755 "${LINUX_DIR}/easytier-core" "${CONTEXT_DIR}/easytier-linux-x86_64/easytier-core"
install -m 0755 "${LINUX_DIR}/easytier-cli" "${CONTEXT_DIR}/easytier-linux-x86_64/easytier-cli"

build_args=(
    buildx build
    --platform linux/amd64
    --file "${DOCKERFILE}"
    --tag "${image_name}:${commit_tag}"
    --tag "${image_name}:latest"
    --label "org.opencontainers.image.source=$(git -C "${ROOT_DIR}" config --get remote.origin.url)"
    --label "org.opencontainers.image.revision=$(cat "${LINUX_DIR}/SOURCE_COMMIT.txt")"
)

build_args+=(--load)
build_args+=("${CONTEXT_DIR}")
docker "${build_args[@]}"
echo "Built and loaded Docker images: ${image_name}:${commit_tag}, ${image_name}:latest"
