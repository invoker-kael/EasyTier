#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

for command in gh git; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "Missing required command: ${command}" >&2
        exit 1
    }
done

if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Run: gh auth login" >&2
    exit 1
fi

SOURCE_SHA="$(git rev-parse HEAD)"
DEFAULT_BRANCH="${GITHUB_DEFAULT_BRANCH:-$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')}"
REPOSITORY="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RUN_TITLE="Windows x64 ${SOURCE_SHA}"

gh workflow run build-windows-x64.yml \
    --repo "${REPOSITORY}" \
    --ref "${DEFAULT_BRANCH}" \
    -f source_ref="${SOURCE_SHA}"

RUN_ID=""
for _ in $(seq 1 30); do
    RUN_ID="$(gh run list \
        --repo "${REPOSITORY}" \
        --workflow build-windows-x64.yml \
        --event workflow_dispatch \
        --created ">=${START_TIME}" \
        --json databaseId,displayTitle \
        --jq ".[] | select(.displayTitle == \\\"${RUN_TITLE}\\\") | .databaseId" \
        --limit 100 | head -n 1)"
    [[ -n "${RUN_ID}" ]] && break
    sleep 2
done

if [[ -z "${RUN_ID}" ]]; then
    echo "Could not identify the workflow run for source commit ${SOURCE_SHA}." >&2
    exit 1
fi

gh run watch "${RUN_ID}" --repo "${REPOSITORY}" --exit-status

OUTPUT_DIR="${ROOT_DIR}/artifacts/github-actions/windows-x86_64/${SOURCE_SHA}"
mkdir -p "${OUTPUT_DIR}"
gh run download "${RUN_ID}" --repo "${REPOSITORY}" --dir "${OUTPUT_DIR}"

CORE_DIR="$(find "${OUTPUT_DIR}" -type f -name easytier-core.exe -printf '%h\n' | head -n 1)"
CLI_DIR="$(find "${OUTPUT_DIR}" -type f -name easytier-cli.exe -printf '%h\n' | head -n 1)"
GUI_DIR="$(find "${OUTPUT_DIR}" -type f -name '*.exe' ! -name easytier-core.exe ! -name easytier-cli.exe -printf '%h\n' | head -n 1)"

if [[ -z "${CORE_DIR}" || -z "${CLI_DIR}" || -z "${GUI_DIR}" || "${CORE_DIR}" != "${CLI_DIR}" ]]; then
    echo "Downloaded artifacts are incomplete." >&2
    exit 1
fi

for output_dir in "${CORE_DIR}" "${GUI_DIR}"; do
    test "$(cat "${output_dir}/SOURCE_COMMIT.txt")" = "${SOURCE_SHA}"
    test -s "${output_dir}/SHA256SUMS.txt"
    (cd "${output_dir}" && sha256sum --check SHA256SUMS.txt)
done

echo "Windows artifacts downloaded to: ${OUTPUT_DIR}"
