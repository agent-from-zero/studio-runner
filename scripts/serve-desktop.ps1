# Starts the browser viewer and the tunnel. Run this from the long-lived step: GitHub ends a step's child processes when the step ends.
$T = $env:RUNNER_TEMP
Start-Process python -ArgumentList "-m websockify --web `"$T\noVNC-1.5.0`" 6080 localhost:5900" -WindowStyle Hidden -RedirectStandardError "$T\ws.err" -RedirectStandardOutput "$T\ws.out"
Invoke-WebRequest 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile "$T\cloudflared.exe"
Start-Process "$T\cloudflared.exe" -ArgumentList 'tunnel --url http://localhost:6080 --no-autoupdate' -WindowStyle Hidden -RedirectStandardError "$T\cf.err" -RedirectStandardOutput "$T\cf.out"
$url = $null; $t0 = Get-Date
while (-not $url -and ((Get-Date) - $t0).TotalSeconds -lt 90) {
  Start-Sleep 2
  $m = Select-String -Path "$T\cf.err" -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($m) { $url = $m.Matches[0].Value }
}
if (-not $url) { throw 'tunnel did not come up' }
Set-Content "$T\url.txt" $url -NoNewline
"tunnel up"
