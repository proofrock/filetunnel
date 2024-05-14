#!/bin/bash

# filetunnel v0.1.0 https://github.com/proofrock/filetunnel
# Copyright (c) 2024- Germano Rizzo <oss AT germanorizzo DOT it>
# See LICENSE file (MIT License)

#####################
# Edit this section #
#####################

# How to contact the jump server from the "file server side". user@host
SSH_SERVER=user@123.123.123.123
# How to contact the jump server from the "client side".
FILE_SERVER=123.123.123.123
# Port on the jump server to tunnel the HTTP server on
PORT=7017

# Setup HTTPS
DO_HTTPS=0
CERT_FILE=./cert.pem
KEY_FILE=./key.pem

###################
# Not from now on #
###################

RND=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)

FILESERVERSCRIPT=`cat <<PYDOC
import os, sys, ssl
from http.server import HTTPServer, SimpleHTTPRequestHandler

# CLI parameters (internal)

file_path = sys.argv[1] # File to serve
url_path =  sys.argv[2] # Random string for URL path
http_port = int(sys.argv[3]) # Port for the server
do_ssl = sys.argv[4] == "1" # Do ssl?
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
        # elif self.path == '/exit':
        #     self.wfile.write(b'bye')
        #     self.send_response(200)
        #     exit(0)
        else:
            self.send_error(404)

# Set up the HTTPS server
server_address = ('', http_port)
httpd = HTTPServer(server_address, SingleFileRequestHandler)

if do_ssl:
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)  
    context.load_cert_chain(cert_file, key_file)
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

httpd.serve_forever()
PYDOC`

FREEPORTSCRIPT=`cat <<PYDOC
import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind(('', 0))
    addr, port = s.getsockname()
print(port)
PYDOC`

LOCAL_PORT=$(python3 -c "$FREEPORTSCRIPT")

function handle_interrupt {
    kill -TERM "$PID1" "$PID2" 2>/dev/null
    wait "$PID1" "$PID2" 2>/dev/null
    # [TODO] Python dies with ugly-looking "logs"
    echo "Bye bye!"
    exit 0
}

trap handle_interrupt SIGINT

ssh $SSH_SERVER -N -R:$PORT:localhost:$LOCAL_PORT &
PID1=$!

{ python3 -c "$FILESERVERSCRIPT" "$1" "$RND" "$LOCAL_PORT" "$DO_HTTPS" "$CERT_FILE" "$KEY_FILE"; kill $PID1; } & # At exit, kills the ssh session
PID2=$!

PROTO="http"
if [ "$DO_HTTPS" -eq "1" ]; then
    PROTO="https"
    ADD_FLAG="k"
fi

echo "All set up, using local port $LOCAL_PORT. Now use the following command:"
echo
echo "curl -OJf$ADD_FLAG $PROTO://$FILE_SERVER:$PORT/$RND"
echo
echo "Then you can close this process with ctrl-c."

wait "$PID1" "$PID2"
