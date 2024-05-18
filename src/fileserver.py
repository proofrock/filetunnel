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
