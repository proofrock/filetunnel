# filetunnel v0.1.3 https://github.com/proofrock/filetunnel
# Copyright (c) 2024- Germano Rizzo <oss AT germanorizzo DOT it>
# See LICENSE file (MIT License)

#####################
# Edit this section #
#####################

# The python command
$PYTHON_COMMAND="python"

# How to contact the jump server from the "file server side". user@host
$SSH_SERVER="user@123.123.123.123"
# How to contact the jump server from the "client side".
$FILE_SERVER="123.123.123.123"
# Port on the jump server to tunnel the HTTP server on
$PORT="7017"

# Setup HTTPS
$DO_HTTPS="0"
$CERT_FILE="./cert.pem"
$KEY_FILE="./key.pem"

###################
# Not from now on #
###################

$RND = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 24 | ForEach-Object {[char]$_})

$FILESERVERSCRIPT = @"

import os, sys, ssl
from http.server import HTTPServer, SimpleHTTPRequestHandler

# CLI parameters (internal)

file_path = sys.argv[1] # File to serve
url_path =  sys.argv[2] # Random string for URL path
http_port = int(sys.argv[3]) # Port for the server
do_ssl = sys.argv[4] == '1' # Do ssl?
if do_ssl:
    cert_file = sys.argv[5]
    key_file = sys.argv[6]

# Size
file_size = os.stat(file_path).st_size

# Create a custom request handler
class SingleFileRequestHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == f'/{url_path}':
            self.send_response(200)
            self.send_header('Content-Type', 'binary/octet-stream')
            self.send_header('Content-Length', str(file_size))
            self.send_header('Content-Disposition', f'attachment; filename="{os.path.basename(file_path)}"')
            self.end_headers()
            with open(file_path, 'rb') as file:
                self.wfile.write(file.read())
        else:
            self.send_error(404)

# Set up the HTTPS server
server_address = ('127.0.0.1', http_port)
httpd = HTTPServer(server_address, SingleFileRequestHandler)

if do_ssl:
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)  
    context.load_cert_chain(cert_file, key_file)
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

try:
    httpd.serve_forever()
except KeyboardInterrupt:
    print('Shutting down local web server.')
finally:
    httpd.server_close()
"@

$FREEPORTSCRIPT = @"

import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind(('', 0))
    addr, port = s.getsockname()
print(port)
"@

$LOCAL_PORT = & $PYTHON_COMMAND -c $FREEPORTSCRIPT

function Handle-Interrupt {
    Stop-Process  $PID1,$PID2 -ErrorAction SilentlyContinue
    Write-Host "Bye bye!"
    exit
    # [TODO] Python dies with ugly-looking "logs"
}

$PID1 = (Start-Process -FilePath ssh -ArgumentList "$SSH_SERVER -N -R:$PORT`:127.0.0.1`:$LOCAL_PORT" -NoNewWindow -passthru).Id

$PID2 = (Start-Process -FilePath $PYTHON_COMMAND -ArgumentList "-c `"$FILESERVERSCRIPT`" `"$($args[0])`" `"$RND`" `"$LOCAL_PORT`" `"$DO_HTTPS`" `"$CERT_FILE`" `"$KEY_FILE`"" -NoNewWindow -passthru).Id

$PROTO = "http"
if ($DO_HTTPS -eq "1") {
    $PROTO = "https"
    $ADD_FLAG = "k"
}

Write-Host "All set up, using local port $LOCAL_PORT."
Write-Host "To download from a shell, use the following command:"
Write-Host
Write-Host "curl -OJf$ADD_FLAG $PROTO`:`/`/$FILE_SERVER`:$PORT`/$RND"
Write-Host
Write-Host "You can also visit the URL using a browser."
Write-Host "After the download, you can close this process with ctrl-c."

# Set up Ctrl+C handling
[Console]::TreatControlCAsInput = $true
while ($true) {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq "C" -and $key.Modifiers -band [ConsoleModifiers]::Control) {
            Handle-Interrupt
        }
    }
    Start-Sleep -Milliseconds 100
}
