#!/usr/bin/env bash
# Network and retry utilities

check_network() {
    # Basic network check - ping a reliable endpoint
    if command -v curl &>/dev/null; then
        curl -s --max-time 5 https://clients3.google.com/generate_204 >/dev/null 2>&1 && return 0 || return 1
    else
        ping -c1 8.8.8.8 >/dev/null 2>&1 && return 0 || return 1
    fi
}

wait_for_network() {
    local retries=0
    local max=60
    while ! check_network; do
        warn "No network detected. Retrying... ($retries/$max)"
        sleep 5
        retries=$((retries+1))
        if [[ $retries -ge $max ]]; then
            error "Network did not come up after $max attempts."
            return 1
        fi
    done
    log "Network OK"
    return 0
}

generate_checksums() {
    local RUNFOLDER="$1"
    local LOGDIR="$2"
    local OUTFILE="$RUNFOLDER/md5sum.txt"
    log "Generating checksums to $OUTFILE (parallel if possible)..."

    if command -v parallel &>/dev/null; then
        find "$RUNFOLDER" -type f -print0 | parallel -0 -j$(nproc) 'md5sum {}' > "$OUTFILE"
    else
        # serial fallback
        find "$RUNFOLDER" -type f -exec md5sum {} \; > "$OUTFILE"
    fi

    log "Checksums generated: $OUTFILE"
}
