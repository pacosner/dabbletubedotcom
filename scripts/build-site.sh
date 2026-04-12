#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
INDEX_SOURCE="${REPO_ROOT}/index.html"
STYLES_SOURCE="${REPO_ROOT}/styles.css"
FAVICON_SOURCE="${REPO_ROOT}/favicon.svg"

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

styles_hash="$(shasum -a 256 "${STYLES_SOURCE}" | awk '{print substr($1,1,12)}')"
favicon_hash="$(shasum -a 256 "${FAVICON_SOURCE}" | awk '{print substr($1,1,12)}')"
styles_file="styles.${styles_hash}.css"
favicon_file="favicon.${favicon_hash}.svg"

perl -0pe '
  s/>\s+</></g;
  s!\s+(/\s*>)! $1!g;
  s/<script>\s+/<script>/g;
  s/\s+<\/script>/<\/script>/g;
' "${INDEX_SOURCE}" \
  | perl -0pe "s/styles\\.css/${styles_file}/g; s/favicon\\.svg/${favicon_file}/g" \
  > "${DIST_DIR}/index.html"

perl -0pe '
  s@/\*[^*]*\*+(?:[^/*][^*]*\*+)*/@@g;
  s/\s+/ /g;
  s/\s*([{}:;,>])\s*/$1/g;
  s/;}/}/g;
  s/\s*([)])\s*/$1/g;
  s/([({])\s*/$1/g;
  s/\s*!important/!important/g;
' "${STYLES_SOURCE}" > "${DIST_DIR}/${styles_file}"

cp "${REPO_ROOT}/README.md" "${DIST_DIR}/README.md"
cp "${FAVICON_SOURCE}" "${DIST_DIR}/${favicon_file}"

printf 'Built static site into %s\n' "${DIST_DIR}"
