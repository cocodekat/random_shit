@echo off
setlocal enabledelayedexpansion

:: =================================================================================
:: CONFIGURATION
:: =================================================================================
set "REMOTE_URL=https://drive.google.com/uc?export=download&id=1oDXgVUwR0LcHXR-Mp1VwsaHvlpd_fz1D"
set "LOCAL_FILE=my_local_script.bat"
set "TEMP_FILE=temp_download.txt"
set "INTERVAL=10"
set "CURRENT_DEVICE_NAME=%COMPUTERNAME%"
set "LOG_FILE=%CURRENT_DEVICE_NAME%_out.txt"
set "DEVICE_FILE=device.txt"
:: =================================================================================


:: --- INITIAL SETUP (RUNS ONLY ONCE) ---
if not exist "!DEVICE_FILE!" (
    echo [SETUP] Saving device name "!CURRENT_DEVICE_NAME!" to "!DEVICE_FILE!"
    echo !CURRENT_DEVICE_NAME!> "!DEVICE_FILE!"
)


:loop
cls
echo [!DATE! !TIME!] Checking for updates on Google Drive for device: !CURRENT_DEVICE_NAME!

set "AUTHORIZED_TO_UPDATE="

:: 1. Download the file from Google Drive to a temporary file
curl -s -L -o "!TEMP_FILE!" "!REMOTE_URL!"

:: Check if the download was successful (size > 0)
for %%I in ("!TEMP_FILE!") do set size=%%~zI
if !size! LSS 1 (
    echo [ERROR] Download failed or file is empty. Retrying in !INTERVAL! seconds...
    del "!TEMP_FILE!" 2>nul
    goto wait
)

:: 2. Check if local file exists. If not, create it.
if not exist "!LOCAL_FILE!" (
    echo [INFO] Local script not found. Skipping security check and creating initial file...
    goto perform_update
)

:: 3. SECURITY CHECK: Verify the device name in the new file
echo [SECURITY CHECK] Checking if the new file is authorized for this device...

:: Use FOR /F to read the first line, which correctly strips line endings (CRLF).
set "FIRST_LINE="
for /f "usebackq tokens=* delims=" %%a in ("!TEMP_FILE!") do (
    set "FIRST_LINE=%%a"
    goto compare_names
)
:: If file is empty or corrupted here
echo [ERROR] Could not read first line for security check.
del "!TEMP_FILE!" 2>nul
goto wait


:compare_names
:: Trim leading/trailing spaces
set "FIRST_LINE=!FIRST_LINE: =!"

if /i "!FIRST_LINE!" NEQ "!CURRENT_DEVICE_NAME!" (
    echo [WARNING] Device Mismatch! File is intended for "!FIRST_LINE!".
    echo [WARNING] Aborting download/execution.
    del "!TEMP_FILE!" 2>nul
    goto wait
)

echo [AUTHORIZED] First line of new file matches device name. Proceeding.
set "AUTHORIZED_TO_UPDATE=true"


:: 4. Compare files and update IF authorized
if /i "!AUTHORIZED_TO_UPDATE!" == "true" goto run_comparison
goto wait


:run_comparison
echo [COMPARING] Calculating MD5 hash for comparison...

set "LOCAL_HASH="
set "TEMP_HASH="
set "HASH_TEMP_FILE=hash_output_temp.txt"

:: --- 1. Get Hash for Local File ---
:: Redirect all output to temp file
certutil -hashfile "!LOCAL_FILE!" MD5 > "!HASH_TEMP_FILE!" 2>nul

:: Read the output: skip=1 to get the hash on the second line.
for /f "skip=1 tokens=1" %%i in ('type "!HASH_TEMP_FILE!"') do (
    :: Use GOTO to ensure only the very first hash line is captured and we exit the loop.
    set "LOCAL_HASH=%%i"
    goto :read_temp_hash
)

:read_temp_hash
del "!HASH_TEMP_FILE!" 2>nul
if not defined LOCAL_HASH (
    echo [FATAL] Failed to generate hash for local file.
    del "!TEMP_FILE!" 2>nul
    goto wait
)


:: --- 2. Get Hash for Temporary Downloaded File ---
:: Redirect all output to temp file
certutil -hashfile "!TEMP_FILE!" MD5 > "!HASH_TEMP_FILE!" 2>nul

:: Read the output: skip=1 to get the hash on the second line.
for /f "skip=1 tokens=1" %%i in ('type "!HASH_TEMP_FILE!"') do (
    :: Use GOTO to ensure only the very first hash line is captured and we exit the loop.
    set "TEMP_HASH=%%i"
    goto :check_hashes
)

:check_hashes
del "!HASH_TEMP_FILE!" 2>nul
if not defined TEMP_HASH (
    echo [FATAL] Failed to generate hash for temp file.
    del "!TEMP_FILE!" 2>nul
    goto wait
)


:: --- 3. Comparison ---
fc /b "!LOCAL_FILE!" "!TEMP_FILE!" >nul
if errorlevel 1 (
    echo [UPDATE DETECTED] Remote file is different
    goto perform_update
) else (
    echo [NO CHANGE] Local file is identical. Skipping update.
    del "!TEMP_FILE!" 2>nul
    goto wait
)



:: =================================================================================
:: UPDATE AND EXECUTION BLOCK
:: =================================================================================
:perform_update

:: Start output redirection to the device-specific log file
echo -------------------------------------------------------------------------------- >> "!LOG_FILE!"
echo [!DATE! !TIME!] --- UPDATE AND EXECUTION START --- >> "!LOG_FILE!"
echo [LOG] Overwriting "!LOCAL_FILE!" with new version >> "!LOG_FILE!"

:: Overwrite local file with the new version
move /Y "!TEMP_FILE!" "!LOCAL_FILE!" >nul
echo [SUCCESS] Local script has been updated >> "!LOG_FILE!"

:: --- START OF EXECUTION FIX (Robustly skips the first line) ---
echo [EXECUTE] Running new command script (Skipping header) >> "!LOG_FILE!"

:: 1 Create a temporary executable file (cmd) that skips the first line
more +1 "!LOCAL_FILE!" > temp_run.cmd

:: 2 Execute the temporary file and capture its output
>> "!LOG_FILE!" (
    call temp_run.cmd
)

:: 3. Clean up the temporary file
del temp_run.cmd 2>nul

echo [EXECUTE] Execution finished. >> "!LOG_FILE!"
:: --- END OF EXECUTION FIX ---

:: After successful update and execution, run the PowerShell upload script
echo [UPLOAD] Running PowerShell upload script to send log to GitHub...
:: MODIFIED: Use -Command with explicit error handling for robustness
PowerShell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "& { .\git.ps1; exit $LASTEXITCODE }"

if errorlevel 1 (
    echo [ERROR] PowerShell script failed to execute. Check path, permissions, and file encoding of git.ps1.
)

goto wait


:: =================================================================================
:: WAIT AND RESTART LOOP
:: =================================================================================
:wait
timeout /t !INTERVAL! /nobreak >nul
goto loop