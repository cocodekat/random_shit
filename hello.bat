@echo off
setlocal

:: --- CONFIGURATION START ---
echo ran > "%USERPROFILE%\hello_ran.txt"

:: The direct download URL format for Google Drive
set "REMOTE_URL=https://drive.google.com/uc?export=download&id=1oDXgVUwR0LcHXR-Mp1VwsaHvlpd_fz1D"

:: The name/path of the local file you want to update
set "LOCAL_FILE=my_local_file.bat"

:: The temporary file used for comparison
set "TEMP_FILE=temp_download.txt"

:: Time in seconds to wait between checks (10 seconds as requested)
set "INTERVAL=10"

:: --- CONFIGURATION END ---

:loop
cls
echo [%DATE% %TIME%] Checking for updates on Google Drive...

:: 1. Download the file from Google Drive to a temporary file
:: -s = silent, -L = follow redirects (CRITICAL for GDrive), -o = output file
curl -s -L -o "%TEMP_FILE%" "%REMOTE_URL%"

:: Check if the download was successful (size > 0)
for %%I in ("%TEMP_FILE%") do set size=%%~zI
if %size% LSS 1 (
    echo [ERROR] Download failed or file is empty. Retrying in %INTERVAL% seconds...
    goto wait
)

:: 2. Check if local file exists. If not, create it from the temp file.
if not exist "%LOCAL_FILE%" (
    echo [INFO] Local file not found. Creating initial file...
    move /Y "%TEMP_FILE%" "%LOCAL_FILE%" >nul
    echo [SUCCESS] File initialized.
    goto wait
)

:: 3. Compare the downloaded temp file with the local file (Binary comparison)
:: fc returns errorlevel 0 if identical, 1 if different
fc /b "%TEMP_FILE%" "%LOCAL_FILE%" >nul
if errorlevel 1 (
    echo [UPDATE DETECTED] Remote file is different.
    
    :: Overwrite local file with the new version
    move /Y "%TEMP_FILE%" "%LOCAL_FILE%" >nul
    
    echo [SUCCESS] Local file has been updated with Google Drive contents.
    cmd /c "%LOCAL_FILE%"
) else (
    echo [NO CHANGE] Local file matches Google Drive.
    :: Clean up temp file
    del "%TEMP_FILE%"
)

:wait
:: Wait for the specified interval before checking again
timeout /t %INTERVAL% /nobreak >nul
goto loop

