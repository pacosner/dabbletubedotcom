#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"

mkdir -p "${DIST_DIR}"

perl -0pe '
  s/>\s+</></g;
  s!\s+(/\s*>)! $1!g;
  s/<script>\s+/<script>/g;
  s/\s+<\/script>/<\/script>/g;
' "${REPO_ROOT}/index.html" > "${DIST_DIR}/index.html"

perl -0pe '
  s@/\*[^*]*\*+(?:[^/*][^*]*\*+)*/@@g;
  s/\s+/ /g;
  s/\s*([{}:;,>])\s*/$1/g;
  s/;}/}/g;
  s/\s*([)])\s*/$1/g;
  s/([({])\s*/$1/g;
  s/\s*!important/!important/g;
' "${REPO_ROOT}/styles.css" > "${DIST_DIR}/styles.css"

cp "${REPO_ROOT}/README.md" "${DIST_DIR}/README.md"
cp "${REPO_ROOT}/favicon.svg" "${DIST_DIR}/favicon.svg"

printf 'Built static site into %s\n' "${DIST_DIR}"
