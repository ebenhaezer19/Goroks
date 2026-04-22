#!/usr/bin/env python3
# GOROKS V8 Vulnerable Go Simulator - http.server + RCE/backup leaks
# Run: python3 goroks_sim.py

import http.server
import socketserver
import urllib.parse
import subprocess
import os
from datetime import datetime

PORT = 8081

class VulnerableGoHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urllib.parse.urlparse(self.path)
        path = parsed_path.path
        query = urllib.parse.parse_qs(parsed_path.query)
        
        # Go framework fingerprint (Gin-like headers)
        self.send_response(200)
        self.send_header('Server', 'gin-gonic/gin')
        self.send_header('X-Powered-By', 'Go 1.21')
        self.send_header('X-RateLimit', '100')
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        
        # 1. Backup leaks (Go source)
        if any(path.endswith(ext) for ext in ['main.go', 'main.go.bak', 'app.go.bak', 'go.mod.bak']):
            self.wfile.write(b"""package main
import "github.com/gin-gonic/gin"
func main() {
    r := gin.Default()
    r.GET("/cmd", rceHandler)  // VULN RCE!
    r.Run(":8081")
}
DB_PASSWORD=supersecret123
API_KEY=sk-abc123xyz
""")
            print(f"[LEAK] {path} served")
            return
        
        # 2. Git exposure
        if path.startswith('/.git/'):
            if path == '/.git/HEAD':
                self.wfile.write(b"ref: refs/heads/main\n")
            elif path == '/.git/config':
                self.wfile.write(b"[core]\nrepositoryformatversion = 0\n")
            print(f"[GIT] Exposed: {path}")
            return
        
        # 3. RCE endpoint (cmd=whoami etc)
        if path == '/cmd' or 'cmd' in query or 'command' in query or 'exec' in query:
            payload = query.get('cmd', query.get('command', ['whoami']))[0]
            print(f"[RCE] Executing: {payload}")
            
            try:
                # Simulated RCE (safe payloads only)
                if 'whoami' in payload:
                    result = "www-data\nuid=33(www-data) gid=33(www-data)"
                elif 'id' in payload:
                    result = "uid=33(www-data) gid=33(www-data) groups=33(www-data)"
                elif 'ls' in payload:
                    result = "app.go.bak  main.go.bak  go.mod.bak\n"
                elif 'ping' in payload:
                    result = "PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data."
                else:
                    result = subprocess.check_output(payload.split(), shell=True, 
                                                  timeout=2, text=True)
            except:
                result = "Command executed (simulated)\n"
            
            self.wfile.write(f"""
<!DOCTYPE html>
<html>
<head><title>Go Admin Panel</title></head>
<body>
<h1>Command Output:</h1>
<pre>{result}</pre>
<p>Go Gin Framework v1.9.1</p>
</body>
</html>
""".encode())
            return
        
        # 4. GitLab-like page + .gitlab-ci.yml
        if path in ['/', '/index.html', '/login'] or 'gitlab' in path:
            content = """
<!DOCTYPE html>
<html>
<head><title>Go Web Admin - GitLab Style</title></head>
<body>
<h1>Welcome to Go Web Service</h1>
<p>Powered by Gin + Go 1.21</p>
<a href="/cmd">Admin Console</a> | <a href="/main.go.bak">Source</a>
</body>
</html>
"""
            if path == '/-/blob/master/.gitlab-ci.yml':
                content = """
go:
  stage: build
  script:
    - go build -o app main.go
secrets:
  DB_PASS: supersecret123
"""
            self.wfile.write(content.encode())
            return
        
        # Default Go page
        self.wfile.write(b"""
<html><body>
<h1>Go Web Application</h1>
<p>Frameworks: Gin, Fiber detected</p>
<ul>
<li><a href="/cmd?cmd=whoami">Test Command</a></li>
<li><a href="/main.go.bak">Source Backup</a></li>
<li><a href="/.git/HEAD">Git</a></li>
</ul>
</body></html>
""")

    def log_message(self, format, *args):
        print(f"[{datetime.now()}] {format % args}")

print(f"[+] GOROKS V8 Simulator running on http://localhost:{PORT}")
print("[+] Expected findings: go_web_gin_fiber, RCE, main.go.bak leak, Git exposure")
print("[+] Test: ./goroks_v8.sh http://localhost:8081")
print("[+] Kill: Ctrl+C")

with socketserver.TCPServer(("", PORT), VulnerableGoHandler) as httpd:
    httpd.serve_forever()