# BaseSpace RUN Upload Pipeline

**Author:** Fadi Slimi  
**© 2025 Fadi Slimi – Medibio**  

A friendly and automated Bash pipeline to upload NGS Run folders to Illumina BaseSpace, including authentication, checksum verification, and log generation. Designed for Linux systems and client-friendly use.  

---

## Overview

This Bash script simplifies the upload of sequencing runs (Illumina MiSeq, NextSeq, NovaSeq, etc.) to BaseSpace. It automates the following steps:  

- Checks for the BaseSpace CLI (`bs`) and installs it if missing.  
- Performs user authentication via BaseSpace CLI.  
- Generates MD5 checksums for all files in the RUN folder.  
- Uploads the run to BaseSpace with a single command.  
- Provides clear color-coded terminal output and log files for easy tracking.  

---

## Features

- Automatic BaseSpace CLI installation if missing.  
- User authentication handling directly from the script.  
- MD5 checksum generation for data integrity.  
- Customizable run name and instrument type.  
- Optional flag to allow invalid read names.  
- Color-coded output for clarity (info, warnings, errors).  
- Log file generation for each upload session.  

---

## Requirements

- Linux-based OS (tested on Ubuntu 20.04+).  
- Bash shell (v4+).  
- Internet connection for BaseSpace CLI installation and authentication.  
- Illumina BaseSpace account.  

> **Note:** Windows users will need to adapt the script to PowerShell.  

---

## Usage

Copy your Bash script and the HTML documentation to your desired folder, then run the script:  
``` bash BS_run_upload_pip.sh ```

You will be prompted for:  

1. Full path to the RUN folder (e.g., `~/Runs/Run_2025-11-17`)  
2. Name of the run (default: `My_Run`)  
3. Instrument type (MiSeq, NextSeq, NovaSeq, etc.)  
4. Allow invalid read names? (yes/no, default: no)  

After confirmation, the script will:  

- Authenticate with BaseSpace CLI (if needed).  
- Generate `md5sum.txt` for all files in the run folder.  
- Upload the run to BaseSpace.  
- Save a log file in `./logs/` with all actions.  

---

## Authentication

The first time you run the script, it will prompt you to authenticate via the BaseSpace CLI:  
``` bs auth ```

You will receive a URL to open in your browser to grant access. After authentication, the script continues automatically.  

---

## Logging

All actions and messages are logged in:
``` ./logs/upload_YYYYMMDD_HHMM.log ```  


for auditing and troubleshooting purposes.  

---

## Skills & Projects

**Fadi Slimi – Bioinformatics Expertise**  

- **M2 Research Project:** Alternative splicing in speciation, in collaboration with LBBE (CNRS, Claude Bernard University, France) and Sweden. Focused on transcriptomic analysis and bioinformatics pipelines.  
- **Professional Experience:** Currently at Medibio, official Illumina partner in North Africa, working on NGS workflows, data analysis, and bioinformatics consulting. Previously at Biotools, official Oxford Nanopore Technologies partner in North Africa.  
- **Skills & Projects:** Extensive experience in NGS data analysis (Illumina & Nanopore), variant calling, functional annotation, population genetics, and database management. Developed multiple open-source bioinformatics pipelines for transcriptomics, machine learning, and general bioinformatics/statistics needs. All projects are documented and reproducible on [GitHub](https://github.com/yourusername).  
- **Tools & Languages:** Python, R, Bash, Galaxy pipelines, CRISPR/Cas data handling, BLAST, PyMOL, PLINK, and genomic databases.  

---

## License

This project is licensed under the **MIT License** – see [LICENSE](LICENSE) for details.  
© 2025 Fadi Slimi – Medibio  

---

## Contributing

Contributions are welcome! Please submit bug reports, feature requests, or pull requests via GitHub.  

---

## Example Command

``` bash BS_run_upload_pip.sh 
Enter path: ~/Runs/Run_2025-11-17
Enter run name: My_Run
Enter instrument: NextSeq2000
Allow invalid read names? no
``

---

## Notes

- Designed for client-friendly use, reproducibility, and traceability.  
- Fully supports Linux environments.  
- Easy to customize and extend for future sequencing instruments or workflow needs.  

---

## Included Files

- `upload_basespace.sh` – Main Bash pipeline script  
- HTML documentation files – user manuals and instructions  
- `README.md` – This file  
- `logs/` – Directory for automatically generated logs (created by the script)  

`

