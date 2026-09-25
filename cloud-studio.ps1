<#
Cloud Studio: Roblox Studio on free GitHub Actions Windows machines (agent account "agent-from-zero",
Studio signed in as Roblox account "agentfromzero"). For people and AIs on this PC.

  powershell -File C:\Users\teach\studio-runner\cloud-studio.ps1 start [minutes] [idle]   # start a machine (default 120 min, stops after 15 min with nobody connected)
  powershell -File C:\Users\teach\studio-runner\cloud-studio.ps1 list                     # running machines and their state
  powershell -File C:\Users\teach\studio-runner\cloud-studio.ps1 link <run id>            # print the browser link to that machine's desktop
  powershell -File C:\Users\teach\studio-runner\cloud-studio.ps1 open <run id>            # open that desktop in the browser
  powershell -File C:\Users\teach\studio-runner\cloud-studio.ps1 stop <run id | all>      # shut machines down (do this when done: it frees the slot)

Limits: up to 20 machines at once, 6 hours each, nothing on a machine is kept after it stops.
Credentials: C:\Users\teach\operator\secrets.json (github3.token, github3.viewKey). Never print them.
#>
param([string]$Cmd = 'list', [string]$Arg1, [string]$Arg2)
$S = Get-Content 'C:\Users\teach\operator\secrets.json' -Raw | ConvertFrom-Json
$Key = [Convert]::FromBase64String($S.github3.viewKey)
$API = 'https://api.github.com/repos/agent-from-zero/studio-runner'
$H = @{ Authorization = "token $($S.github3.token)"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'cloud-studio' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Links {
  $out = @{}
  foreach ($x in (Invoke-RestMethod "$API/issues/1/comments?per_page=100" -Headers $H)) {
    if ($x.body -match '^session (\d+) (\S+)$') {
      $b = [Convert]::FromBase64String($Matches[2]); $aes = [Security.Cryptography.Aes]::Create(); $aes.Key = $Key; $aes.IV = $b[0..15]
      $u, $pw = ([Text.Encoding]::UTF8.GetString($aes.CreateDecryptor().TransformFinalBlock($b, 16, $b.Length - 16))) -split '\|', 2
      $out[$Matches[1]] = "$u/vnc.html?autoconnect=true&resize=scale&reconnect=true&password=$pw"
    }
  }
  $out
}
function Runs { @((Invoke-RestMethod "$API/actions/workflows/desktop.yml/runs?per_page=30" -Headers $H).workflow_runs | Where-Object { $_.status -ne 'completed' }) }
switch ($Cmd) {
  'start' {
    $m = if ($Arg1) { $Arg1 } else { '120' }; $i = if ($Arg2) { $Arg2 } else { '15' }
    Invoke-RestMethod "$API/actions/workflows/desktop.yml/dispatches" -Method Post -Headers $H -Body (@{ ref = 'main'; inputs = @{ minutes = $m; idle = $i } } | ConvertTo-Json) | Out-Null
    "started: $m min max, stops after $i min with nobody connected. Ready in ~3 min; then: cloud-studio.ps1 list"
  }
  'list' {
    $l = Links; $r = Runs
    if (-not $r) { 'no machines running' }
    foreach ($x in $r) { "{0}  {1}  up {2} min" -f $x.id, $(if ($l.ContainsKey("$($x.id)")) { 'ready' } else { 'starting' }), [int]((Get-Date).ToUniversalTime() - ([datetime]$x.created_at).ToUniversalTime()).TotalMinutes }
  }
  'link' { $l = Links; if ($l.ContainsKey($Arg1)) { $l[$Arg1] } else { 'not ready (or no such run)' } }
  'open' { $l = Links; if ($l.ContainsKey($Arg1)) { Start-Process $l[$Arg1]; 'opened' } else { 'not ready (or no such run)' } }
  'stop' {
    $ids = if ($Arg1 -eq 'all') { (Runs).id } else { @($Arg1) }
    foreach ($id in $ids) { Invoke-RestMethod "$API/actions/runs/$id/cancel" -Method Post -Headers $H | Out-Null; "stopping $id" }
  }
  default { Get-Help $MyInvocation.MyCommand.Path }
}
