Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Get folder where this VBS file lives
Dim baseDir
baseDir = fso.GetParentFolderName(WScript.ScriptFullName)

Dim psPath
psPath = baseDir & "\send_device.ps1"

Dim batPath
batPath = baseDir & "\hack.bat"

' Run PowerShell script
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & psPath & """", 1, False

' Run batch file
WshShell.Run """" & batPath & """", 1, False

Set WshShell = Nothing
