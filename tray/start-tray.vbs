' Runs the Cloud Studio tray icon with a hidden console and waits for it. CloudStudio.exe is a renamed copy of
' powershell.exe so Windows gives this icon its own taskbar entry (and it can be pinned visible).
CreateObject("WScript.Shell").Run """C:\Users\teach\studio-runner\tray\CloudStudio.exe"" -NoProfile -ExecutionPolicy Bypass -File ""C:\Users\teach\studio-runner\tray\cloud-studio-tray.ps1""", 0, True
