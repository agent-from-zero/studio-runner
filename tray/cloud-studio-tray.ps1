# Cloud Studio tray icon: opens, lists and stops Roblox Studio desktops running on the agent's GitHub Actions runners.
# Reads the agent's GitHub token and view key from operator\secrets.json (this PC only).
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$ErrorActionPreference = 'Continue'
$S     = Get-Content 'C:\Users\teach\operator\secrets.json' -Raw | ConvertFrom-Json
$Tok   = $S.github3.token
$Key   = [Convert]::FromBase64String($S.github3.viewKey)
$Repo  = 'agent-from-zero/studio-runner'
$API   = "https://api.github.com/repos/$Repo"
$H     = @{ Authorization = "token $Tok"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'cloud-studio-tray' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$opened  = @{}        # run id -> $true once its viewer was opened
$pending = 0          # sessions asked for but not yet opened

function Get-Runs { try { (Invoke-RestMethod "$API/actions/workflows/desktop.yml/runs?per_page=20" -Headers $H).workflow_runs | Where-Object { $_.status -ne 'completed' } } catch { @() } }
function Get-Links {
  $out = @{}
  try { $c = Invoke-RestMethod "$API/issues/1/comments?per_page=100" -Headers $H } catch { return $out }
  foreach ($x in $c) {
    if ($x.body -match '^session (\d+) (\S+)$') {
      try {
        $b = [Convert]::FromBase64String($Matches[2]); $aes = [Security.Cryptography.Aes]::Create(); $aes.Key = $Key
        $aes.IV = $b[0..15]; $p = $aes.CreateDecryptor().TransformFinalBlock($b, 16, $b.Length - 16)
        $u, $pw = ([Text.Encoding]::UTF8.GetString($p)) -split '\|', 2
        $out[$Matches[1]] = "$u/vnc.html?autoconnect=true&resize=scale&reconnect=true&password=$pw"
      } catch {}
    }
  }
  $out
}
function Open-Viewer($url) { Start-Process $url }
function Start-Session([int]$minutes) {
  $body = @{ ref = 'main'; inputs = @{ minutes = "$minutes" } } | ConvertTo-Json
  try { Invoke-RestMethod "$API/actions/workflows/desktop.yml/dispatches" -Method Post -Headers $H -Body $body | Out-Null
        $script:pending++; $tray.ShowBalloonTip(5000, 'Cloud Studio', "Starting a machine for $minutes min. It opens here in about 3 minutes.", 'Info') }
  catch { $tray.ShowBalloonTip(5000, 'Cloud Studio', "Could not start: $($_.Exception.Message)", 'Error') }
}
function Stop-Run($id) { try { Invoke-RestMethod "$API/actions/runs/$id/cancel" -Method Post -Headers $H | Out-Null } catch {} }

$icon = [Drawing.SystemIcons]::Application
$exe = Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter RobloxStudioBeta.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($exe) { $icon = [Drawing.Icon]::ExtractAssociatedIcon($exe.FullName) }
$tray = New-Object Windows.Forms.NotifyIcon
$tray.Icon = $icon; $tray.Text = 'Cloud Studio'; $tray.Visible = $true
$menu = New-Object Windows.Forms.ContextMenuStrip
$tray.ContextMenuStrip = $menu

function Build-Menu {
  $menu.Items.Clear()
  $new = New-Object Windows.Forms.ToolStripMenuItem 'Open a new cloud Studio'
  foreach ($m in 60, 120, 240, 350) {
    $label = if ($m -ge 60) { "for $([math]::Round($m/60,1)) hours" } else { "for $m min" }
    $i = New-Object Windows.Forms.ToolStripMenuItem $label; $i.Tag = $m
    $i.add_Click({ param($s) Start-Session $s.Tag }); [void]$new.DropDownItems.Add($i)
  }
  [void]$menu.Items.Add($new)
  [void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
  $runs = @(Get-Runs); $links = Get-Links
  if ($runs.Count -eq 0) { $e = $menu.Items.Add('No machines running'); $e.Enabled = $false }
  foreach ($r in $runs) {
    $age = [int]((Get-Date).ToUniversalTime() - ([datetime]$r.created_at).ToUniversalTime()).TotalMinutes
    $state = if ($links.ContainsKey("$($r.id)")) { 'ready' } else { 'starting' }
    $item = New-Object Windows.Forms.ToolStripMenuItem "Machine $($r.run_number)  ($state, up $age min)"
    $o = New-Object Windows.Forms.ToolStripMenuItem 'Open'; $o.Tag = "$($r.id)"; $o.Enabled = ($state -eq 'ready')
    $o.add_Click({ param($s) $l = Get-Links; if ($l.ContainsKey($s.Tag)) { Open-Viewer $l[$s.Tag] } })
    $x = New-Object Windows.Forms.ToolStripMenuItem 'Stop'; $x.Tag = "$($r.id)"
    $x.add_Click({ param($s) Stop-Run $s.Tag; $tray.ShowBalloonTip(3000, 'Cloud Studio', 'Machine stopping.', 'Info') })
    [void]$item.DropDownItems.Add($o); [void]$item.DropDownItems.Add($x); [void]$menu.Items.Add($item)
  }
  if ($runs.Count -gt 1) { $all = $menu.Items.Add('Stop all'); $all.add_Click({ foreach ($r in @(Get-Runs)) { Stop-Run $r.id } }) }
  [void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
  $q = $menu.Items.Add('Quit tray icon (machines keep running)'); $q.add_Click({ $tray.Visible = $false; [Windows.Forms.Application]::Exit() })
}
$menu.add_Opening({ Build-Menu })
$tray.add_MouseClick({ param($s, $e) if ($e.Button -eq 'Left') { Build-Menu; $m = [Windows.Forms.NotifyIcon].GetMethod('ShowContextMenu', [Reflection.BindingFlags]'Instance,NonPublic'); $m.Invoke($tray, $null) } })

# Every 10 s while a session is pending: open its viewer as soon as its link appears.
$timer = New-Object Windows.Forms.Timer; $timer.Interval = 10000
$timer.add_Tick({
  if ($script:pending -le 0) { return }
  $links = Get-Links
  foreach ($id in $links.Keys) { if (-not $opened.ContainsKey($id)) { $opened[$id] = $true; $script:pending--; Open-Viewer $links[$id]; $tray.ShowBalloonTip(4000, 'Cloud Studio', 'Your cloud Studio is open in the browser.', 'Info') } }
})
foreach ($id in (Get-Links).Keys) { $opened[$id] = $true }   # links that existed before this tray started are not auto-opened
$timer.Start()
[Windows.Forms.Application]::Run()
$tray.Dispose()
