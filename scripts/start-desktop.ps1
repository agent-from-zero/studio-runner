# Remote desktop for this runner: TightVNC (password) -> noVNC in the browser -> Cloudflare quick tunnel.
# Prints nothing secret. Writes the tunnel URL and VNC password to files in RUNNER_TEMP.
$ProgressPreference = 'SilentlyContinue'
$T = $env:RUNNER_TEMP
$pw = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
Set-Content "$T\vncpw.txt" $pw -NoNewline
Invoke-WebRequest 'https://www.tightvnc.com/download/2.8.85/tightvnc-2.8.85-gpl-setup-64bit.msi' -OutFile "$T\tvnc.msi"
$args = "/i `"$T\tvnc.msi`" /quiet /norestart ADDLOCAL=Server SERVER_REGISTER_AS_SERVICE=1 SERVER_ADD_FIREWALL_EXCEPTION=0 " +
        "SET_USEVNCAUTHENTICATION=1 VALUE_OF_USEVNCAUTHENTICATION=1 SET_PASSWORD=1 VALUE_OF_PASSWORD=$pw " +
        "SET_ALLOWLOOPBACK=1 VALUE_OF_ALLOWLOOPBACK=1 SET_LOOPBACKONLY=1 VALUE_OF_LOOPBACKONLY=1"
Start-Process msiexec.exe -ArgumentList $args -Wait
Invoke-WebRequest 'https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.zip' -OutFile "$T\novnc.zip"
Expand-Archive "$T\novnc.zip" -DestinationPath $T -Force
python -m pip install -q websockify | Out-Null
"desktop installed (vnc service: $((Get-Service tvnserver).Status))"
