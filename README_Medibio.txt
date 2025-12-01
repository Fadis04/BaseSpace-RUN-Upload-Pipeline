BaseSpace Run Uploader — v1.0
============================
Purpose:
  - Friendly one-click tool to upload Illumina run folders to Illumina BaseSpace.
  - Designed to be distributed to clients (technicians, labs) with minimal setup.

Contents:
  - Medibio_RunUploader.sh  (main launcher)
  - modules/                (helper modules for detection, renaming, upload, network)
  - logs/                   (runtime logs)
  - LICENSE.txt
  - CHANGELOG.txt
  - Original helper script uploaded by user: /mnt/data/BS_run_upload_pip.sh

Quickstart:
  1. Unzip the package.
  2. Make launcher executable: chmod +x Medibio_RunUploader.sh
  3. Run:
     ./Medibio_RunUploader.sh -r /path/to/run
     or non-interactive:
     ./Medibio_RunUploader.sh -r /path/to/run -n MyRun --auto

Requirements:
  - bash, coreutils (md5sum, find), curl or wget
  - GNU parallel (optional) for faster checksums
  - pigz (optional) for faster compression (not required)
  - BaseSpace CLI (the script will try to install it to $HOME/bin if missing)

Support:
  - Medibio Bioinformatics Support Team
  - contact: f.slimi@medibio.tn 
