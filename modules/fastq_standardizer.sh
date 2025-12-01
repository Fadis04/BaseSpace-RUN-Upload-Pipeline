#!/usr/bin/env bash
# ===============================================
# SAFE FASTQ Standardizer for Medibio Run Uploader
# Optimized version — preserves lanes, logs, progress
# ===============================================

standardize_fastqs() {
    local RUNFOLDER="$1"
    local LOGDIR="$2"

    log "Scanning FASTQ files under: $RUNFOLDER"

    # Collect FASTQ files
    local fastq_list=()
    while IFS= read -r -d $'\0' f; do fastq_list+=("$f"); done \
        < <(find "$RUNFOLDER" -type f -name "*.fastq.gz" -print0 2>/dev/null)

    if [[ ${#fastq_list[@]} -eq 0 ]]; then
        warn "No FASTQ found — skipping standardization."
        return 0
    fi

    log "Found ${#fastq_list[@]} FASTQ files"

    # VALID FASTQ PATTERN — DO NOT TOUCH THESE FILES
    local valid_regex='^(.+)_S[0-9]+_L[0-9]{3}_R[12]_001\.fastq\.gz$'

    # Counter ONLY for non-standard samples
    local fix_id=1
    local total=${#fastq_list[@]}

    for i in "${!fastq_list[@]}"; do
        local fq="${fastq_list[$i]}"
        local dir=$(dirname "$fq")
        local base=$(basename "$fq")

        # Progress indicator
        local progress=$(( (i+1) * 100 / total ))
        echo -ne "[INFO] Processing FASTQ ($((i+1))/${total}) — ${progress}% complete\r"

        # If file is already standard → skip
        if [[ "$base" =~ $valid_regex ]]; then
            log "[OK] Valid FASTQ — no change: $base"
            continue
        fi

        # Extract sample name
        local sample=$(echo "$base" | sed -E 's/_R[12].*//; s/.fastq.gz//')

        # Detect R1/R2
        local readtag="R1"
        if [[ "$base" =~ R2 ]]; then
            readtag="R2"
        fi

        # Preserve lane number if present (L001, L002, etc.)
        local lane=$(echo "$base" | grep -o -E 'L[0-9]{3}')
        lane=${lane:-"L001"}

        # Build NEW STANDARD NAME
        local newname="${sample}_S${fix_id}_${lane}_${readtag}_001.fastq.gz"
        local dst="$dir/$newname"

        # Avoid overwriting
        if [[ -e "$dst" ]]; then
            log "[WARN] Target exists, creating copy: $newname"
            cp -n "$fq" "$dst"
        else
            log "[FIX] Renaming $base → $newname"
            mv "$fq" "$dst"
        fi

        fix_id=$((fix_id+1))
    done

    echo -e "\n[INFO] FASTQ check & fix complete."
    log "FASTQ check & fix complete."
}

