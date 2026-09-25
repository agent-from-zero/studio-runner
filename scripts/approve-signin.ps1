# Signs the running Studio in as the agent account: reads Studio's quick sign-in code from its log
# and approves it with the agent's session (Roblox's own "Quick sign in" flow). Nothing secret is printed.
param([string]$Cookie, [string]$Exe = $env:STUDIO_EXE, [int]$Attempts = 8)
$logs = "$env:LOCALAPPDATA\Roblox\logs"; $code = $null
for ($a = 1; $a -le $Attempts -and -not $code; $a++) {
  Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
  if ($a -gt 1) {   # new local identity, so Studio re-rolls which sign-in page it shows
    Remove-Item "$env:LOCALAPPDATA\Roblox\LocalStorage" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item 'HKCU:\Software\Roblox\RobloxStudioBrowser' -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item 'HKCU:\Software\ROBLOX Corporation' -Recurse -Force -ErrorAction SilentlyContinue
  }
  Remove-Item "$logs\*Studio*" -Force -ErrorAction SilentlyContinue
  Start-Process $Exe
  $t0 = Get-Date
  while (-not $code -and ((Get-Date) - $t0).TotalSeconds -lt 25) {
    Start-Sleep 2
    foreach ($f in (Get-ChildItem $logs -Filter '*Studio*' -File -ErrorAction SilentlyContinue)) {
      $m = Select-String -Path $f.FullName -Pattern '"code":"([A-Z0-9]{6})"' -ErrorAction SilentlyContinue | Select-Object -Last 1
      if ($m) { $code = $m.Matches[0].Groups[1].Value; break }
    }
  }
  $t = Get-ChildItem $logs -Filter '*Studio*' -File -ErrorAction SilentlyContinue | ForEach-Object { Select-String -Path $_.FullName -Pattern 'rolloutPercent=\d+, inTreatment=\w+' -ErrorAction SilentlyContinue | Select-Object -First 1 }
  "attempt $a : $(if ($code) { 'sign-in code found' } else { 'no code' }) $(if ($t) { $t.Matches[0].Value })"
}
if (-not $code) { throw 'no sign-in code after all attempts' }
$ws = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$ws.Cookies.Add((New-Object System.Net.Cookie('.ROBLOSECURITY', $Cookie, '/', '.roblox.com')))
$api = 'https://apis.roblox.com/auth-token-service/v1/login'
$body = @{ code = $code } | ConvertTo-Json
$pre = Invoke-WebRequest "$api/enterCode" -Method Post -Body $body -ContentType 'application/json' -WebSession $ws -UseBasicParsing -SkipHttpErrorCheck
$csrf = $pre.Headers['x-csrf-token'] | Select-Object -First 1
$h = @{ 'x-csrf-token' = "$csrf" }
$r1 = Invoke-WebRequest "$api/enterCode" -Method Post -Body $body -ContentType 'application/json' -WebSession $ws -Headers $h -UseBasicParsing -SkipHttpErrorCheck
$r2 = Invoke-WebRequest "$api/validateCode" -Method Post -Body $body -ContentType 'application/json' -WebSession $ws -Headers $h -UseBasicParsing -SkipHttpErrorCheck
"sign-in approval: enterCode $($r1.StatusCode), validateCode $($r2.StatusCode)"
$t1 = Get-Date
while (((Get-Date) - $t1).TotalSeconds -lt 90) {
  $log = Get-ChildItem "$env:LOCALAPPDATA\Roblox\logs" -Filter '*Studio*' | Sort-Object LastWriteTime | Select-Object -Last 1
  if (Select-String -Path $log.FullName -Pattern 'Authenticated : YES|LoginController.*(success|Success|logged in)' -Quiet) { 'studio reports signed in'; break }
  Start-Sleep 3
}
