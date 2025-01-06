$ErrorActionPreference = "SilentlyContinue"

if (-not ([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `\"$PSCommandPath`\"" -Verb RunAs
    exit
}

function Get-Signature {
    [CmdletBinding()]
    param (
        [string[]]$FilePath
    )

    $SignatureStatus = "Unknown"
    if (Test-Path -PathType Leaf -Path $FilePath) {
        $Authenticode = (Get-AuthenticodeSignature -FilePath $FilePath -ErrorAction SilentlyContinue).Status
        switch ($Authenticode) {
            "Valid" { $SignatureStatus = "Valid Signature" }
            "NotSigned" { $SignatureStatus = "Not Signed" }
            "HashMismatch" { $SignatureStatus = "Hash Mismatch" }
            "NotTrusted" { $SignatureStatus = "Not Trusted" }
            default { $SignatureStatus = "Invalid Signature (UnknownError)" }
        }
    } else {
        $SignatureStatus = "File Not Found"
    }
    return $SignatureStatus
}

if (!(Get-PSDrive -Name HKLM -PSProvider Registry)) {
    Try { New-PSDrive -Name HKLM -PSProvider Registry -Root HKEY_LOCAL_MACHINE } Catch { Write-Warning "Error Mounting HKEY_LOCAL_MACHINE"; exit }
}

function Get-BAMActivities {
    $RegistryPaths = @("HKLM:\SYSTEM\CurrentControlSet\Services\bam\", "HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\")
    $Users = @()

    Try {
        foreach ($Path in $RegistryPaths) {
            $Users += Get-ChildItem -Path "$Path\UserSettings\" | Select-Object -ExpandProperty PSChildName
        }
    } Catch {
        Write-Warning "Error Parsing BAM Key. Unsupported Windows Version."
        exit
    }

    $Activities = @()
    foreach ($UserSID in $Users) {
        Try {
            $User = (New-Object System.Security.Principal.SecurityIdentifier($UserSID)).Translate([System.Security.Principal.NTAccount]).Value
        } Catch {
            $User = "Unknown User"
        }

        foreach ($RegistryPath in $RegistryPaths) {
            $BAMItems = Get-Item -Path "$RegistryPath\UserSettings\$UserSID" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property
            foreach ($Item in $BAMItems) {
                $Key = Get-ItemProperty -Path "$RegistryPath\UserSettings\$UserSID" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Item
                if ($Key.Length -eq 24) {
                    $Hex = [System.BitConverter]::ToString($Key[7..0]) -replace "-",""
                    $TimestampUTC = [DateTime]::FromFileTime([Convert]::ToInt64($Hex, 16))
                    $FilePath = "C:" + $Item.TrimStart("\Device\HarddiskVolume")
                    $Signature = Get-Signature -FilePath $FilePath

                    $Activities += [PSCustomObject]@{
                        User            = $User
                        SID             = $UserSID
                        FilePath        = $FilePath
                        LastAccessedUTC = $TimestampUTC
                        Signature       = $Signature
                    }
                }
            }
        }
    }

    return $Activities
}

function Export-Results {
    param (
        [Parameter(Mandatory=$true)]
        [Array]$Data,
        [string]$Format = "Grid"
    )

    switch ($Format.ToLower()) {
        "csv" { $Data | Export-Csv -Path "BAM_Results.csv" -NoTypeInformation; Write-Host "Results saved to BAM_Results.csv" -ForegroundColor Green }
        "json" { $Data | ConvertTo-Json | Out-File -FilePath "BAM_Results.json"; Write-Host "Results saved to BAM_Results.json" -ForegroundColor Green }
        default { $Data | Out-GridView -PassThru -Title "BAM Activities" }
    }
}

Clear-Host
$Activities = Get-BAMActivities
if ($Activities.Count -eq 0) {
    Write-Host "No activities found." -ForegroundColor Yellow
    exit
}

Export-Results -Data $Activities -Format "Grid"

Write-Host "Script completed successfully." -ForegroundColor Cyan
