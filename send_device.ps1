# --- CONFIGURATION START ---

$GitHubToken = "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"
$RepoOwner = "cocodekat" # e.g., "cocodekat"
$RepoName = "random_shit" # e.g., "random_shit"

# Dynamically set the device name and file path based on the system variable
$DeviceName = $env:COMPUTERNAME
$FilePath = $DeviceName + "_out.txt"

# And apply the same fix for the local path:
$LogFilePath = $DeviceName + "_out.txt"

# --- CONFIGURATION END ---



# 0. Create an empty temporary device log file
Set-Content -Path $LogFilePath -Value $null


Write-Host "--- GitHub Log Upload Start for Device: $DeviceName ---"

# 1. Check if the local log file exists
if (-not (Test-Path $LogFilePath)) {
    Write-Warning "Log file ($LogFilePath) not found. Aborting upload."
    exit
}


# 2. Define Headers for Authentication
$Headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept"        = "application/vnd.github.v3+json"
}
$ApiUrlBase = "https://api.github.com/repos/$RepoOwner/$RepoName/contents/$FilePath"


# 3. GET the current file's SHA (required for updating)
Write-Host "Retrieving current file SHA from GitHub..."
try {
    # Suppress the body output from the GET request as we only need $FileInfo
    $FileInfo = Invoke-RestMethod -Uri $ApiUrlBase -Method Get -Headers $Headers -ErrorAction Stop
    $CurrentSha = $FileInfo.sha
    Write-Host "Found existing file. SHA: $CurrentSha"
}
catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    if ($StatusCode -eq 404) {
        $CurrentSha = $null
        Write-Host "File does not exist on GitHub (404). Will attempt to create it."
    }
    elseif ($StatusCode -eq 401 -or $StatusCode -eq 403) {
        Write-Error "Authentication Failed ($StatusCode). Check GitHub Token/Scopes."
        exit
    }
    else {
        Write-Error "Failed to retrieve file info from GitHub. Status Code: $StatusCode. $($_.Exception.Message)"
        exit
    }
}


# 4. Prepare the new content
Write-Host "Reading local log content and encoding to Base64..."

# Read the local file content as raw bytes
$ContentBytes = [System.IO.File]::ReadAllBytes($LogFilePath)
# Encode the bytes to Base64 string
$Base64Content = [System.Convert]::ToBase64String($ContentBytes)


# 5. Construct the JSON Payload
$JsonBody = @{
    "message" = "Automated log update for $DeviceName on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "content" = $Base64Content
}

if ($CurrentSha) {
    # SHA is REQUIRED for updating existing files
    $JsonBody.sha = $CurrentSha
} else {
    Write-Host "Note: SHA parameter omitted for file creation."
}

$JsonPayload = $JsonBody | ConvertTo-Json -Depth 4


# 6. PUT the updated content to GitHub
Write-Host "Sending update request to GitHub..."
try {
    $Response = Invoke-RestMethod -Uri $ApiUrlBase -Method Put -Headers $Headers -Body $JsonPayload -ContentType "application/json" -ErrorAction Stop

    Write-Host "Successfully uploaded log file to GitHub: $FilePath"
    Write-Host "New SHA: $($Response.content.sha)"

    # Optional: Delete the local log file after successful upload to start fresh
    Remove-Item $LogFilePath -Force

}
catch {
    # --- CRITICAL DIAGNOSTIC BLOCK ---
    $StatusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Failed to upload log file to GitHub. Status Code: $StatusCode."
    
    # Try to read the error body for 422 Unprocessable Entity messages
    try {
        $ResponseStream = $_.Exception.Response.GetResponseStream()
        $StreamReader = New-Object System.IO.StreamReader($ResponseStream)
        $ResponseBody = $StreamReader.ReadToEnd()
        Write-Error "GitHub Error Body: $ResponseBody"
    } catch {
        Write-Error "Could not retrieve error body."
    }
    # --- END CRITICAL DIAGNOSTIC BLOCK ---
}


Write-Host "--- GitHub Log Upload End ---"