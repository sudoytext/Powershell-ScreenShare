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

function Get-PrefetchData {
    $PrefetchFolder = "$env:SystemRoot\Prefetch"
    $PrefetchData = @()

    if (Test-Path $PrefetchFolder) {
        $PrefetchFiles = Get-ChildItem -Path $PrefetchFolder -Filter "*.pf" -ErrorAction SilentlyContinue
        foreach ($File in $PrefetchFiles) {
            $LastRunTime = $File.LastWriteTime
            $PrefetchData += [PSCustomObject]@{
                FileName       = $File.Name
                DirectoryPath  = $File.DirectoryName
                LastRunTimeUTC = $LastRunTime
            }
        }
    } else {
        Write-Warning "Prefetch folder not found."
    }

    return $PrefetchData
}

function Show-GUI {
    param (
        [Parameter(Mandatory=$true)]
        [Array]$Data
    )

    Add-Type -AssemblyName PresentationFramework

    $Window = New-Object system.windows.window
    $Window.Title = "BAM and Prefetch Viewer"
    $Window.Width = 800
    $Window.Height = 600
    $Window.ResizeMode = "CanMinimize"

    $Grid = New-Object system.windows.controls.grid
    $Window.Content = $Grid

    $DataGrid = New-Object system.windows.controls.datagrid
    $DataGrid.ItemsSource = $Data
    $DataGrid.AutoGenerateColumns = $true
    $DataGrid.CanUserAddRows = $false
    $DataGrid.CanUserResizeColumns = $true
    $DataGrid.CanUserResizeRows = $true
    $DataGrid.Margin = "10,10,10,50"
    $Grid.Children.Add($DataGrid)

    $ExportButton = New-Object system.windows.controls.button
    $ExportButton.Content = "Export to CSV"
    $ExportButton.Width = 100
    $ExportButton.Height = 30
    $ExportButton.HorizontalAlignment = "Right"
    $ExportButton.VerticalAlignment = "Bottom"
    $ExportButton.Margin = "0,0,10,10"
    $ExportButton.Add_Click({
        $Data | Export-Csv -Path "Results.csv" -NoTypeInformation
        [System.Windows.MessageBox]::Show("Results exported to Results.csv")
    })
    $Grid.Children.Add($ExportButton)

    $Window.ShowDialog() | Out-Null
}

Clear-Host
$BAMActivities = Get-BAMActivities
$PrefetchData = Get-PrefetchData

$CombinedData = $BAMActivities + $PrefetchData
if ($CombinedData.Count -eq 0) {
    Write-Host "No data found." -ForegroundColor Yellow
    exit
}

Show-GUI -Data $CombinedData

Write-Host "Script completed successfully." -ForegroundColor Cyan
