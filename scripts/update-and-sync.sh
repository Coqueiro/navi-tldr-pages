#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/Users/lucas.garcia/Github/navi-tldr-pages"
NAVI="/opt/homebrew/bin/navi"
LOG_FILE="${REPO_DIR}/logs/update-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "${REPO_DIR}/logs"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== navi-tldr-pages update: $(date) ==="

# 1. Pull latest tldr pages
echo "Pulling tldr upstream..."
git -C "${REPO_DIR}/tldr" pull --ff-only

# 2. Translate to .cheat format
echo "Translating pages..."
"${REPO_DIR}/scripts/translate"

# 3. Commit + push if there are changes
if git -C "${REPO_DIR}" diff --quiet && git -C "${REPO_DIR}" diff --cached --quiet; then
  echo "No changes to commit."
else
  echo "Committing and pushing..."
  git -C "${REPO_DIR}" add -A
  git -C "${REPO_DIR}" commit -m "Updates pages (auto $(date +%Y-%m-%d))"
  git -C "${REPO_DIR}" push origin master
fi

# 4. Update local navi cheats (direct copy, avoids navi repo add hanging on auth)
NAVI_CHEATS_DIR="${HOME}/Library/Application Support/navi/cheats/Coqueiro__navi-tldr-pages"
echo "Syncing cheat files to ${NAVI_CHEATS_DIR}..."
mkdir -p "${NAVI_CHEATS_DIR}"
# Clear old files and flatten: pages/common/foo.cheat -> pages__common__foo.cheat
rm -rf "${NAVI_CHEATS_DIR}"
mkdir -p "${NAVI_CHEATS_DIR}"
find "${REPO_DIR}/pages" "${REPO_DIR}/personal_pages" -name '*.cheat' 2>/dev/null | while read -r src; do
  rel="${src#"${REPO_DIR}/"}"
  flat="$(echo "$rel" | sed 's|/|__|g')"
  cp "$src" "${NAVI_CHEATS_DIR}/${flat}"
done
echo "Synced $(ls "${NAVI_CHEATS_DIR}" | wc -l | tr -d ' ') cheat files."

# 5. Prune old logs (keep last 12)
ls -t "${REPO_DIR}/logs"/update-*.log 2>/dev/null | tail -n +13 | xargs rm -f 2>/dev/null || true

echo "=== Done: $(date) ==="
