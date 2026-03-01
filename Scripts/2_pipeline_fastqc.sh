#!/usr/bin/env bash

set -euo pipefail

# Submitter for FastQC array jobs (dynamic array size, robust export of file list)

echo "Defining global variables and directories"

RAW_DIR="/workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads"
FASTQC_OUT="/workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc"
threads=2

# Avoid literal expansion when no files are present
shopt -s nullglob

# Build array of fastq files (glob will return nothing if no matches)
files=( "$RAW_DIR"/*.fastq )

if (( ${#files[@]} == 0 )); then
    echo "No .fastq files found in ${RAW_DIR}. Aborting." >&2
    exit 1
fi

# Compute array range: 0..N-1
num_files=${#files[@]}
array_range="0-$((num_files - 1))"

# Write file list to a temp file so the array can be reconstructed in the job
file_list=$(mktemp -t fastqc_filelist.XXXXXX)
printf "%s\n" "${files[@]}" > "$file_list"

echo "Submitting FastQC jobs for files in: ${RAW_DIR}"
echo "  Found ${num_files} files; using SLURM array ${array_range}"
echo "  File list written to: ${file_list}"
echo "  FastQC output dir: ${FASTQC_OUT}"
echo

# Submit job; use --parsable so sbatch returns just the jobid
jobid=$(sbatch --parsable --export=FILE_LIST="$file_list",FASTQC_OUT="$FASTQC_OUT",threads="$threads" --array="$array_range" 2_pipeline_fastqc.slurm)

echo " Submitted jobs:"
echo "   └─ FastQC array Job ID: $jobid"
echo " Monitor with: sacct -j $jobid"
echo " To view per-task logs check the files in your logs/ directory configured in the .slurm script."
