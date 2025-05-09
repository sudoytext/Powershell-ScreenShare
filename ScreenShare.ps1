$ErrorActionPreference = "SilentlyContinue"
Clear-Host

function Write-Header {
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "     RoseRBW Ranked Bedwars Screenshare       " -ForegroundColor Cyan
    Write-Host "        Script by Ytext SSer | RoseRBW        " -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
}

Write-Header
$today = Get-Date -Format "yyyy-MM-dd"
$output = "ytext.txt"
$exePaths = @()

Write-Host "`n[+] Scanning for executed EXE files today..." -ForegroundColor Cyan
$startTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime

$events = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Security-Auditing'; Id=4688; StartTime=$startTime} -ErrorAction SilentlyContinue

foreach ($event in $events) {
    $message = $event.Message
    if ($message -match "New Process Name:\s+(.+\.exe)") {
        $exePath = $matches[1].Trim()
        if ($exePaths -notcontains $exePath) {
            $exePaths += $exePath
        }
    }
}

Write-Host "[+] Checking Java version..." -ForegroundColor Cyan
$javaVersion = & java -version 2>&1 | Select-String "version"

Write-Host "[+] Searching for JDK-related tasks..." -ForegroundColor Cyan
$jdkTasks = Get-Process | Where-Object { $_.Name -like "*java*" -or $_.Name -like "*jdk*" }

Write-Host "[+] Scanning for suspicious keywords in processes..." -ForegroundColor Cyan
$susKeywords = @("vape", "vapelite", "autoclicker", "doomsday", "wurst", "impact", "future", "lambda", "ghostclient")
$matches = @()

Get-Process | ForEach-Object {
    $proc = $_
    foreach ($kw in $susKeywords) {
        if ($proc.Name -like "*$kw*") {
            $matches += "$($proc.Name) ($kw)"
        }
    }
}
Write-Host "[+] Writing results to $output..." -ForegroundColor Cyan
Set-Content $output "RoseRBW Screenshare Results - $today"
Add-Content $output "`n=============================================="
Add-Content $output "`n[+] Executed .exe files since startup:`n"
$exePaths | ForEach-Object { Add-Content $output $_ }

Add-Content $output "`n[+] Java Version:"
Add-Content $output $javaVersion

Add-Content $output "`n[+] JDK/Java-related tasks running:"
$jdkTasks | ForEach-Object { Add-Content $output "$($_.Name) - PID: $($_.Id)" }

Add-Content $output "`n[+] Suspicious Processes Found:"
if ($matches.Count -eq 0) {
    Add-Content $output "None found."
} else {
    $matches | ForEach-Object { Add-Content $output $_ }
}

Add-Content $output "`n=============================================="
Add-Content $output "Checked by Ytext SSer - RoseRBW Screenshare"

Start-Process notepad.exe $output
Write-Host "`n[✓] Everything has been checked by Ytext SSer." -ForegroundColor Cyan
Write-Host "------------------------------------------------" -ForegroundColor Cyan
Write-Host "saved ytext.txt" -ForegroundColor Cyan
Write-Host "" -ForegroundColor Cyan
Write-Host "------------------------------------------------" -ForegroundColor Cyan
Pause
