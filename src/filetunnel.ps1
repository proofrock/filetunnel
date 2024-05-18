# filetunnel v0.1.4 https://github.com/proofrock/filetunnel
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
# Put 'fileserver.py' here
"@

$FREEPORTSCRIPT = @"
# Put 'freeport.py' here
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
