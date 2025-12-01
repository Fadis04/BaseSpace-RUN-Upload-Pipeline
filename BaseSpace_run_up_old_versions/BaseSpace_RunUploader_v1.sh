#!/usr/bin/env bash
# ============================================
# Friendly BaseSpace RUN Upload Pipeline
# Author: Fadi Slimi
# © 2025 Fadi Slimi - Medibio
# ============================================

# -------- Colors for friendly output --------
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BLUE="\033[1;34m"
NC="\033[0m" # No Color

# -------- Welcome Message --------
echo -e "${BLUE}========================================"
echo " Welcome to BaseSpace Upload Pipeline"
echo "      © 2025 Fadi Slimi - Medibio"
echo "========================================${NC}"

# -------- Interactive Inputs --------
read -rp "Enter the full path to the RUN folder: " RUNFOLDER
RUNFOLDER="${RUNFOLDER/#\~/$HOME}"  # expand ~ to $HOME
while [[ ! -d "$RUNFOLDER" ]]; do
    echo -e "${RED}[ERROR] Folder not found! Please enter a valid path.${NC}"
    read -rp "Enter the full path to the RUN folder: " RUNFOLDER
done

read -rp "Enter the name for this run: " RUNNAME
RUNNAME=${RUNNAME:-"My_Run"}

read -rp "Enter instrument type (e.g., MiSeq, NextSeq): " INSTRUMENT
INSTRUMENT=${INSTRUMENT:-"Unknown"}

read -rp "Allow invalid read names? (yes/no, default: no): " ALLOW_INVALID_NAMES
ALLOW_INVALID_NAMES=${ALLOW_INVALID_NAMES:-no}

# -------- Logs setup --------
LOGDIR="./logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/upload_$(date +%Y%m%d_%H%M).log"
echo -e "${GREEN}[INFO] Log file will be saved at: $LOGFILE${NC}"

# -------- Check / Install BaseSpace CLI --------
if ! command -v bs &> /dev/null; then
    echo -e "${YELLOW}[INFO] BaseSpace CLI not found. Installing...${NC}"
    mkdir -p "$HOME/bin"
    wget "https://launch.basespace.illumina.com/CLI/latest/amd64-linux/bs" -O "$HOME/bin/bs" \
        || { echo -e "${RED}[ERROR] Failed to download BaseSpace CLI${NC}"; exit 1; }
    chmod u+x "$HOME/bin/bs"
    export PATH="$HOME/bin:$PATH"
    echo -e "${GREEN}[INFO] BaseSpace CLI installed at $HOME/bin/bs${NC}"
    bs --version | tee -a "$LOGFILE"
fi

# -------- Authentication Check (Interactive) --------
CURRENT_USER=$(bs whoami 2>/dev/null)

if [[ -n "$CURRENT_USER" ]]; then
    # Un utilisateur est déjà connecté
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e "${YELLOW}[AUTH] Currently logged in as: ${GREEN}$CURRENT_USER${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    
    read -rp "Do you want to upload using this account? (yes/no): " USE_CURRENT
    USE_CURRENT=${USE_CURRENT:-yes}

    if [[ "$USE_CURRENT" == "no" ]] || [[ "$USE_CURRENT" == "n" ]]; then
        echo -e "${YELLOW}[AUTH] Switching account... Launching authentication process.${NC}"
        bs auth --force 2>&1 | tee -a "$LOGFILE"
        # Si --force n'est pas supporté par votre version de bs, utilisez simplement: bs auth
    else
        echo -e "${GREEN}[AUTH] Keeping current session.${NC}"
    fi
else
    # Personne n'est connecté
    echo -e "${YELLOW}[AUTH] Not authenticated. Launching initialization...${NC}"
    bs auth 2>&1 | tee -a "$LOGFILE"
fi

# Vérification finale de l'utilisateur
FINAL_USER=$(bs whoami)
echo -e "${GREEN}[INFO] Uploading process will run as: $FINAL_USER${NC}" | tee -a "$LOGFILE"

# -------- Generate checksums --------
echo -e "${BLUE}[INFO] Generating MD5 checksums for all files...${NC}" | tee -a "$LOGFILE"
CHECKSUM_FILE="$RUNFOLDER/md5sum.txt"
find "$RUNFOLDER" -type f -exec md5sum {} \; > "$CHECKSUM_FILE"
echo -e "${GREEN}[INFO] Checksums saved to $CHECKSUM_FILE${NC}" | tee -a "$LOGFILE"

# -------- Upload --------
UPLOAD_CMD="bs upload run \"$RUNFOLDER\" -n \"$RUNNAME\" -t \"$INSTRUMENT\""
if [[ "$ALLOW_INVALID_NAMES" == "yes" ]]; then
    UPLOAD_CMD="$UPLOAD_CMD --allow-invalid-readnames"
fi

echo -e "${BLUE}[INFO] Ready to upload! Command:${NC}"
echo "       $UPLOAD_CMD"

read -rp "Proceed with upload? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${YELLOW}[INFO] Upload canceled by user.${NC}" | tee -a "$LOGFILE"
    exit 0
fi

echo -e "${GREEN}[INFO] Uploading...${NC}" | tee -a "$LOGFILE"
eval $UPLOAD_CMD 2>&1 | tee -a "$LOGFILE"

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo -e "${RED}[ERROR] Upload failed. Check the log file: $LOGFILE${NC}" | tee -a "$LOGFILE"
    exit 1
fi

echo -e "${GREEN}[INFO] Upload completed successfully!${NC}" | tee -a "$LOGFILE"
echo -e "${BLUE}========================================${NC}"
exit 0
