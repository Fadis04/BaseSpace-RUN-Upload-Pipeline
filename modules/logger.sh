#!/usr/bin/env bash
# Logger utilities for Medibio Run Uploader

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log() {
    echo -e "$(timestamp) [INFO] $*"
    echo "$(timestamp) [INFO] $*" >> "$LOGDIR/medibio_uploader.log"
}

warn() {
    echo -e "$(timestamp) [WARN] $*"
    echo "$(timestamp) [WARN] $*" >> "$LOGDIR/medibio_uploader.log"
}

error() {
    echo -e "$(timestamp) [ERROR] $*"
    echo "$(timestamp) [ERROR] $*" >> "$LOGDIR/medibio_uploader.log"
}
