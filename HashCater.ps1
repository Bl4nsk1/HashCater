[CmdletBinding()]
param(
    [string]$Hashs,
    [string]$Hashcat,
    [switch]$HashcatHelp,
    [string]$Wordlist,

    [ValidateSet("wordlist","bruteforce","both")]
    [string]$AttackMode,

    [string]$Params,

    [int]$Mode = 22000,

    [int]$MaskRuntime = 1800,
    [int]$CooldownSeconds = 60,

    [int]$TempAbort = 80,
    [int]$GpuTempRetain = 70,

    [int]$Workload = 2,

    [string]$LogFile,

    [switch]$VerboseMode
)

function Show-Help {
    Write-Host ""
    Write-Host "HashCater - Hashcat Automation Tool" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ".\HashCater.ps1 -Hashs <path> -Hashcat <path> -AttackMode <mode>"
    Write-Host ""
}

if ($PSBoundParameters.Count -eq 0) {
    Show-Help
    exit
}

if (-not $HashcatHelp -and (-not $Hashs -or -not $Hashcat -or -not $AttackMode)) {
    Write-Host "[ERROR] Missing required parameters!" -ForegroundColor Red
    Show-Help
    exit
}

$HashcatExe = Join-Path $Hashcat "hashcat.exe"

if (-not (Test-Path $HashcatExe)) {
    throw "[ERROR] hashcat.exe not found!"
}

function Log {
    param(
        [string]$Message,
        [string]$Color = "White"
    )

    $ts = Get-Date -Format "HH:mm:ss"

    Write-Host "[$ts] $Message" -ForegroundColor $Color

    if ($LogFile) {
        "[$ts] $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
}

function Get-GpuTemperature {

    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue

    if (-not $nvidiaSmi) {
        return $null
    }

    try {

        $temp = & nvidia-smi `
            --query-gpu=temperature.gpu `
            --format=csv,noheader,nounits 2>$null |
            Select-Object -First 1

        return [int]$temp.Trim()

    }
    catch {
        return $null
    }
}

function Wait-GpuCooldown {

    while ($true) {

        $temp = Get-GpuTemperature

        if ($null -eq $temp) {
            return
        }

        if ($temp -le $GpuTempRetain) {
            return
        }

        Log "[COOLDOWN] GPU at ${temp}°C. Waiting..." Yellow

        Start-Sleep -Seconds 30
    }
}

function Get-SSID {

    param([string]$CapFile)

    try {

        $lines = Get-Content $CapFile

        foreach ($line in $lines) {

            if ($line -match "^WPA\*(01|02)\*") {

                $parts = $line -split "\*"

                if ($parts.Count -ge 6 -and $parts[5] -match "^[0-9A-Fa-f]+$") {

                    $hex = $parts[5]

                    $bytes = for ($i = 0; $i -lt $hex.Length; $i += 2) {
                        [Convert]::ToByte($hex.Substring($i, 2), 16)
                    }

                    return [Text.Encoding]::UTF8.GetString($bytes)
                }
            }
        }

        return "UNKNOWN"
    }
    catch {
        return "UNKNOWN"
    }
}

function Get-PrioritizedMasks {

    param([string]$SSID)

    $masks = @(
        "?d?d?d?d?d?d?d?d",
        "?d?d?d?d?d?d?d?d?d?d"
    )

    if ($SSID -and $SSID -ne "UNKNOWN") {

        $base = ($SSID -replace '[^a-zA-Z0-9]', '').ToLower()

        if ($base.Length -ge 4) {

            $masks += "$base@?d?d?d"
            $masks += "$base@?d?d?d?d"
        }
    }

    return $masks | Select-Object -Unique
}

function Run-Hashcat {

    param(
        [string]$Arguments
    )

    Wait-GpuCooldown

    $thermalArgs = @(
        "--hwmon-temp-abort=$TempAbort"
        "-w $Workload"
    ) -join " "

    $fullArgs = "$Arguments $thermalArgs"

    if ($VerboseMode) {
        Log "[CMD] $HashcatExe $fullArgs" DarkGray
    }

    $process = Start-Process `
        -FilePath $HashcatExe `
        -ArgumentList $fullArgs `
        -Wait `
        -PassThru `
        -NoNewWindow

    $exitCode = $process.ExitCode

    $temp = Get-GpuTemperature

    if ($temp) {
        Log "[GPU] Current temperature: ${temp}°C" Cyan
    }

    if ($exitCode -eq 255 -or $exitCode -eq -1) {
        Log "[WARN] Hashcat exited with code $exitCode" Red
    }

    Log "[COOLDOWN] Sleeping $CooldownSeconds seconds..." Yellow

    Start-Sleep -Seconds $CooldownSeconds

    return $exitCode
}

if ($HashcatHelp) {
    & $HashcatExe --help
    exit
}

if (-not (Test-Path $Hashs)) {
    throw "[ERROR] Hashs path not found!"
}

$Caps = Get-ChildItem $Hashs -Filter "*.hc22000"

if ($Caps.Count -eq 0) {
    throw "No .hc22000 files found"
}

$CrackedCount = 0

foreach ($Cap in $Caps) {

    $CapFile = $Cap.FullName

    Log "[+] Processing $CapFile" Cyan

    $SSID = Get-SSID $CapFile

    Log "[SSID] $SSID" Yellow

    $Cracked = $false

    if ($AttackMode -in @("wordlist","both") -and $Wordlist) {

        $Wordlists = Get-ChildItem $Wordlist -Filter "*.txt"

        foreach ($WL in $Wordlists) {

            Log "[WL] $($WL.Name)"

            Run-Hashcat "-m $Mode `"$CapFile`" `"$($WL.FullName)`" -a 0 $Params"

            $result = & $HashcatExe --show "$CapFile" -m $Mode --quiet

            if ($result) {

                Log "[CRACKED] $result" Green

                $Cracked = $true
                break
            }
        }
    }

    if (-not $Cracked -and $AttackMode -in @("bruteforce","both")) {

        $Masks = Get-PrioritizedMasks $SSID

        foreach ($Mask in $Masks) {

            Log "[MASK] $Mask"

            Run-Hashcat "-m $Mode `"$CapFile`" -a 3 $Mask --runtime=$MaskRuntime $Params"

            $result = & $HashcatExe --show "$CapFile" -m $Mode --quiet

            if ($result) {

                Log "[CRACKED] $result" Green

                $Cracked = $true
                break
            }
        }
    }

    if ($Cracked) {
        $CrackedCount++
    }
}

Log ""
Log "[DONE] Processed: $($Caps.Count)" Cyan
Log "[DONE] Cracked: $CrackedCount" Green
Log "[DONE] Failed: $($Caps.Count - $CrackedCount)" Yellow