# BaseSpace Run Uploader

**Author:** Fadi Slimi  
**© 2025 Fadi Slimi – Medibio (Official Partner Illumina – North Africa)**

A friendly and automated Bash pipeline to upload NGS Run folders to Illumina BaseSpace, including authentication, checksum verification, and log generation. Designed for Linux systems for reproducible and client-friendly use.

---

## Overview

This Bash script simplifies the upload of sequencing runs (Illumina MiSeq, NextSeq, NovaSeq, etc.) to BaseSpace. It automates the following steps:

- Checks for the BaseSpace CLI (`bs`) and installs it if missing.  
- Performs user authentication via BaseSpace CLI.  
- Optionally standardizes FASTQ file names.  
- Generates MD5 checksums for all files in the RUN folder.  
- Uploads the run to BaseSpace with a single command.  
- Provides clear color-coded terminal output and log files for easy tracking.

---

## Features

- Automatic BaseSpace CLI installation if missing.  
- User authentication handling directly from the script.  
- Optional FASTQ standardization for Illumina naming conventions.  
- Instrument detection (MiSeq, NextSeq, NovaSeq, etc.).  
- MD5 checksum generation for data integrity.  
- Retry + Resume upload in case of network failure.  
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

## Installation

Clone the repository:

```bash
git clone https://github.com/your-username/BaseSpace_RunUploader.git
cd BaseSpace_RunUploader
chmod +x BaseSpace_RunUploader_v3.3.sh
```

---

## Usage 

Run the script:

```bash
./BaseSpace_RunUploader_v3.3.sh
```

You will be prompted for:

1- Full path to the RUN folder (e.g., ~/Runs/Run_2025-11-17)

2- Name of the run (default: folder name)

3- Instrument type (MiSeq, NextSeq, NovaSeq, etc.)

4- Option to standardize FASTQ files (yes/no)

After confirmation, the script will:

* Authenticate with BaseSpace CLI (if needed).

* Generate md5sum.txt for all files in the run folder.

* Standardize FASTQ files (if chosen).

* Upload the run to BaseSpace.

* Save a log file in ./logs/ with all actions.

---

## Logging

All actions and messages are logged in:
```./logs/upload_YYYYMMDD_HHMM.log ```
for auditing and troubleshooting purposes.

## License

This project is licensed under the MIT License – see LICENSE.txt for details.
© 2025 Fadi Slimi – Medibio (Official Partner Illumina – North Africa)

## Contributing

Contributions are welcome! Please submit bug reports, feature requests, or pull requests via GitHub.

Example
```
./BaseSpace_RunUploader_v3.3.sh
Enter path: ~/Runs/Run_2025-11-17
Enter run name: My_Run
Enter instrument: NextSeq2000
Standardize FASTQ files? yes
```
## Included Files

* BaseSpace_RunUploader_v3.3.sh — Main Bash pipeline script

* LICENSE.txt — License file

* CHANGELOG.txt — Version history

* README.md — This file

* logs/ — Directory for automatically generated logs (created by the script)

* modules/ — Optional modules (if any)

## Notes

* Designed for client-friendly use, reproducibility, and traceability.

* Fully supports Linux environments.

* Easy to customize and extend for future sequencing instruments or workflow needs.
