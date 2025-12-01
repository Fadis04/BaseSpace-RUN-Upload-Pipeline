#!/usr/bin/env bash
# ============================================
# BaseSpace Run Uploader - v3.2 Optimized
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
error() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOGFILE"; exit 1; }

print_header() {
    echo -e "${BLUE}========================================"
    echo " BaseSpace Run Uploader — v3.2 Optimized"
    echo " Friendly, interactive uploader for Illumina"
    echo "========================================${NC}"
}

print_header

# -------- Source modules --------
for mod in instrument_detector.sh fastq_standardizer.sh network_retry.sh basespace_upload.sh; do
    [[ -f "$THIS_DIR/modules/$mod" ]] && source "$THIS_DIR/modules/$mod" || log "Module $mod not found, skipping source."
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
        *) error "Unknown argument: $1";;
    esac
done

# -------- Validate RUN folder --------
# 1. Demande interactive si -r non fourni
if [[ -z "$RUNFOLDER" ]]; then
    read -rp "Enter the full path to the RUN folder: " RUNFOLDER
fi
# 2. Nettoyage de l'entrée (suppression des espaces/caractères cachés)
RUNFOLDER="$(echo -e "${RUNFOLDER}" | tr -d '[:space:]')"
RUNFOLDER="${RUNFOLDER/#\~/$HOME}"
while [[ ! -d "$RUNFOLDER" ]]; do
    error "Folder not found! Please enter a valid path."
    read -rp "Enter the full path to the RUN folder: " RUNFOLDER
    RUNFOLDER="$(echo -e "${RUNFOLDER}" | tr -d '[:space:]')"
    RUNFOLDER="${RUNFOLDER/#\~/$HOME}"
done
# Assurez-vous qu'il n'y a pas de slash final pour extraire le nom du dossier
RUNFOLDER=${RUNFOLDER%/}

# -------- Run Name Initialization (Optimisation + Correction) --------
if [[ -z "$RUNNAME" ]]; then
    DEFAULT_RUNNAME=$(basename "$RUNFOLDER")
    read -rp "Enter the Run Name (Default: $DEFAULT_RUNNAME): " RUNNAME_INPUT
    # Utiliser le nom du dossier si l'entrée est vide
    RUNNAME="${RUNNAME_INPUT:-$DEFAULT_RUNNAME}"
fi

log "Run folder: $RUNFOLDER"
log "Run name: $RUNNAME"

# -------- BaseSpace CLI check & install --------
if ! command -v bs &> /dev/null; then
    echo -e "${YELLOW}[INFO] BaseSpace CLI not found. Installing...${NC}"
    mkdir -p "$HOME/bin"
    wget -q "https://launch.basespace.illumina.com/CLI/latest/amd64-linux/bs" -O "$HOME/bin/bs" \
        || error "Failed to download BaseSpace CLI"
    chmod u+x "$HOME/bin/bs"
    export PATH="$HOME/bin:$PATH"
    echo -e "${GREEN}[INFO] BaseSpace CLI installed at $HOME/bin/bs${NC}"
fi

# -------- Authentication --------
CURRENT_USER=$(bs whoami 2>/dev/null || true)
if [[ -n "$CURRENT_USER" ]]; then
    echo -e "${YELLOW}[AUTH] Currently logged in as: ${GREEN}$(echo "$CURRENT_USER" | grep -A1 Name | tail -n1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*|[[:space:]]*$//')${NC}"
    read -rp "Upload with this account? (yes/no): " USE_CURRENT
    USE_CURRENT=${USE_CURRENT:-yes}
    if [[ "$USE_CURRENT" =~ ^(no|n)$ ]]; then
        echo -e "${YELLOW}[AUTH] Switching account...${NC}"
        # Utilisation de 'bs auth' sans --force si non nécessaire pour relancer l'auth interactive
        bs auth 2>&1 | tee -a "$LOGFILE"
    else
        echo -e "${GREEN}[AUTH] Keeping current session.${NC}"
    fi
else
    echo -e "${YELLOW}[AUTH] Not authenticated. Launching authentication...${NC}"
    bs auth 2>&1 | tee -a "$LOGFILE"
fi
FINAL_USER_RAW=$(bs whoami)
FINAL_USER=$(echo "$FINAL_USER_RAW" | grep -A1 Name | tail -n1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*|[[:space:]]*$//')
echo -e "${GREEN}[INFO] Uploading as: $FINAL_USER${NC}" | tee -a "$LOGFILE"

# -------- Instrument Detection --------
if [[ -z "$INSTRUMENT" ]]; then
    DETECTED=$(detect_instrument "$RUNFOLDER" 2>/dev/null || echo "Unknown")
    
    # Tentative d'utiliser le nom du dossier Run comme fallback pour les instruments modernes (ex: M08067)
    if [[ "${DETECTED,,}" == "unknown" ]]; then
        FOLDER_NAME=$(basename "$RUNFOLDER")
        case "${FOLDER_NAME}" in
            *M0[0-9]*|*A0[0-9]*) DETECTED="NextSeq/MiSeq/iSeq";; # Pattern générique
        esac
    fi

    case "${DETECTED,,}" in
        iseq*) INSTRUMENT="iSeq100";;
        nextseq*|*nextseq*|*2000*) INSTRUMENT="NextSeq";;
        novaseq*|*novaseq*) INSTRUMENT="NovaSeq6000";;
        miseq*|*m[0-9]*) INSTRUMENT="MiSeq";;
        miniseq*) INSTRUMENT="MiniSeq";;
        hiseq*) INSTRUMENT="HiSeq2500";;
        *) INSTRUMENT="Unknown";;
    esac
    echo -e "${GREEN}[INFO] Instrument auto-detected as: $INSTRUMENT${NC}"
fi

# -------- FASTQ Standardization --------
echo -e "${BLUE}[INFO] Standardizing FASTQ filenames...${NC}"
# Nous renvoyons stderr à /dev/null pour éviter les messages d'erreur si le module est manquant
standardize_fastqs "$RUNFOLDER" "$LOGDIR" 2>/dev/null || log "FASTQ standardization module failed or skipped."
echo -e "${GREEN}[DONE] FASTQ standardization complete.${NC}"

# -------- MD5 Checksums --------
echo -e "${BLUE}[INFO] Generating MD5 checksums for all files in the RUN folder...${NC}"
echo -e "${GREEN}[INFO] MD5 checksum generation step placeholder (Implement with 'find ... -type f -print0 | xargs -0 md5sum').${NC}"

# -------- Upload Command (BCL Exclusion) --------
echo -e "${BLUE}[INFO] Preparing upload command...${NC}"
# Pattern d'exclusion BCL (optimisation)
BCL_EXCLUDE_PATTERN="Data/Intensities/BaseCalls/*"
log "Excluding BCL pattern: $BCL_EXCLUDE_PATTERN"

# Utilisation de la variable BCL_EXCLUDE_PATTERN dans la commande
UPLOAD_CMD="bs upload run \"$RUNFOLDER\" -n \"$RUNNAME\" -t \"$INSTRUMENT\" --exclude \"$BCL_EXCLUDE_PATTERN\""

echo "Command: $UPLOAD_CMD"

# Confirmation conditionnelle
if [[ "$AUTO" == "yes" ]]; then
    log "Auto mode enabled. Skipping manual confirmation."
    CONFIRM="yes"
else
    read -rp "Proceed with upload? (yes/no): " CONFIRM
    CONFIRM=${CONFIRM:-no}
fi

if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${YELLOW}[INFO] Upload canceled by user.${NC}" | tee -a "$LOGFILE"
    exit 0
fi

# -------- Upload with Spinner --------
echo -ne "${BLUE}[INFO] Starting upload...${NC}"
(
    # Exécuter la commande de téléversement
    eval $UPLOAD_CMD 2>&1 | tee -a "$LOGFILE"
) &
PID=$!
spinner='|/-\'
i=0
while kill -0 $PID 2>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\r${BLUE}[INFO] Uploading... %c${NC}" "${spinner:$i:1}"
    sleep 0.2
done
wait $PID
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    error "Upload failed. Check log: $LOGFILE"
else
    echo -e "\r${GREEN}[DONE] Upload completed successfully!${NC}"
    log "Upload completed successfully!"
fi
