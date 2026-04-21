#!/bin/bash
# Go Web App Source Code Recon Toolkit v1.0
# Usage: ./go_source_recon.sh http://target.com

TARGET=${1:? "Usage: $0 <target>"}
OUTPUT="go_recon_$(date +%Y%m%d_%H%M%S)"
mkdir -p $OUTPUT

echo "[+] Starting Go Source Recon on $TARGET"
echo "[+] Output: $OUTPUT/"

# 1. Backup & Go file enumeration
echo "[+] Hunting Go backups & source files..."
cat << EOBACKUPS | while read ext; do
main.go handlers.go app.go server.go routes.go cmd.go
main.go~ main.go.bak main.go.old main.go.swp
handlers.go~ app.go.bak server.go.old
