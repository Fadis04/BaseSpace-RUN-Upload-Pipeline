#!/usr/bin/env bash
# Detect Illumina instrument from run folder

detect_instrument() {
    local RUNFOLDER="$1"
    local INST="Unknown"
    if [[ -f "$RUNFOLDER/RunParameters.xml" ]]; then
        if grep -qi 'MiSeq' "$RUNFOLDER/RunParameters.xml"; then INST='MiSeq'; fi
        if grep -qi 'NextSeq' "$RUNFOLDER/RunParameters.xml"; then INST='NextSeq'; fi
        if grep -qi 'MiniSeq' "$RUNFOLDER/RunParameters.xml"; then INST='MiniSeq'; fi
        if grep -qi 'iSeq' "$RUNFOLDER/RunParameters.xml"; then INST='iSeq'; fi
    fi
    if [[ -f "$RUNFOLDER/RunInfo.xml" ]]; then
        if grep -qi 'NovaSeq' "$RUNFOLDER/RunInfo.xml"; then INST='NovaSeq'; fi
    fi
    echo "$INST"
}
