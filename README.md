![hashcater](/static/logo.png)

<p align="center">
  <b>Automated Hashcat Wrapper for WPA/WPA2 (.hc22000) Cracking</b><br>
  Fast, smart and practical password cracking automation
</p>
<p align="center">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg">
  <img src="https://img.shields.io/badge/Hashcat-supported-orange.svg">
  <img src="https://img.shields.io/badge/platform-Windows-lightgrey.svg">
  <img src="https://img.shields.io/github/license/Bl4nsk1/HashCater">
</p>

---

# HashCater

**Automated Hashcat Cracking for WPA/WPA2 Pentests**

Thermal-safe, smart Wi-Fi hash cracking automation

## ⚡ Overview

HashCater automates **Hashcat** execution against `.hc22000` files with intelligent mask prioritization, GPU thermal protection, and ISP-based heuristics for Brazilian networks.

## 🔥 Features

- Wordlist, bruteforce, or combined attack modes
- SSID extraction directly from `.hc22000` files
- SSID-based smart mask generation
- ISP heuristics (VIVO, CLARO, TP-LINK, NET, WIFI)
- GPU thermal protection (`--hwmon-temp-abort`)
- Configurable workload and cooldown between runs
- Log file support for long sessions
- Summary report (cracked / failed)

## 🛠 Requirements

- Windows with PowerShell 5.1+
- [Hashcat](https://hashcat.net/hashcat/)
- GPU with OpenCL/CUDA support
- `.hc22000` files (use [Cap2Hash](https://github.com/Bl4nsk1/Cap2Hash) to convert captures)

## 🚀 Usage

```powershell
# Load and run (bypasses ExecutionPolicy)
$script = Get-Content '.\HashCater.ps1' -Raw
$sb = [scriptblock]::Create($script)

# Wordlist attack
& $sb -Hashs C:\handshakes -Hashcat C:\hashcat -AttackMode wordlist -Wordlist C:\wordlists

# Bruteforce
& $sb -Hashs C:\handshakes -Hashcat C:\hashcat -AttackMode bruteforce

# Both with logging
& $sb -Hashs C:\handshakes -Hashcat C:\hashcat -AttackMode both -Wordlist C:\wordlists -LogFile C:\results.log
```

## ⚙️ Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Hashs` | — | Path to `.hc22000` files |
| `-Hashcat` | — | Path to hashcat folder |
| `-AttackMode` | — | `wordlist` \| `bruteforce` \| `both` |
| `-Wordlist` | — | Path to wordlist folder |
| `-Params` | — | Extra hashcat parameters |
| `-Mode` | 22000 | Hash mode |
| `-MaskRuntime` | 600 | Seconds per mask |
| `-CooldownSeconds` | 15 | Pause between runs (GPU cooling) |
| `-TempAbort` | 90 | GPU temp limit (°C) |
| `-Workload` | 3 | Hashcat workload (1-4) |
| `-LogFile` | — | Output log path |
| `-VerboseMode` | — | Detailed command logging |

## ⚙️ Workflow

```
.hc22000 → Wordlist Attack → Bruteforce (smart masks) → Fallback (8-digit) → Result
```

## 📂 Output

```
[10:30:15] [+] Processing: network.hc22000
[10:30:15] [SSID] VIVO-A1B2
[10:30:15] [MASK] ?d?d?d?d?d?d?d?d
[10:35:20] [CRACKED - MASK] hash:12345678
[10:35:35] [DONE] Processed 5 files | Cracked: 3 | Failed: 2
```

## 📜 License

MIT License

Copyright (c) 2026 Bl4nsk1

## 👤 Author

[Bl4nsk1](https://github.com/Bl4nsk1)
