' Starts the Cloud Studio tray icon through bots.mjs (no window) unless it is already running.
CreateObject("WScript.Shell").Run "node C:\Users\teach\bots\bots.mjs start cloud-studio-tray -- wscript.exe //B C:\Users\teach\studio-runner\tray\start-tray.vbs", 0, False
