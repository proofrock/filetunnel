# fileserver v0.1.0

This project aids in setting up a tunnel that serves a single file on an encrypted connection, allowing to source it from your system and downloading it on another system you don't have "direct" access to, because under a firewall or such reasons.

It employs a "jump server" to which it will reverse tunnel a local port via SSH. 

It has been tested under Linux, both for the source and destination system; it will be adapted to Windows and MacOS.

## Prerequisites

- A "jump server" that you can access via SSH from the source system;
  - A port on it, accessible by "the world";
  - SSH on the jump server must be configured to allow remote tunnels (see below);
- `python` v3 on the source system;
- `curl` on the destination system.

## Usage

- You configure and run the script `filetunnel.sh` with the file to transfer:
```bash
./fileserver.sh myFile.binary
```
- It will output a `curl` command to use on the destination system to download the file.

Behind the scenes, the script opens a web server using python, on a random local port; then reverse tunnels it on the jump server, making it available remotely. 

The `curl` script, when executed on the destination system, will connect to the port and download the file, assigning the correct filename to it.

## Setup

### The jump server

This is a "normal" server such as a VPS, that you can access via SSH from the source system.

A port (to configure inside the script) must be accessible from outside, at least from the destination system.

On ssh, (reverse) tunneling must be enabled. Ensure that you have this setting in `/etc/ssh/sshd_config`:

```
AllowTcpForwarding yes
```

We'll also need to access the remote-forwarded port from outside. So, set:

```python
GatewayPorts clientspecified # or 'yes'
```

**WARNING!** This setting allows the forwarded port (*any* forwarded port, even for other uses) to be globally accessible. Carefully consider the security implications of this.

### The source system

Download `filetunnel.sh` from the release page.

Open it, and configure the variables in the first section. You'll need:

- `SSH_SERVER`: address to contact the jump server from the source system, using ssh, in form `user@host`.
- `FILE_SERVER`: IP or DNS name to contact the jump server from the destination system.
- `PORT`: port on the jump server for the tunnel, accessible from the destination server.

If you want HTTPS, see the next section.

### Setup https

First, generate the certificates using:
```bash
openssl req -newkey rsa:4096 -nodes -keyout key.pem -x509 -days 365 -out cert.pem
```
This will generate a `cert.pem` and a (secret) `key.pem` files.

Then configure `fileserver.sh` to use HTTPS, by setting the relevant variables: 

- `DO_HTTPS`: set to `1`.
- `CERT_FILE`, `KEY_FILE`: paths to the `cert.pem` and `key.pem` files generated by `openssl`.

## Security

- There is an inherent risk in doing reverse tunneling. It's a good idea to reserve the jump server to this use;
- The connection between the source system and the jump server is protected by `ssh`;
- The connection between the jump server and the destination system is protected by (optional) HTTPS, using a user-provided certificate;
  - Also, the generated URL is random;
- Once transferred the file, it's good measure to terminate the script to avoid continued exposure.

## Troubleshooting

### When stopping the script w/ `ctrl-c`, a python error is shown
```
Traceback (most recent call last):
  File "<string>", line 18, in <module>
  File "/usr/lib/python3.12/socketserver.py", line 235, in serve_forever
    ready = selector.select(poll_interval)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/lib/python3.12/selectors.py", line 415, in select
    fd_event_list = self._selector.poll(timeout)
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
KeyboardInterrupt
```
This is ok, for now just ignore it. It's on the todo not to show it.

## To do

- Adapt and fully test under MacOS, Windows
- Optional "one shot" mode: when the file is downloaded, the server exists;
- Optional compression;
- When stopping the script, the python part emits an ugly-looking error, even if it's totally intended.

## Build and contribute

In the `src` folder there are three script (one bash, two python) to manually "compile" into the target script. Make a copy of the bash script, and then follow the comments that contain `[BUILD]`.

If you have any good idea, please feel free to hack on it! The code should be fairly simple to understand and change, and doesn't have many dependencies.

## License

```
filetunnel v0.1.0 https://github.com/proofrock/filetunnel
Copyright (c) 2024- Germano Rizzo <oss AT germanorizzo DOT it>
See LICENSE file (MIT License)
```
