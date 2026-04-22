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
    [int]$MaskRuntime = 600,
    [switch]$VerboseMode
)

function Show-Help {
    Write-Host ""
    Write-Host "HashCater - Hashcat Automation Tool" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host ".\HashCater.ps1 -Hashs <path> -Hashcat <path> -AttackMode <mode> [options]"
    Write-Host ""
    Write-Host "Required:"
    Write-Host "  -Hashs        Path to .hc22000 files"
    Write-Host "  -Hashcat      Path to hashcat folder"
    Write-Host "  -AttackMode   wordlist | bruteforce | both"
    Write-Host ""
    Write-Host "Optional:"
    Write-Host "  -HashcatHelp  Hashcat help menu"
    Write-Host "  -Wordlist     Path to wordlists"
    Write-Host "  -Params       Extra hashcat parameters"
    Write-Host "  -Mode         Hash mode (default: 22000)"
    Write-Host "  -MaskRuntime  Runtime per mask (seconds)"
    Write-Host "  -VerboseMode  Enable detailed logs"
    Write-Host ""
    Write-Host "Example:" -ForegroundColor Yellow
    Write-Host ".\HashCater.ps1 -Hashs C:\captured_files -Hashcat C:\hashcat -AttackMode both -Wordlist C:\wl"
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

if (-not (Test-Path $Hashcat)) {
    throw "[ERROR] Hashcat path not found!"
}

$HashcatExe = Join-Path $Hashcat "hashcat.exe"

if (-not (Test-Path $HashcatExe)) {
    throw "[ERROR] hashcat.exe not found in provided path!"
}

if ($HashcatHelp) {
    Write-Host ""
    Write-Host "[INFO] Showing hashcat help..." -ForegroundColor Yellow
    Write-Host ""

    & $HashcatExe --help
    exit
}

if (-not (Test-Path $Hashs)) {
    throw "[ERROR] Hashs path not found!"
}

function Log($msg, $color="White") {
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    Write-Host "[$timestamp] $msg" -ForegroundColor $color
}

function Get-SSID($capFile) {
    try {
        $line = Get-Content $capFile -TotalCount 1

        if ($line -match "^WPA\*") {
            $parts = $line -split "\*"

            if ($parts.Count -ge 6) {
                $ssidHex = $parts[5]

                if ($ssidHex -match "^[0-9A-Fa-f]+$") {
                    return [System.Text.Encoding]::ASCII.GetString(
                        [System.Convert]::FromHexString($ssidHex)
                    )
                }
            }
        }

        return "UNKNOWN"
    }
    catch {
        return "UNKNOWN"
    }
}

function Get-PrioritizedMasks($ssid) {

    $masks = @()
    $masks += "?d?d?d?d?d?d?d?d"       
    $masks += "?d?d?d?d?d?d?d?d?d?d"
    $masks += "?l?l?l?l?l?l?d?d"
    $masks += "?l?l?l?l?d?d?d?d"

    if ($ssid -and $ssid -ne "UNKNOWN") {

        $base = ($ssid -replace '[^a-zA-Z0-9]', '').ToLower()

        if ($base.Length -ge 4) {
            $masks += "$base?d?d"
            $masks += "$base?d?d?d"
            $masks += "$base?d?d?d?d"
        }

        # heurística ISP
        if ($ssid -match "VIVO|CLARO|TP-LINK|NET|WIFI") {
            $masks = @(
                "?d?d?d?d?d?d?d?d",
                "?d?d?d?d?d?d?d?d?d?d"
            ) + $masks
        }
    }

    return $masks | Select-Object -Unique
}

function Run-Hashcat($arguments) {

    if ($VerboseMode) {
        Log "[CMD] $arguments" DarkGray
    }

    $process = Start-Process -FilePath $HashcatExe `
        -ArgumentList $arguments `
        -NoNewWindow -Wait -PassThru

    return $process.ExitCode
}

if (-not $Hashs -or -not $Hashcat -or -not $AttackMode) {
    throw "Missing required parameters"
}

$HashcatExe = Join-Path $Hashcat "hashcat.exe"

if (-not (Test-Path $HashcatExe)) {
    throw "hashcat.exe not found"
}

$Caps = Get-ChildItem $Hashs -Filter "*.hc22000"

if ($Caps.Count -eq 0) {
    throw "No .hc22000 files found"
}

foreach ($Cap in $Caps) {

    $capFile = $Cap.FullName
    Log "[+] Processing: $capFile" Cyan

    $ssid = Get-SSID $capFile
    Log "[SSID] $ssid" Yellow

    $cracked = $false

    if ($AttackMode -in @("wordlist","both") -and $Wordlist) {

        $Wordlists = Get-ChildItem $Wordlist -Filter "*.txt"

        foreach ($wl in $Wordlists) {

            Log "[WL] $($wl.Name)"

            Run-Hashcat "-m $Mode `"$capFile`" `"$($wl.FullName)`" -a 0 $Params"

            $result = & $HashcatExe --show "$capFile" -m $Mode

            if ($result) {
                Log "[CRACKED - WL]" Green
                $result
                $cracked = $true
                break
            }
        }
    }

    if ($cracked) { continue }

    if ($AttackMode -in @("bruteforce","both")) {

        $masks = Get-PrioritizedMasks $ssid

        foreach ($mask in $masks) {

            Log "[MASK] $mask"

            Run-Hashcat "-m $Mode `"$capFile`" -a 3 $mask --runtime=$MaskRuntime $Params"

            $result = & $HashcatExe --show "$capFile" -m $Mode

            if ($result) {
                Log "[CRACKED - MASK]" Green
                $result
                $cracked = $true
                break
            }
        }
    }

    if (-not $cracked) {
        Log "[FALLBACK] 8-digit numeric" Yellow

        Run-Hashcat "-m $Mode `"$capFile`" -a 3 ?d?d?d?d?d?d?d?d"

        $result = & $HashcatExe --show "$capFile" -m $Mode

        if ($result) {
            Log "[CRACKED - FALLBACK]" Green
            $result
        } else {
            Log "[FAIL] NOT FOUND" Red
        }
    }
}