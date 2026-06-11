#!/usr/bin/env bash

####################################################################################
# Mycovirus Discovery Workflow - Step IV: BOWTIE2 Batch Submitter                  #
# Author: Cinthy Jimenez-Silva (2026)                                              #
#                                                                                  #
# Description:                                                                     #
# This script submits a batch of BOWTIE2 jobs to the SLURM scheduler.              #
# Extracting and de novo assembly                                                  #
# Build the host reference index, then align trimmed reads and keep non-host pairs.#
####################################################################################



set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

source "$CONFIG"

: "${REF:?Need REF set in config/pipeline.env or environment}"
: "${ANNOTATION_DIR:?Need ANNOTATION_DIR set in config/pipeline.env or environment}"
: "${TRIM_DIR:?Need TRIM_DIR set in config/pipeline.env or environment}"
: "${MAPPING_DIR:?Need MAPPING_DIR set in config/pipeline.env or environment}"
: "${LOG_DIR:?Need LOG_DIR set in config/pipeline.env or environment}"
: "${EMAIL:?Need EMAIL set in config/pipeline.env or environment}"

# Derived paths from config
BOWTIE_OUT="$ANNOTATION_DIR"
INDEX_DIR="${BOWTIE_OUT}/bt2index"

MAP_IN="$TRIM_DIR"
MAP_OUT="$MAPPING_DIR"
MAP_LOG="${MAP_OUT}/logs"

mkdir -p "$LOG_DIR" "$BOWTIE_OUT" "$INDEX_DIR" "$MAP_OUT" "$MAP_LOG"

if [[ ! -f "$REF" ]]; then
  echo "ERROR: Reference genome not found: $REF" >&2
  exit 1
fi

find_trimmed_r1_files() {
  local dir="$1"
  find "$dir" -maxdepth 1 -type f \( \
      -name '*_trimmomatic_R1.fastq'    -o \
      -name '*_trimmomatic_R1.fastq.gz' -o \
      -name '*_trimmomatic_R1.fq'       -o \
      -name '*_trimmomatic_R1.fq.gz' \
    \) | sort
}

echo "Submitting Bowtie2 index build job..."
echo "REF=$REF"
echo "INDEX_DIR=$INDEX_DIR"
echo "MAP_IN=$MAP_IN"
echo "MAP_OUT=$MAP_OUT"
echo "MAP_LOG=$MAP_LOG"

job_index=$(sbatch --parsable \
  --mail-user="$EMAIL" \
  --mail-type=ALL \
  --export=ALL,CONFIG="$CONFIG",REF="$REF",INDEX_DIR="$INDEX_DIR" \
  --output="${LOG_DIR}/bowtie2_index_%A.out" \
  --error="${LOG_DIR}/bowtie2_index_%A.err" \
  "${SCRIPT_DIR}/4_pipeline_bowtie2_build_index.slurm")

echo "Submitting Bowtie2 alignment job array (after index job $job_index)..."

mapfile -t R1_FILES < <(find_trimmed_r1_files "$MAP_IN")

if (( ${#R1_FILES[@]} == 0 )); then
  echo "ERROR: No trimmed R1 files found in $MAP_IN" >&2
  echo "Supported patterns: *_trimmomatic_R1.fastq, *_trimmomatic_R1.fastq.gz, *_trimmomatic_R1.fq, *_trimmomatic_R1.fq.gz" >&2
  exit 1
fi

array_max=$((${#R1_FILES[@]} - 1))

job_align=$(sbatch --parsable \
  --mail-user="$EMAIL" \
  --mail-type=END,FAIL \
  --dependency=afterok:"$job_index" \
  --array=0-"$array_max" \
  --export=ALL,CONFIG="$CONFIG",INDEX_DIR="$INDEX_DIR",MAP_IN="$MAP_IN",MAP_OUT="$MAP_OUT",MAP_LOG="$MAP_LOG" \
  --output="${LOG_DIR}/bowtie2_align_%A_%a.out" \
  --error="${LOG_DIR}/bowtie2_align_%A_%a.err" \
  "${SCRIPT_DIR}/4_pipeline_bowtie2.slurm")

echo "Submitted jobs:"
echo "  - index: $job_index"
echo "  - align: $job_align (afterok:$job_index)"
echo "Monitor:"
echo "  sacct -j $job_index,$job_align"
echo "  squeue -u ${USER:-$(whoami)}"