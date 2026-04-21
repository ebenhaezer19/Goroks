<img width="1275" height="585" alt="image" src="https://github.com/user-attachments/assets/515d0ab9-ab53-4254-b2d1-5565c48ffc3c" />


# Goroks 

Automated reconnaissance and exploitation pipeline for discovering exposed **Go application source code**, **backup files**, and **misconfigured Git repositories**.

---

## 📌 Overview

This toolkit is designed to streamline **web reconnaissance** specifically targeting:

* Exposed `.go` source files
* Backup artifacts (`.bak`, `.old`, `.swp`, etc.)
* Misconfigured `.git` directories
* Sensitive information leakage
* Potential RCE indicators

It integrates multiple phases into a **single automated pipeline**, reducing manual effort during initial pentesting.

---

## ⚙️ Features

### 1. Fingerprinting

* Detects Go-based applications using:

  * HTTP headers
  * Response body heuristics (Gin, Echo, Fiber)
  * `/debug/pprof` endpoint

### 2. Surface Discovery (FFUF)

* Fuzzing endpoints using custom Go-focused wordlist
* Supports:

  * Redirect following
  * Auto-calibration
  * Status-based filtering

### 3. Sensitive File Detection

* Identifies exposed:

  * `.env`
  * `.go`
  * config files
* Searches for:

  * `password`
  * `token`
  * `secret`
  * `key`

### 4. Git Exposure Exploitation

* Detects `.git` exposure
* Dumps repository using `GitTools`
* Reconstructs working directory
* Extracts:

  * Secrets
  * Credentials
  * API keys

### 5. Static Code Analysis

* Searches for dangerous patterns:

  * `exec`
  * `system`
  * `popen`
  * `subprocess`

### 6. Basic RCE Detection

* Reflection-based testing
* Time-based detection (`sleep` payload)

---

## 🛠️ Requirements

Install dependencies:

```bash
Make on root node and path ex: /root/go-pentest/Goroks
apt update
apt install -y curl jq git ffuf
```

Clone GitTools:

```bash
git clone https://github.com/internetwache/GitTools.git
```

---

## 🚀 Usage

```bash
chmod +x go_source_recon.sh
./go_source_recon.sh http://target.com
```

---

## 📂 Output Structure

```
recon_YYYYMMDD_HHMMSS/
├── headers.txt
├── ffuf.json
├── urls.txt
├── sensitive.txt
├── rce.txt
├── secrets.txt
├── rce_candidates.txt
├── report.txt
└── git_dump/
    └── .git/
```

---

## 📊 Example Output

```
[HIGH] Git exposed!
[LOW] Reflection via cmd
[LOW] Reflection via exec
```

---

## 🔍 Example Findings

| Type           | Severity | Description                |
| -------------- | -------- | -------------------------- |
| `.git exposed` | HIGH     | Full source code leakage   |
| `.env exposed` | HIGH     | Credentials disclosure     |
| Reflection     | LOW      | Input reflected (not RCE)  |
| Time-based RCE | CRITICAL | Possible command execution |

---

## ⚠️ Important Notes

* Tool ini **tidak menjamin RCE**, hanya mendeteksi indikasi awal
* Banyak false positive pada:

  * Reflection
  * Static responses
* Validasi manual tetap wajib

---

## 🔐 Legal Disclaimer

This tool is intended for:

* Authorized penetration testing
* Security research
* Educational purposes

**Do not use against systems without explicit permission.**

---

## 🧠 Next Improvements (Roadmap)

* Integrasi dengan:

  * `nuclei`
  * `httpx`
  * `katana`
* Advanced Go binary analysis
* Endpoint crawling (JS parsing)
* Parameter fuzzing

---

## 👨‍💻 Author

Developed for advanced **web application reconnaissance & exploitation workflows**.

---

## ⭐ Contribution

Pull requests are welcome. For major changes, open an issue first.

---

## 📜 License

MIT License

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
