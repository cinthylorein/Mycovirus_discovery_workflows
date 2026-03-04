#!/bin/bash

#This script allows us to run fastqc fr the raw and trimmed (included removed reads)

#SBATCH -J fastqc_array
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --time=00:10:00
#SBATCH --mail-type=ALL

set -euo pipefail
set -x

: "${CONFIG:?CONFIG not set}"
source "$CONFIG"

# Load the FastQC module:
module load FastQC/0.12.1

mkdir -p "$FASTQC_DIR"

# Build list of files inside the job (don’t pass arrays through sbatch)
mapfile -t files < <(ls -1 "$RAW_DIR"/*.fastq* 2>/dev/null || true)

if (( ${#files[@]} == 0 )); then
  echo "ERROR: No FASTQ files found in RAW_DIR=$RAW_DIR" >&2
  exit 1
fi

file="${files[$SLURM_ARRAY_TASK_ID]:-}"

if [[ -z "$file" ]]; then
  echo "ERROR: No file for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID" >&2
  echo "files count=${#files[@]}" >&2
  exit 1
fi


threads="${SLURM_CPUS_PER_TASK:-2}"

echo "Running FastQC on: $file"

fastqc --nogroup -q -t "$threads" -o "$FASTQC_DIR" "$file"

printf "All jobs finished.\n"


# Unloading 

module unload FastQC/0.12.1
   

