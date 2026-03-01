#!/usr/bin/env bash
#
# SLURM script for running FastQC on an array of files.
# The --array is supplied by the submitter (pipeline_fastqc.sh)
#
#SBATCH -J fastqc_array
#SBATCH -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/fastqc_%A_%a.out
#SBATCH -e /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/fastqc_%A_%a.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --time=00:10:00

# FILE_LIST, FASTQC_OUT and threads are exported from the submit script
if [[ -z "${FILE_LIST:-}" ]]; then
    echo "ERROR: FILE_LIST not provided (export FILE_LIST=... when calling sbatch)" >&2
    exit 1
fi

if [[ -z "${FASTQC_OUT:-}" || -z "${threads:-}" ]]; then
    echo "Missing required variables: FASTQC_OUT or threads" >&2
    exit 1
fi

# Read file list into an array
mapfile -t files < "$FILE_LIST"

# Validate task id
if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    echo "SLURM_ARRAY_TASK_ID is not set; this script expects to be run as an array job." >&2
    exit 1
fi

file="${files[$SLURM_ARRAY_TASK_ID]}"

if [[ -z "$file" ]]; then
    echo "No file for task ID $SLURM_ARRAY_TASK_ID (index out of range or empty list)" >&2
    exit 1
fi

if [[ ! -e "$file" ]]; then
    echo "File does not exist: $file" >&2
    exit 1
fi

# Ensure output directory exists
mkdir -p "$FASTQC_OUT"

echo "Task $SLURM_ARRAY_TASK_ID running FastQC on: $file"
echo "Writing FastQC output to: $FASTQC_OUT"
echo "Using threads: $threads"

# Load FastQC module
module load FastQC/0.12.1

fastqc --nogroup -q -t "$threads" -o "$FASTQC_OUT" "$file"

echo "Task $SLURM_ARRAY_TASK_ID finished successfully."

# Unload module
module unload FastQC/0.12.1