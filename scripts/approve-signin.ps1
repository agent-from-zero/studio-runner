# Signs the running Studio in as the agent account: reads Studio's quick sign-in code from its log
# and approves it with the agent's session (Roblox's own "Quick sign in" flow). Nothing secret is printed.
param([string]$Cookie, [int]$TimeoutSec = 180)
$t0 = Get-Date; $code = $null
while (-not $code -and ((Get-Date) - $t0).TotalSeconds -lt $TimeoutSec) {
  foreach ($f in (Get-ChildItem "$env:LOCALAPPDATA\Roblox\logs" -File -ErrorAction SilentlyContinue)) {
    $m = Select-String -Path $f.FullName -Pattern '"code":"([A-Z0-9]{6})"' -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($m) { $code = $m.Matches[0].Groups[1].Value; break }
  }
  if (-not $code) { Start-Sleep 2 }
}
if (-not $code) {
  Get-ChildItem "$env:LOCALAPPDATA\Roblox\logs" -File | ForEach-Object { "log: $($_.Name) $($_.Length)" }
  Get-ChildItem "$env:LOCALAPPDATA\Roblox\logs" -File | ForEach-Object { Select-String -Path $_.FullName -Pattern 'QuickSignIn|LoginPage|Authenticated|LoginController' | Select-Object -Last 8 | ForEach-Object { ($_.Line -replace '"code":"[A-Z0-9]+"','[code]' -replace 'privateKey":"[^"]+','[pk]').Substring(0, [Math]::Min(220, $_.Line.Length)) } }
}
if (-not $code) { throw 'no sign-in code appeared in the Studio log' }
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
