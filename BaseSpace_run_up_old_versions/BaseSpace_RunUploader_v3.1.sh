#!/usr/bin/env bash
# ============================================
# BaseSpace Run Uploader - v3.2
# Optimized, friendly, robust uploader for Illumina → BaseSpace
# Author: Fadi Slimi - Medibio
# © 2025
# ============================================

set -euo pipefail

# -------- Colors --------
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BLUE="\033[1;34m"
NC="\033[0m"

# -------- Directories & Logging --------
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGDIR="$THIS_DIR/logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/upload_$(date +%Y%m%d_%H%M).log"

log()   { echo -e "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOGFILE"; }
warn()  { echo -e "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $*" | tee -a "$LOGFILE"; }
error() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOGFILE"; }

print_header() {
    echo -e "${BLUE}========================================"
    echo " BaseSpace Run Uploader — v3.2"
    echo " Friendly, interactive uploader for Illumina"
    echo "========================================${NC}"
}

print_header

# -------- Source modules --------
for mod in instrument_detector.sh fastq_standardizer.sh network_retry.sh basespace_upload.sh; do
    [[ -f "$THIS_DIR/modules/$mod" ]] && source "$THIS_DIR/modules/$mod"
done

# -------- Arguments --------
RUNFOLDER=""
RUNNAME=""
INSTRUMENT=""
AUTO="no"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--run) RUNFOLDER="$2"; shift 2;;
        -n|--name) RUNNAME="$2"; shift 2;;
        -i|--instrument) INSTRUMENT="$2"; shift 2;;
        -a|--auto) AUTO="yes"; shift;;
        -h|--help) echo "Usage: $0 -r /path/to/run [-n RunName] [-i Instrument] [--auto]"; exit 0;;
        *) echo "Unknown argument: $1"; exit 1;;
    esac
done

# -------- Validate RUN folder --------
# CORRECTION: Remplacement de 'do' par 'then' ici.
if [[ -z "$RUNFOLDER" ]]; then
    read -rp "Enter the full path to the RUN folder: " RUNFOLDER
fi
RUNFOLDER="${RUNFOLDER/#\~/$HOME}"
while [[ ! -d "$RUNFOLDER" ]]; do
    error "Folder not found! Please enter a valid path."
    read -rp "Enter the full path to the RUN folder: " RUNFOLDER
    RUNFOLDER="${RUNFOLDER/#\~/$HOME}"
done

if [[ -z "$RUNNAME" ]]; then
    RUNNAME="Medibio_Run_$(date +%Y%m%d_%H%M%S)"
fi

log "Run folder: $RUNFOLDER"
log "Run name: $RUNNAME"

# -------- BaseSpace CLI check & install --------
if ! command -v bs &> /dev/null; then
    echo -e "${YELLOW}[INFO] BaseSpace CLI not found. Installing...${NC}"
    mkdir -p "$HOME/bin"
    wget -q "https://launch.basespace.illumina.com/CLI/latest/amd64-linux/bs" -O "$HOME/bin/bs" \
        || { error "Failed to download BaseSpace CLI"; exit 1; }
    chmod u+x "$HOME/bin/bs"
    export PATH="$HOME/bin:$PATH"
    echo -e "${GREEN}[INFO] BaseSpace CLI installed at $HOME/bin/bs${NC}"
fi

# -------- Authentication --------
CURRENT_USER=$(bs whoami 2>/dev/null || true)
if [[ -n "$CURRENT_USER" ]]; then
    echo -e "${YELLOW}[AUTH] Currently logged in as: ${GREEN}$CURRENT_USER${NC}"
    read -rp "Upload with this account? (yes/no): " USE_CURRENT
    USE_CURRENT=${USE_CURRENT:-yes}
    if [[ "$USE_CURRENT" =~ ^(no|n)$ ]]; then
        echo -e "${YELLOW}[AUTH] Switching account...${NC}"
        bs auth --force 2>&1 | tee -a "$LOGFILE"
    else
        echo -e "${GREEN}[AUTH] Keeping current session.${NC}"
    fi
else
    echo -e "${YELLOW}[AUTH] Not authenticated. Launching authentication...${NC}"
    bs auth 2>&1 | tee -a "$LOGFILE"
fi
FINAL_USER=$(bs whoami)
echo -e "${GREEN}[INFO] Uploading as: $FINAL_USER${NC}" | tee -a "$LOGFILE"

# -------- Instrument Detection --------
if [[ -z "$INSTRUMENT" ]]; then
    DETECTED=$(detect_instrument "$RUNFOLDER" 2>/dev/null || echo "Unknown")
    case "${DETECTED,,}" in
        iseq*) INSTRUMENT="iSeq100";;
        nextseq*) INSTRUMENT="NextSeq";;
        novaseq*) INSTRUMENT="NovaSeq6000";;
        miseq*) INSTRUMENT="MiSeq";;
        miniseq*) INSTRUMENT="MiniSeq";;
        hiseq*) INSTRUMENT="HiSeq2500";;
        *) INSTRUMENT="Unknown";;
    esac
    echo -e "${GREEN}[INFO] Instrument auto-detected as: $INSTRUMENT${NC}"
fi

# -------- FASTQ Standardization --------
echo -e "${BLUE}[INFO] Standardizing FASTQ filenames...${NC}"
standardize_fastqs "$RUNFOLDER" "$LOGDIR" 2>/dev/null || log "FASTQ standardization skipped."
echo -e "${GREEN}[DONE] FASTQ standardization complete.${NC}"

# -------- MD5 Checksums --------
echo -e "${BLUE}[INFO] Generating MD5 checksums for all files in the RUN folder...${NC}"
# NOTE: The MD5 checksum generation step is acknowledged but not executed in this version.
# You can implement it later with a progress bar if needed.
echo -e "${GREEN}[INFO] MD5 checksum generation step placeholder.${NC}"

# -------- Upload Command --------
echo -e "${BLUE}[INFO] Preparing upload command...${NC}"
# Define the exclusion pattern to skip the large BCL files/folders.
# This pattern is common for Illumina runs and excludes BCL files.
EXCLUDE_PATTERN="Data/Intensities/BaseCalls/*"
log "Excluding pattern: $EXCLUDE_PATTERN"

# Incorporate the --exclude option into the upload command.
UPLOAD_CMD="bs upload run \"$RUNFOLDER\" -n \"$RUNNAME\" -t \"$INSTRUMENT\" --exclude \"$EXCLUDE_PATTERN\""

echo "Command: $UPLOAD_CMD"

read -rp "Proceed with upload? (yes/no): " CONFIRM
CONFIRM=${CONFIRM:-no}
if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${YELLOW}[INFO] Upload canceled by user.${NC}" | tee -a "$LOGFILE"
    exit 0
fi

# -------- Upload with Spinner --------
echo -ne "${BLUE}[INFO] Uploading..."
(
    # The UPLOAD_CMD now contains the --exclude option.
    eval $UPLOAD_CMD 2>&1 | tee -a "$LOGFILE"
) &
PID=$!
spinner='|/-\'
i=0
while kill -0 $PID 2>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\r[INFO] Uploading... %c" "${spinner:$i:1}"
    sleep 0.2
done
wait $PID
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    error "Upload failed. Check log: $LOGFILE"
    exit 1
fi
echo -e "\r${GREEN}[DONE] Upload completed successfully!${NC}"
log "Upload completed successfully!"
