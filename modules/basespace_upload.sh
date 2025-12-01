#!/usr/bin/env bash
# BaseSpace upload wrapper with automatic retry and resume behaviour
# Relies on 'bs' CLI being in PATH (the script will try to install it if missing)

ensure_basespace_cli() {
    local LOGDIR="$1"
    if command -v bs &>/dev/null; then
        log "BaseSpace CLI found: $(which bs)"
        return 0
    fi
    warn "BaseSpace CLI not found. Attempting to download to $HOME/bin..."
    mkdir -p "$HOME/bin"
    if curl -fsSL -o "$HOME/bin/bs" "https://launch.basespace.illumina.com/CLI/latest/amd64-linux/bs" || wget -q -O "$HOME/bin/bs" "https://launch.basespace.illumina.com/CLI/latest/amd64-linux/bs"; then
        chmod +x "$HOME/bin/bs"
        export PATH="$HOME/bin:$PATH"
        log "Installed BaseSpace CLI to $HOME/bin/bs"
        return 0
    fi
    error "Failed to install BaseSpace CLI automatically. Please install 'bs' and re-run."
    return 1
}

# Check if connected to BaseSpace CLI and show account info
check_bs_connection() {
    if ! command -v bs &> /dev/null; then
        error "BaseSpace CLI not found. Please install it first."
        exit 1
    fi

    USER_INFO=$(bs whoami 2>&1)
    if [[ $? -eq 0 ]]; then
        log "✅ Connected to BaseSpace."
        log "Account info: $USER_INFO"
    else
        error "❌ Not connected to BaseSpace. Please run 'bs authenticate' to log in."
        exit 1
    fi
}

upload_with_retry() {
    local RUNFOLDER="$1"
    local RUNNAME="$2"
    local INSTRUMENT="$3"
    local LOGDIR="$4"
    local AUTO="$5"

    local CMD="bs upload run \"$RUNFOLDER\" -n \"$RUNNAME\" -t \"$INSTRUMENT\""

    # Remove the --allow-invalid-readnames flag entirely

    local attempt=0
    local max_attempts=10
    local delay=5

    # Ensure network before starting
    wait_for_network || return 1

    while [[ $attempt -lt $max_attempts ]]; do
        attempt=$((attempt+1))
        log "Starting upload attempt $attempt/$max_attempts"
        # Run upload while streaming logs
        if eval $CMD 2>&1 | tee -a "$LOGDIR/bs_upload_$(date +%Y%m%d_%H%M%S).log"; then
            log "Upload successful on attempt $attempt"
            return 0
        fi

        warn "Upload attempt $attempt failed. Will retry after $delay seconds..."
        sleep $delay
        delay=$((delay * 2))
        # wait for network before next try
        wait_for_network || { warn "Network gone; will retry when back."; }
    done

    error "Upload failed after $max_attempts attempts."
    return 1
}
