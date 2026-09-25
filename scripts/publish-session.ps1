# Posts this session's viewer link, AES-encrypted with VIEW_KEY, as a comment on issue 1. Only the PC can read it.
param([string]$ViewKey)
$T = $env:RUNNER_TEMP
$plain = "$(Get-Content "$T\url.txt" -Raw)|$(Get-Content "$T\vncpw.txt" -Raw)"
$aes = [System.Security.Cryptography.Aes]::Create(); $aes.Key = [Convert]::FromBase64String($ViewKey); $aes.GenerateIV()
$ct = $aes.CreateEncryptor().TransformFinalBlock([Text.Encoding]::UTF8.GetBytes($plain), 0, $plain.Length)
$blob = [Convert]::ToBase64String($aes.IV + $ct)
$body = @{ body = "session $env:GITHUB_RUN_ID $blob" } | ConvertTo-Json
$h = @{ Authorization = "Bearer $env:GH_TOKEN"; Accept = 'application/vnd.github+json' }
$r = Invoke-RestMethod "https://api.github.com/repos/$env:GITHUB_REPOSITORY/issues/1/comments" -Method Post -Headers $h -Body $body
"session published (comment $($r.id))"
Set-Content "$T\comment.txt" $r.id
