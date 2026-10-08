#!/usr/bin/env bash

set -o pipefail
#PARAMS FOR HASHCAT

HASHS="/home/bl4nsk1/handshakes"
HASHCAT="/usr/bin/hashcat"
HASHCAT_HELP=false
WORDLIST=""
ATTACK_MODE="bruteforce"
PARAMS=""
MODE=22000
MASK_RUNTIME=1800
COOLDOWN_SECONDS=60
TEMP_ABORT=80
GPU_TEMP_RETAIN=70
WORKLOAD=2
LOG_FILE=""
VERBOSE_MODE=false

#HELP MESSAGE
show_help() {
    echo
    echo "HashCater - Hashcat Automation Tool"
    echo
    echo "Usage:"
    echo "  $0 -H <hashes_path> -C <hashcat_path> -A <mode>"
    echo
    echo "Options:"
    echo "  -H, --hashes <path>          Directory containing .hc22000 files"
    echo "  -C, --hashcat <path>         Hashcat directory or executable"
    echo "  -h, --hashcat-help           Show Hashcat help"
    echo "  -W, --wordlist <path>        Directory containing .txt wordlists"
    echo "  -A, --attack-mode <mode>     wordlist | bruteforce | both"
    echo "  -P, --params <args>          Additional Hashcat parameters"
    echo "  -m, --mode <mode>            Hashcat mode (default: 22000)"
    echo
    echo "  --mask-runtime <seconds>     Runtime per mask (default: 1800)"
    echo "  --cooldown <seconds>         Cooldown after successful attack (default: 60)"
    echo "  --temp-abort <temp>          Abort temperature (default: 80)"
    echo "  --gpu-temp-retain <temp>     Resume temperature (default: 70)"
    echo "  -w, --workload <level>       Hashcat workload (default: 2)"
    echo "  -l, --log <file>             Log file"
    echo "  -v, --verbose                Show executed commands"
    echo
    echo "Examples:"
    echo
    echo "  $0 -H ./hashes -C /usr/bin/hashcat -A wordlist -W ./wordlists"
    echo
    echo "  $0 -H ./hashes -C /usr/bin/hashcat -A both -W ./wordlists"
    echo
}

#CHECK ARGS
while [[ $# -gt 0 ]]; do
    case "$1" in
        -H|--hashes)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            HASHS="$2"
            shift 2
            ;;

        -C|--hashcat)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            HASHCAT="$2"
            shift 2
            ;;

        -h|--hashcat-help)
            HASHCAT_HELP=true
            shift
            ;;

        -W|--wordlist)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            WORDLIST="$2"
            shift 2
            ;;

        -A|--attack-mode)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            ATTACK_MODE="$2"
            shift 2
            ;;

        -P|--params)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            PARAMS="$2"
            shift 2
            ;;

        -m|--mode)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            MODE="$2"
            shift 2
            ;;

        --mask-runtime)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            MASK_RUNTIME="$2"
            shift 2
            ;;

        --cooldown)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            COOLDOWN_SECONDS="$2"
            shift 2
            ;;

        --temp-abort)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            TEMP_ABORT="$2"
            shift 2
            ;;

        --gpu-temp-retain)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            GPU_TEMP_RETAIN="$2"
            shift 2
            ;;

        -w|--workload)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            WORKLOAD="$2"
            shift 2
            ;;

        -l|--log)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] Missing value for $1"
                exit 1
            fi
            LOG_FILE="$2"
            shift 2
            ;;

        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;

        *)
            echo "[ERROR] Unknown parameter: $1"
            show_help
            exit 1
            ;;
    esac
done

#CHECK ARGS
if [[ "$HASHCAT_HELP" == false ]]; then
    if [[ -z "$HASHS" || -z "$HASHCAT" || -z "$ATTACK_MODE" ]]; then
        echo "[ERROR] Missing required parameters!"
        show_help
        exit 1
    fi

    case "$ATTACK_MODE" in
        wordlist|bruteforce|both)
            ;;
        *)
            echo "[ERROR] Invalid attack mode: $ATTACK_MODE"
            echo "Valid modes: wordlist, bruteforce, both"
            exit 1
            ;;
    esac
fi
#CHECK HASHCAT BINARIE
if [[ -d "$HASHCAT" ]]; then
    HASHCAT_EXE="$HASHCAT/hashcat"
elif [[ -x "$HASHCAT" ]]; then
    HASHCAT_EXE="$HASHCAT"
else
    HASHCAT_EXE="$(command -v "$HASHCAT" 2>/dev/null || true)"
fi

if [[ "$HASHCAT_HELP" == true ]]; then
    if [[ -z "$HASHCAT_EXE" ]]; then
        HASHCAT_EXE="$(command -v hashcat 2>/dev/null || true)"
    fi

    if [[ -z "$HASHCAT_EXE" ]]; then
        echo "[ERROR] hashcat executable not found!"
        exit 1
    fi

    "$HASHCAT_EXE" --help
    exit $?
fi

if [[ -z "$HASHCAT_EXE" || ! -x "$HASHCAT_EXE" ]]; then
    echo "[ERROR] hashcat executable not found!"
    exit 1
fi

PARAM_ARGS=()

if [[ -n "$PARAMS" ]]; then
    read -r -a PARAM_ARGS <<< "$PARAMS"
fi
#LOGGING
log() {
    local message="$1"
    local color="${2:-}"
    local timestamp

    timestamp=$(date '+%H:%M:%S')

    case "$color" in
        red)
            printf '\033[31m[%s] %s\033[0m\n' "$timestamp" "$message"
            ;;
        green)
            printf '\033[32m[%s] %s\033[0m\n' "$timestamp" "$message"
            ;;
        yellow)
            printf '\033[33m[%s] %s\033[0m\n' "$timestamp" "$message"
            ;;
        cyan)
            printf '\033[36m[%s] %s\033[0m\n' "$timestamp" "$message"
            ;;
        gray)
            printf '\033[90m[%s] %s\033[0m\n' "$timestamp" "$message"
            ;;
        *)
            printf '[%s] %s\n' "$timestamp" "$message"
            ;;
    esac

    if [[ -n "$LOG_FILE" ]]; then
        printf '[%s] %s\n' "$timestamp" "$message" >> "$LOG_FILE"
    fi
}
#GET GPU TEMPERATURE
get_gpu_temperature() {
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        return 1
    fi

    local temp

    temp=$(
        nvidia-smi \
            --query-gpu=temperature.gpu \
            --format=csv,noheader,nounits 2>/dev/null |
            head -n 1 |
            tr -d '[:space:]'
    )

    if [[ "$temp" =~ ^[0-9]+$ ]]; then
        echo "$temp"
        return 0
    fi

    return 1
}
#GPU COOLDOWN
wait_gpu_cooldown() {
    while true; do
        local temp

        temp=$(get_gpu_temperature) || return 0

        if (( temp <= GPU_TEMP_RETAIN )); then
            return 0
        fi

        log "[COOLDOWN] GPU at ${temp}°C. Waiting..." yellow
        sleep 30
    done
}
# GET SSID FROM HASH
get_ssid() {
    local hashfile="$1"

    while IFS= read -r line; do
        if [[ "$line" =~ ^WPA\*(01|02)\* ]]; then
            IFS='*' read -ra parts <<< "$line"

            if (( ${#parts[@]} >= 6 )); then
                local hex="${parts[5]}"

                if [[ "$hex" =~ ^[0-9A-Fa-f]+$ ]]; then
                    printf '%s' "$hex" |
                        xxd -r -p 2>/dev/null |
                        iconv -f UTF-8 -t UTF-8 2>/dev/null

                    return 0
                fi
            fi
        fi
    done < "$hashfile"

    echo "UNKNOWN"
}
#MASKS
get_prioritized_masks() {
    local ssid="$1"

    local masks=(
        '?d?d?d?d?d?d?d?d'
        '?d?d?d?d?d?d?d?d?d?d'
    )

    if [[ -n "$ssid" && "$ssid" != "UNKNOWN" ]]; then
        local base

        base=$(
            printf '%s' "$ssid" |
                tr -cd '[:alnum:]' |
                tr '[:upper:]' '[:lower:]'
        )

        if (( ${#base} >= 4 )); then
            masks+=(
                "${base}@?d?d?d"
                "${base}@?d?d?d?d"
            )
        fi
    fi

    printf '%s\n' "${masks[@]}" | awk '!seen[$0]++'
}
#RUNNING
run_hashcat() {
    wait_gpu_cooldown

    local -a arguments=("$@")

    local -a thermal_args=(
        "--hwmon-temp-abort=$TEMP_ABORT"
        "-w"
        "$WORKLOAD"
    )

    if [[ "$VERBOSE_MODE" == true ]]; then
        printf '[CMD] %q ' "$HASHCAT_EXE"
        printf '%q ' "${arguments[@]}"
        printf '%q ' "${thermal_args[@]}"
        printf '\n'
    fi

    "$HASHCAT_EXE" \
        "${arguments[@]}" \
        "${thermal_args[@]}"

    local exit_code=$?

    local temp
    temp=$(get_gpu_temperature) || true

    if [[ -n "$temp" ]]; then
        log "[GPU] Current temperature: ${temp}°C" cyan
    fi

    if (( exit_code != 0 )); then
        log "[WARN] Hashcat exited with code $exit_code" red
        return "$exit_code"
    fi

    if (( COOLDOWN_SECONDS > 0 )); then
        log "[COOLDOWN] Sleeping $COOLDOWN_SECONDS seconds..." yellow
        sleep "$COOLDOWN_SECONDS"
    fi

    return 0
}
#CHECK FILES CRACKED
check_cracked() {
    local hashfile="$1"

    local result

    result=$(
        "$HASHCAT_EXE" \
            --show \
            -m "$MODE" \
            "$hashfile" \
            --quiet 2>/dev/null
    )

    if [[ -n "$result" ]]; then
        printf '%s\n' "$result"
        return 0
    fi

    return 1

if [[ ! -d "$HASHS" ]]; then
    echo "[ERROR] Hashs path not found: $HASHS"
    exit 1
fi

mapfile -t CAPS < <(
    find "$HASHS" \
        -maxdepth 1 \
        -type f \
        -name '*.hc22000' \
        -print
)

if (( ${#CAPS[@]} == 0 )); then
    echo "No .hc22000 files found"
    exit 1
fi

CRACKED_COUNT=0

for hashfile in "${CAPS[@]}"; do

    log "[+] Processing $hashfile" cyan

    SSID=$(get_ssid "$hashfile")

    log "[SSID] $SSID" yellow

    CRACKED=false

    if [[ "$ATTACK_MODE" == "wordlist" ||
          "$ATTACK_MODE" == "both" ]] &&
       [[ -n "$WORDLIST" ]]; then

        if [[ ! -d "$WORDLIST" ]]; then

            log "[WARN] Wordlist directory not found: $WORDLIST" red

        else

            mapfile -t WORDLISTS < <(
                find "$WORDLIST" \
                    -maxdepth 1 \
                    -type f \
                    -name '*.txt' \
                    -print
            )

            if (( ${#WORDLISTS[@]} == 0 )); then
                log "[WARN] No .txt wordlists found in: $WORDLIST" yellow
            fi

            for WL in "${WORDLISTS[@]}"; do

                log "[WL] $(basename "$WL")"

                run_hashcat \
                    -m "$MODE" \
                    "$hashfile" \
                    "$WL" \
                    -a 0 \
                    "${PARAM_ARGS[@]}"

                result=$(check_cracked "$hashfile") || true

                if [[ -n "$result" ]]; then
                    log "[CRACKED] $result" green
                    CRACKED=true
                    break
                fi

            done
        fi
    fi

    if [[ "$CRACKED" == false ]] &&
       [[ "$ATTACK_MODE" == "bruteforce" ||
          "$ATTACK_MODE" == "both" ]]; then

        mapfile -t MASKS < <(
            get_prioritized_masks "$SSID"
        )

        for MASK in "${MASKS[@]}"; do

            log "[MASK] $MASK"

            run_hashcat \
                -m "$MODE" \
                "$hashfile" \
                -a 3 \
                "$MASK" \
                "--runtime=$MASK_RUNTIME" \
                "${PARAM_ARGS[@]}"

            result=$(check_cracked "$hashfile") || true

            if [[ -n "$result" ]]; then
                log "[CRACKED] $result" green
                CRACKED=true
                break
            fi

        done
    fi

    if [[ "$CRACKED" == true ]]; then
        ((CRACKED_COUNT++))
    fi

done

TOTAL=${#CAPS[@]}
FAILED=$((TOTAL - CRACKED_COUNT))

log ""
log "[DONE] Processed: $TOTAL" cyan
log "[DONE] Cracked: $CRACKED_COUNT" green
log "[DONE] Failed: $FAILED" yellow
