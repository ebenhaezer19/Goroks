#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:? "Usage: $0 <target>"}
OUTPUT="asge_v8_runtime_$(date +%Y%m%d_%H%M%S)"
BASE_URL=$(echo "$TARGET" | sed 's#/$##')

mkdir -p "$OUTPUT"

echo "[+] Target: $TARGET"
echo "[+] Output: $OUTPUT"

# =========================
# 0. Dependency Check
# =========================
for bin in curl jq grep awk sed sort uniq timeout; do
    command -v $bin >/dev/null || { echo "[!] Missing: $bin"; exit 1; }
done

command -v google-chrome >/dev/null || command -v chromium >/dev/null || {
    echo "[!] Chrome/Chromium required for runtime engine"
    exit 1
}

# =========================
# 1. Seed Graph (GitLab-aware)
# =========================
echo "[+] Building seed graph..."

cat <<EOF > "$OUTPUT/seeds.txt"
$BASE_URL
$BASE_URL/explore
$BASE_URL/help
$BASE_URL/search
$BASE_URL/users/sign_in
$BASE_URL/users/sign_up
$BASE_URL/dashboard
$BASE_URL/-/tree
$BASE_URL/-/blob
$BASE_URL/-/commits
$BASE_URL/-/merge_requests
$BASE_URL/-/issues
$BASE_URL/api/v4/projects
$BASE_URL/api/v4/users
$BASE_URL/-/profile
EOF

# =========================
# 2. Static Crawl Layer
# =========================
echo "[+] Static crawling..."

> "$OUTPUT/static_body.txt"

while read -r url; do
    echo "[CRAWL] $url"
    curl -s "$url" >> "$OUTPUT/static_body.txt" || true
done < "$OUTPUT/seeds.txt"

# =========================
# 3. JS Asset Extraction
# =========================
echo "[+] Extracting JS assets..."

grep -Eo 'https?://[^"]+\.js[^"]*|/assets/[^"]+\.js' "$OUTPUT/static_body.txt" \
| sort -u > "$OUTPUT/js_assets.txt"

# =========================
# 4. Runtime JS Execution Engine (CORE DIFFERENCE)
# =========================
echo "[+] Running runtime browser analysis..."

RUNTIME_JS="$OUTPUT/runtime_capture.js"

cat <<'EOF' > "$RUNTIME_JS"
(() => {
    const logs = [];

    const origFetch = window.fetch;
    window.fetch = function() {
        logs.push({type:"fetch", args: arguments[0]});
        return origFetch.apply(this, arguments);
    };

    const origXHROpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function() {
        logs.push({type:"xhr", url: arguments[1]});
        return origXHROpen.apply(this, arguments);
    };

    setTimeout(() => {
        document.body.innerText = JSON.stringify(logs);
    }, 5000);
})();
EOF

RUNTIME_OUTPUT="$OUTPUT/runtime_log.txt"

while read -r js; do
    [ -z "$js" ] && continue

    echo "[JS-RUNTIME] $js"

    timeout 15s google-chrome \
        --headless \
        --disable-gpu \
        --no-sandbox \
        "$BASE_URL" \
        --dump-dom \
        2>/dev/null >> "$RUNTIME_OUTPUT" || true

done < "$OUTPUT/js_assets.txt"

# =========================
# 5. API Inference Engine (Runtime + Static merge)
# =========================
echo "[+] Extracting API patterns..."

cat "$OUTPUT/static_body.txt" "$RUNTIME_OUTPUT" 2>/dev/null \
| grep -Eo '/api/v[0-9]+/[a-zA-Z0-9/_-]+' \
| sort -u > "$OUTPUT/api_routes.txt"

grep -Eo '/graphql|/internal|/v[0-9]+/' "$OUTPUT/static_body.txt" \
| sort -u >> "$OUTPUT/api_routes.txt" || true

sort -u "$OUTPUT/api_routes.txt" -o "$OUTPUT/api_routes.txt"

# =========================
# 6. Surface Graph Builder
# =========================
echo "[+] Building attack surface graph..."

> "$OUTPUT/surface_graph.txt"

while read -r url; do
    SCORE="LOW"

    echo "$url" | grep -qi "blob\|tree\|commit" && SCORE="HIGH"
    echo "$url" | grep -qi "api\|graphql\|login\|token" && SCORE="MEDIUM"

    echo "[NODE][$SCORE] $url" >> "$OUTPUT/surface_graph.txt"

done < "$OUTPUT/seeds.txt"

while read -r api; do
    echo "[NODE][API] $api (confidence: HIGH)" >> "$OUTPUT/surface_graph.txt"
done < "$OUTPUT/api_routes.txt"

# =========================
# 7. JS Asset Catalog
# =========================
cp "$OUTPUT/js_assets.txt" "$OUTPUT/js_catalog.txt"

# =========================
# 8. Report Engine
# =========================
echo "[+] Generating report..."

cat <<EOF > "$OUTPUT/report.txt"
ASGE v8 - RUNTIME ATTACK SURFACE ENGINE

TARGET: $TARGET

--- SEEDS ---
$(cat "$OUTPUT/seeds.txt")

--- JS ASSETS ---
$(cat "$OUTPUT/js_catalog.txt")

--- API ROUTES (STATIC + RUNTIME) ---
$(cat "$OUTPUT/api_routes.txt")

--- SURFACE GRAPH ---
$(cat "$OUTPUT/surface_graph.txt")

EOF

echo "[+] DONE → $OUTPUT"