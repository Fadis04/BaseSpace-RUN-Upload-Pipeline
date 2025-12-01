#!/usr/bin/env bash
# ======================================================================
# BaseSpace Run Uploader — v3.3 Professional Edition
# Developed by: Fadi SLIMI © 2025 — Medibio / Illumina Integrations
# Features:
#   - FASTQ verification & standardization
#   - Auto-detect instrument
#   - BaseSpace authentication & account switch
#   - Retry + Resume upload
# ======================================================================

set -euo pipefail

# ==========================
# Colors
# ==========================
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
NC="\033[0m"

# ==========================
# Header
# ==========================
echo -e "${CYAN}===================================================================="
echo -e "        BaseSpace Run Uploader — v3.3 Professional Edition"
echo -e "   FASTQ standardization • Auto-instrument detection • Fail-safe"
echo -e "   Developed by: ${GREEN}Fadi SLIMI © 2025${NC}"
echo -e "====================================================================${NC}\n"

# ==========================
# Retry Settings
# ==========================
RETRY_MAX=20
RETRY_WAIT=15
PING_TEST="basespace.illumina.com"

# ==========================
# Utility functions
# ==========================
log() { echo -e "[INFO] $1"; }
warn() { echo -e "[WARN] $1"; }
err() { echo -e "${RED}[ERROR] $1${NC}"; }

# ==========================
# 1. BaseSpace CLI INSTALLATION
# ==========================
install_bs_cli() {
    echo -e "${YELLOW}[INSTALL] BaseSpace CLI non trouvé — installation en cours...${NC}"
    mkdir -p "$HOME/bin"
    local DEST="$HOME/bin/bs"
    wget -q "https://launch.basespace.illumina.com/CLI/latest/amd64-linux/bs" -O "$DEST" \
        || { err "Téléchargement BaseSpace CLI échoué"; exit 1; }
    chmod +x "$DEST"
    [[ ":$PATH:" != *":$HOME/bin:"* ]] && echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    echo -e "${GREEN}[INSTALL] BaseSpace CLI installé avec succès.${NC}"
}
if ! command -v bs >/dev/null 2>&1; then install_bs_cli; fi

# ==========================
# 2. AUTHENTIFICATION & SWITCH DE COMPTE
# ==========================
echo -e "${BLUE}[AUTH] Vérification du compte BaseSpace actif...${NC}"

CURRENT=$(bs whoami 2>/dev/null || true)

clean_bs_session() {
    mv "$HOME/.basespace/default.cfg" "$HOME/.basespace/default.cfg.bak_$(date +%H%M%S)" 2>/dev/null || true
}

if [[ -n "$CURRENT" ]]; then
    USER=$(echo "$CURRENT" | grep "Name" | awk -F '|' '{print $3}' | xargs)
    EMAIL=$(echo "$CURRENT" | grep "Email" | awk -F '|' '{print $3}' | xargs)
    ID=$(echo "$CURRENT" | grep "Id" | awk -F '|' '{print $3}' | xargs)

    echo -e "${GREEN}[AUTH] Compte actif détecté:${NC}"
    echo -e "   👤 Nom:   ${CYAN}$USER${NC}"
    echo -e "   📧 Email: ${CYAN}$EMAIL${NC}"
    echo -e "   🆔 ID:     ${CYAN}$ID${NC}\n"

    read -rp "Voulez-vous utiliser ce compte ? (yes/no): " CH
    CH=${CH:-yes}
    if [[ "$CH" =~ ^n|no$ ]]; then
        clean_bs_session
        echo -e "${YELLOW}[AUTH] Nouvelle session en cours...${NC}"
        bs auth --force
    fi
else
    echo -e "${YELLOW}[AUTH] Pas de session active → Authentification nécessaire...${NC}"
    bs auth --force
fi

FINAL=$(bs whoami)
FINAL_USER=$(echo "$FINAL" | grep "Name" | awk -F '|' '{print $3}' | xargs)
FINAL_EMAIL=$(echo "$FINAL" | grep "Email" | awk -F '|' '{print $3}' | xargs)
FINAL_ID=$(echo "$FINAL" | grep "Id" | awk -F '|' '{print $3}' | xargs)

echo -e "${GREEN}[AUTH] Connecté en tant que:${NC}"
echo -e "   👤 Nom:   ${CYAN}$FINAL_USER${NC}"
echo -e "   📧 Email: ${CYAN}$FINAL_EMAIL${NC}"
echo -e "   🆔 ID:     ${CYAN}$FINAL_ID${NC}\n"

# ==========================
# 3. RUN SELECTION
# ==========================
read -rp "Chemin complet du RUN folder: " RUN
RUN="${RUN/#\~/$HOME}"
RUN="${RUN%/}"
[[ ! -d "$RUN" ]] && { err "Ce dossier n'existe pas."; exit 1; }

DEFAULT_NAME=$(basename "$RUN")
read -rp "Nom du RUN (Default: $DEFAULT_NAME): " NAME
NAME=${NAME:-$DEFAULT_NAME}
echo -e "${GREEN}[INFO] RUN sélectionné → $RUN${NC}"

# ==========================
# 4. FASTQ STANDARDIZER (v4.2 optimized)
# ==========================
fastq_standardizer() {
    local RUNFOLDER="$1"
    local LOGDIR="$RUNFOLDER/fastq_standardizer_logs"
    mkdir -p "$LOGDIR"
    local LOGFILE="$LOGDIR/fastq_standardizer_$(date +%Y%m%d_%H%M%S).log"

    log() { echo -e "[INFO] $1" | tee -a "$LOGFILE"; }
    warn() { echo -e "[WARN] $1" | tee -a "$LOGFILE"; }

    log "Scanning FASTQ files in: $RUNFOLDER"

    mapfile -d $'\0' fastq_list < <(find "$RUNFOLDER" -type f -name "*.fastq.gz" -print0 2>/dev/null)
    [[ ${#fastq_list[@]} -eq 0 ]] && { warn "No FASTQ files found — skipping standardization."; return; }

    log "Found ${#fastq_list[@]} FASTQ files."

    local valid_regex='^(.+)_S[0-9]+_L[0-9]{3}_R[12]_001\.fastq\.gz$'
    local fix_id=1
    local total=${#fastq_list[@]}
    declare -A sample_ids

    for i in "${!fastq_list[@]}"; do
        local fq="${fastq_list[$i]}"
        local dir=$(dirname "$fq")
        local base=$(basename "$fq")

        local progress=$(( (i+1)*100/total ))
        echo -ne "[INFO] Processing ($((i+1))/${total}) — ${progress}%\r"

        [[ "$base" =~ $valid_regex ]] && { log "Valid FASTQ — $base"; continue; }

        local sample=$(echo "$base" | sed -E 's/_R[12].*//; s/.fastq.gz//')
        local readtag="R1"; [[ "$base" =~ R2 ]] && readtag="R2"
        local lane=$(echo "$base" | grep -o -E 'L[0-9]{3}'); lane=${lane:-"L001"}

        # Assign consistent S ID per sample
        if [[ -z "${sample_ids[$sample]+x}" ]]; then
            sample_ids[$sample]=$fix_id
            fix_id=$((fix_id+1))
        fi
        local S_ID=${sample_ids[$sample]}

        local newname="${sample}_S${S_ID}_${lane}_${readtag}_001.fastq.gz"
        local dst="$dir/$newname"

        if [[ -e "$dst" ]]; then
            log "Target exists, creating copy: $newname"
            cp -n "$fq" "$dst"
        else
            log "Renaming $base → $newname"
            mv "$fq" "$dst"
        fi
    done

    echo -e "\n[INFO] FASTQ standardization complete."
    log "FASTQ standardization complete."
}

read -rp "Voulez-vous standardiser les FASTQ avant upload ? (yes/no): " STD
STD=${STD:-yes}
[[ "$STD" =~ ^y|yes$ ]] && fastq_standardizer "$RUN"

# ==========================
# 5. INSTRUMENT DETECTION
# ==========================
detect_instrument() {
    local folder="$1"
    [[ -f "$folder/RunParameters.xml" ]] && {
        if grep -qi "NextSeq2000" "$folder/RunParameters.xml"; then echo "NextSeq2000"; return; fi
        if grep -qi "NextSeq1000" "$folder/RunParameters.xml"; then echo "NextSeq1000"; return; fi
        if grep -qi "NovaSeqXPlus" "$folder/RunParameters.xml"; then echo "NovaSeqXPlus"; return; fi
        if grep -qi "NovaSeqX" "$folder/RunParameters.xml"; then echo "NovaSeqX"; return; fi
        if grep -qi "NovaSeq" "$folder/RunParameters.xml"; then echo "NovaSeq6000"; return; fi
        if grep -qi "MiSeq" "$folder/RunParameters.xml"; then echo "MiSeq"; return; fi
        if grep -qi "iSeq" "$folder/RunParameters.xml"; then echo "iSeq100"; return; fi
    }
    [[ -f "$folder/RunInfo.xml" ]] && {
        if grep -qi "MiSeq" "$folder/RunInfo.xml"; then echo "MiSeq"; return; fi
        if grep -qi "NextSeq" "$folder/RunInfo.xml"; then echo "NextSeq"; return; fi
        if grep -qi "NovaSeq" "$folder/RunInfo.xml"; then echo "NovaSeq6000"; return; fi
    }
    local name=$(basename "$folder")
    [[ "$name" =~ NH ]] && echo "NextSeq2000" && return
    [[ "$name" =~ AHC ]] && echo "NextSeq2000" && return
    echo "Unknown"
}

INSTRUMENT=$(detect_instrument "$RUN")
case "$INSTRUMENT" in
    NextSeq*) VALID_INSTR="NextSeq2000" ;;
    NovaSeqXPlus) VALID_INSTR="NovaSeqXPlus" ;;
    NovaSeq*) VALID_INSTR="NovaSeq6000" ;;
    MiSeq*) VALID_INSTR="MiSeq" ;;
    iSeq*) VALID_INSTR="iSeq100" ;;
    *) VALID_INSTR="NextSeq2000" ;;
esac

echo -e "${BLUE}[INFO] Instrument détecté: ${GREEN}$INSTRUMENT${NC}"
echo -e "${BLUE}[INFO] Instrument utilisé pour BaseSpace: ${CYAN}$VALID_INSTR${NC}\n"

# ==========================
# 6. UPLOAD COMMAND
# ==========================
CMD="bs upload run \"$RUN\" -n \"$NAME\" -t \"$VALID_INSTR\" --exclude \"Data/Intensities/BaseCalls/*\""
echo -e "${YELLOW}[UPLOAD] Commande générée:${NC}"
echo -e "   $CMD\n"

read -rp "Voulez-vous lancer l’upload ? (yes/no): " GO
GO=${GO:-no}
[[ "$GO" != "yes" ]] && { echo -e "${RED}[INFO] Upload annulé.${NC}"; exit 0; }

# ==========================
# 7. UPLOAD WITH RETRY
# ==========================
upload_with_retry() {
    local cmd="$1"
    local attempt=1

    echo -e "${BLUE}[UPLOAD] Démarrage upload intelligent (resume + retry)...${NC}"

    while [[ $attempt -le $RETRY_MAX ]]; do
        echo -e "${CYAN}[UPLOAD] Tentative $attempt/$RETRY_MAX...${NC}"

        if ! ping -c1 -W2 "$PING_TEST" &>/dev/null; then
            echo -e "${RED}[NETWORK] Internet non disponible. Attente...${NC}"
            while ! ping -c1 -W2 "$PING_TEST" &>/dev/null; do sleep 5; done
            echo -e "${GREEN}[NETWORK] Internet restauré. Reprise de l’upload...${NC}"
        fi

        eval $cmd && { echo -e "${GREEN}[SUCCESS] Upload terminé avec succès !${NC}"; return 0; }

        echo -e "${RED}[ERROR] Upload échoué (tentative $attempt).${NC}"
        echo -e "${YELLOW}[RETRY] Nouvelle tentative dans $RETRY_WAIT secondes...${NC}"
        sleep $RETRY_WAIT
        ((attempt++))
    done

    echo -e "${RED}[FATAL] Nombre maximal de tentatives atteint — upload impossible.${NC}"
    exit 1
}

upload_with_retry "$CMD"

exit 0
