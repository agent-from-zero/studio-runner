# Installs the current Roblox Studio build and closes the copy the installer auto-launches.
$ProgressPreference = 'SilentlyContinue'
$ver = (Invoke-RestMethod https://clientsettingscdn.roblox.com/v2/client-version/WindowsStudio64).clientVersionUpload
Invoke-WebRequest "https://setup.rbxcdn.com/$ver-RobloxStudioInstaller.exe" -OutFile "$env:RUNNER_TEMP\inst.exe"
Start-Process "$env:RUNNER_TEMP\inst.exe"
$t0 = Get-Date
while (((Get-Date) - $t0).TotalMinutes -lt 6 -and -not (Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue)) { Start-Sleep 2 }
Start-Sleep 3
Get-Process RobloxStudioBeta, RobloxStudioInstaller -ErrorAction SilentlyContinue | Stop-Process -Force
$exe = Get-ChildItem 'C:\Program Files\Roblox\Versions' -Recurse -Filter RobloxStudioBeta.exe | Select-Object -First 1
"STUDIO_EXE=$($exe.FullName)" | Out-File -Append $env:GITHUB_ENV
"installed $ver in $([int]((Get-Date) - $t0).TotalSeconds)s"
