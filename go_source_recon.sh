#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:? "Usage: $0 <target>"}
OUTPUT="recon_$(date +%Y%m%d_%H%M%S)"
WORDLIST="go_wordlist.txt"

mkdir -p "$OUTPUT"

echo "[+] Target: $TARGET"
echo "[+] Output: $OUTPUT"

# =========================
# 0. Dependency Check
# =========================
for bin in curl ffuf jq git grep awk sed; do
    command -v $bin >/dev/null || { echo "[!] $bin not installed"; exit 1; }
done

# =========================
# 1. Fingerprinting
# =========================
echo "[+] Fingerprinting..."

HEADERS=$(curl -s -I "$TARGET" || true)
BODY=$(curl -s "$TARGET" | head -n 80 || true)

echo "$HEADERS" > "$OUTPUT/headers.txt"
echo "$BODY" > "$OUTPUT/body_snippet.txt"

TECH="unknown"

if echo "$HEADERS $BODY" | grep -Eqi "golang|gin|fiber|echo|net/http"; then
    TECH="go"
fi

echo "[+] Tech detected: $TECH"

# =========================
# 2. SEED COLLECTION (NEW)
# =========================
echo "[+] Collecting seed URLs..."

curl -s "$TARGET" | grep -Eo 'href="[^"]+"' | cut -d'"' -f2 > "$OUTPUT/seed_urls.txt" || true

# robots & sitemap
curl -s "$TARGET/robots.txt" > "$OUTPUT/robots.txt" 2>/dev/null || true
curl -s "$TARGET/sitemap.xml" > "$OUTPUT/sitemap.xml" 2>/dev/null || true

# =========================
# 3. JS ROUTE MINER (NEW CRITICAL LAYER)
# =========================
echo "[+] Mining JS endpoints..."

curl -s "$TARGET" | \
grep -Eo '(/api/[a-zA-Z0-9_/\-]+|/v[0-9]/[a-zA-Z0-9_/\-]+|fetch\([^)]+\))' \
> "$OUTPUT/js_routes.txt" || true

# =========================
# 4. URL MERGE ENGINE
# =========================
cat "$OUTPUT/seed_urls.txt" "$OUTPUT/js_routes.txt" 2>/dev/null | sort -u > "$OUTPUT/all_seeds.txt" || true

# fallback if empty
if [ ! -s "$OUTPUT/all_seeds.txt" ]; then
    echo "$TARGET" > "$OUTPUT/all_seeds.txt"
fi

# =========================
# 5. SMART FFUF (SEED-BASED)
# =========================
echo "[+] Running adaptive ffuf..."

> "$OUTPUT/ffuf_results.json"

while read -r url; do
    [ -z "$url" ] && continue

    # normalize
    BASE=$(echo "$url" | sed 's|/$||')

    ffuf -u "$BASE/FUZZ" \
    -w "$WORDLIST" \
    -t 20 \
    -mc 200,204,301,302,307 \
    -fs 0 \
    -ac \
    -o "$OUTPUT/ffuf_$(date +%s%N).json" -of json \
    || true

done < "$OUTPUT/all_seeds.txt"

echo "[+] ffuf completed"

# merge results
cat "$OUTPUT"/ffuf_*.json 2>/dev/null | jq -s 'add' > "$OUTPUT/ffuf.json" 2>/dev/null || true

FOUND=$(jq '.results | length' "$OUTPUT/ffuf.json" 2>/dev/null || echo 0)
echo "[+] Found endpoints: $FOUND"

jq -r '.results[].url' "$OUTPUT/ffuf.json" 2>/dev/null > "$OUTPUT/urls.txt" || true

# =========================
# 6. VALIDATION ENGINE (SAFE VERSION)
# =========================
echo "[+] Validating endpoints..."

> "$OUTPUT/sensitive.txt"

while read -r url; do
    [ -z "$url" ] && continue

    RES=$(curl -s "$url" || true)

    echo "$RES" | grep -Eqi "password|secret|token|apikey" && {
        echo "[HIGH] Sensitive leak → $url"
        echo "$url" >> "$OUTPUT/sensitive.txt"
    }

    echo "$RES" | grep -qi "package main" && {
        echo "[INFO] Go source exposed → $url"
    }

done < "$OUTPUT/urls.txt"

# =========================
# 7. GIT EXPOSURE CHECK (IMPROVED)
# =========================
echo "[+] Checking .git exposure..."

GIT_EXPOSED="NO"

if curl -s "$TARGET/.git/HEAD" | grep -q "ref:"; then
    echo "[HIGH] Git exposed!"
    GIT_EXPOSED="YES"

    mkdir -p "$OUTPUT/git_dump"

    ./gitdumper.sh "$TARGET/.git/" "$OUTPUT/git_dump" || echo "[!] git dump failed"

    if [ -d "$OUTPUT/git_dump/.git" ]; then
        pushd "$OUTPUT/git_dump" > /dev/null

        git checkout . 2>/dev/null || true

        grep -rEi "password|token|secret|key|api" . > ../secrets.txt || true
        grep -rEi "exec\.Command|os/exec|system\(" . > ../rce_candidates.txt || true

        popd > /dev/null
    fi
fi

# =========================
# 8. STATIC RCE SINK DETECTION (FIXED)
# =========================
echo "[+] Static RCE sink detection..."

> "$OUTPUT/rce.txt"

grep -rEi "exec\.Command|os/exec|system\(|popen|Runtime\.exec" . \
2>/dev/null > "$OUTPUT/rce.txt" || true

# =========================
# 9. REPORT GENERATION
# =========================
echo "[+] Generating report..."

cat <<EOF > "$OUTPUT/report.txt"
TARGET: $TARGET
TECH: $TECH

--- FINDINGS ---
Git Exposure: $GIT_EXPOSED

Sensitive Files:
$(cat "$OUTPUT/sensitive.txt" 2>/dev/null)

RCE Sinks (STATIC ONLY):
$(cat "$OUTPUT/rce.txt" 2>/dev/null)

Secrets Sample:
$(head -n 20 "$OUTPUT/secrets.txt" 2>/dev/null)

Endpoints Found:
$FOUND

EOF

echo "[+] Done. Output: $OUTPUT"