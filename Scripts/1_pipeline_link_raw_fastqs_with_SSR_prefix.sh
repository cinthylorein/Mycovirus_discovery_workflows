#!/usr/bin/env bash
set -euo pipefail

####################################################################################
# Mycovirus Discovery Workflow - Step I: set up raw_reads                          #
# Author: Cinthy Jimenez-Silva (2026)                                              #
#                                                                                  #
# Description:                                                                     #
# Usage:                                                                           #
#   export RAW=/path/to/raw_reads												   #
#   bash Scripts/1_pipeline_link_raw_fastqs_with_srr_prefix.sh /input/dir          #
# What it does:                                                                    #
# - Creates symlinks for *.fastq.gz and *.fq.gz into $RAW                          #
# - Renames links so they start with "SRR" (e.g., SRR<original_filename>.fastq.gz) #
# - Does NOT modify the original files                                             #
####################################################################################


SRC_DIR="${1:?Provide source directory containing *.fastq.gz or *.fq.gz}"

RAW="${RAW:-}"
if [[ -z "$RAW" ]]; then
  echo "ERROR: RAW is not set. Example: export RAW=/workspace/$USER/.../raw_reads" >&2
  exit 1
fi

mkdir -p "$RAW"

shopt -s nullglob

# Collect both extensions
files=( "$SRC_DIR"/*.fastq.gz "$SRC_DIR"/*.fq.gz )
if (( ${#files[@]} == 0 )); then
  echo "ERROR: No *.fastq.gz or *.fq.gz files found in: $SRC_DIR" >&2
  exit 1
fi

for f in "${files[@]}"; do
  base="$(basename "$f")"

  # Normalize read suffix for either extension:
  #   _R1.fastq.gz -> _R_1.fastq.gz
  #   _R2.fastq.gz -> _R_2.fastq.gz
  #   _R1.fq.gz    -> _R_1.fq.gz
  #   _R2.fq.gz    -> _R_2.fq.gz
  norm="$base"
  norm="${norm/_1.fastq.gz/_1.fastq.gz}"
  norm="${norm/_2.fastq.gz/_2.fastq.gz}"
  norm="${norm/_1.fq.gz/_1.fq.gz}"
  norm="${norm/_2.fq.gz/_2.fq.gz}"

  # Add SRR prefix (avoid double-prefixing)
  if [[ "$norm" == SRR* ]]; then
    link_name="$norm"
  else
    link_name="SRR${norm}"
  fi

  dest="${RAW}/${link_name}"

  # Create/replace symlink safely
  ln -sfn "$f" "$dest"
done

echo "Linked ${#files[@]} FASTQ files into: $RAW"
echo "Example:"
ls -l "$RAW" | head