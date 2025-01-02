$ErrorActionPreference = "SilentlyContinue"

# Ensure script is run as Administrator
if (-not ([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

function Get-Signature {
    param ([string[]]$FilePath)

    $Existence = Test-Path -PathType "Leaf" -Path $FilePath
    if ($Existence) {
        $Authenticode = (Get-AuthenticodeSignature -FilePath $FilePath -ErrorAction SilentlyContinue).Status
        switch ($Authenticode) {
            "Valid" { return "Valid Signature" }
            "NotSigned" { return "Invalid Signature (NotSigned)" }
            "HashMismatch" { return "Invalid Signature (HashMismatch)" }
            "NotTrusted" { return "Invalid Signature (NotTrusted)" }
            default { return "Invalid Signature (UnknownError)" }
        }
    } else {
        return "File Was Not Found"
    }
}

# Display Banner
function Display-Banner {
    Clear-Host
    Write-Host ""
    Write-Host -ForegroundColor Red "  _____  ______          __"
    Write-Host -ForegroundColor Red " |  __ \|  _ \ \        / /"
    Write-Host -ForegroundColor Red " | |__) | |_) \ \  /\  / / "
    Write-Host -ForegroundColor Red " |  _  /|  _ < \ \/  \/ /  "
    Write-Host -ForegroundColor Red " | | \ \| |_) | \  /\  /   "
    Write-Host -ForegroundColor Red " |_|  \_\____/   \/  \/    "
    Write-Host -ForegroundColor Red "                           "
    Write-Host -ForegroundColor Blue "   ScreenSharing   " -NoNewLine
    Write-Host -ForegroundColor Red "discord.gg/urrankedbedwars"
    Write-Host ""
}

# Ensure Admin Privileges
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (!(Test-Admin)) {
    Write-Warning "Please run the script as Administrator."
    Start-Sleep 5
    Exit
}

Display-Banner

$stopwatch = [Diagnostics.Stopwatch]::StartNew()

# Mount HKLM Registry Key if not mounted
if (!(Get-PSDrive -Name HKLM -PSProvider Registry)) {
    try {
        New-PSDrive -Name HKLM -PSProvider Registry -Root HKEY_LOCAL_MACHINE
    } catch {
        Write-Warning "Error mounting HKEY_Local_Machine registry."
    }
}

# Parse BAM Keys
$bamPaths = @("HKLM:\SYSTEM\CurrentControlSet\Services\bam\", "HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\")
try {
    $userSIDs = foreach ($path in $bamPaths) {
        Get-ChildItem -Path "${path}UserSettings\" | Select-Object -ExpandProperty PSChildName
    }
} catch {
    Write-Warning "Error parsing BAM key. Likely unsupported Windows version."
    Exit
}

# Retrieve TimeZone Information
$timeZoneInfo = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation"
$userTimeZone = $timeZoneInfo.TimeZoneKeyName
$userBias = -([convert]::ToInt32([Convert]::ToString($timeZoneInfo.ActiveTimeBias, 2), 2))
$userDaylightBias = -([convert]::ToInt32([Convert]::ToString($timeZoneInfo.DaylightBias, 2), 2))

# Process BAM Entries
function Process-BAMEntries {
    param ([string]$sid, [array]$paths)

    $results = @()
    foreach ($path in $paths) {
        $bamItems = Get-Item -Path "${path}UserSettings\$sid" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property
        foreach ($item in $bamItems) {
            $key = Get-ItemProperty -Path "${path}UserSettings\$sid" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $item
            if ($key.Length -eq 24) {
                $hexTimestamp = [System.BitConverter]::ToString($key[7..0]) -replace "-", ""
                $utcTime = [DateTime]::FromFileTimeUtc([Convert]::ToInt64($hexTimestamp, 16))
                $localTime = $utcTime.AddMinutes($userBias)

                $filePath = Join-Path -Path "C:" -ChildPath $item.TrimStart("\Device\HarddiskVolume")
                $signature = Get-Signature -FilePath $filePath

                $results += [PSCustomObject]@{
                    "Last Checked (Local)" = $localTime.ToString("yyyy-MM-dd HH:mm:ss")
                    "Last Checked (UTC)" = $utcTime.ToString("yyyy-MM-dd HH:mm:ss")
                    "Program" = Split-Path -Leaf $item
                    "Path" = $filePath
                    "Signature" = $signature
                    "User" = try {
                        (New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount]).Value
                    } catch {
                        "Unknown"
                    }
                    "SID" = $sid
                }
            }
        }
    }
    return $results
}

$bamEntries = @()
foreach ($sid in $userSIDs) {
    $bamEntries += Process-BAMEntries -sid $sid -paths $bamPaths
}

# Display Results
$bamEntries | Out-GridView -PassThru -Title "BAM Key Entries ($($bamEntries.Count)) - TimeZone: $userTimeZone (Bias: $userBias, Daylight Bias: $userDaylightBias)"

$stopwatch.Stop()
Write-Host ""
Write-Host "Execution time: $($stopwatch.Elapsed.TotalMinutes) minutes" -ForegroundColor Yellow
