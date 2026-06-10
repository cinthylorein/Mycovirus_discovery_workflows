#!/usr/bin/env bash

# Step III: TRIMMOMATIC

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

source "$CONFIG"

TRIMMOMATIC_JAR="${TRIMMOMATIC_JAR:-/workspace/cflcyd/software/Trimmomatic/Trimmomatic-0.39/trimmomatic-0.39.jar}"
CLIP="${CLIP:-${ADAPTER_DIR}/Illumina.fa}"

TRIM_OUT="$TRIM_DIR"
UNPAIRED="${TRIM_DIR}/unpaired"
TRIM_LOG_DIR="${TRIM_DIR}/logs"

mkdir -p "$LOG_DIR" "$TRIM_OUT" "$UNPAIRED" "$TRIM_LOG_DIR"

if [[ ! -d "$RAW_DIR" ]]; then
  echo "ERROR: RAW_DIR not found: $RAW_DIR" >&2
  exit 1
fi

if [[ ! -f "$TRIMMOMATIC_JAR" ]]; then
  echo "ERROR: Trimmomatic jar not found: $TRIMMOMATIC_JAR" >&2
  exit 1
fi

if [[ ! -f "$CLIP" ]]; then
  echo "ERROR: Adapter file not found: $CLIP" >&2
  exit 1
fi

echo "Submitting Trimmomatic job"
echo "RAW_DIR=$RAW_DIR"
echo "TRIM_OUT=$TRIM_OUT"
echo "UNPAIRED=$UNPAIRED"
echo "TRIM_LOG_DIR=$TRIM_LOG_DIR"
echo "CLIP=$CLIP"
echo "TRIMMOMATIC_JAR=$TRIMMOMATIC_JAR"

shopt -s nullglob
read1_list=(
  "$RAW_DIR"/SRR*_1.fastq
  "$RAW_DIR"/SRR*_1.fastq.gz
  "$RAW_DIR"/SRR*_1.fq.gz
)

if (( ${#read1_list[@]} == 0 )); then
  echo "ERROR: No SRR*_1.fastq, SRR*_1.fastq.gz, or SRR*_1.fq.gz files found in $RAW_DIR" >&2
  exit 1
fi

array_max=$((${#read1_list[@]} - 1))
echo "Submitting Trimmomatic array: ${#read1_list[@]} samples (0..$array_max)"

job_trim=$(sbatch --parsable \
  --array=0-"$array_max" \
  --export=ALL,CONFIG="$CONFIG",TRIMMOMATIC_JAR="$TRIMMOMATIC_JAR",CLIP="$CLIP",TRIM_OUT="$TRIM_OUT",UNPAIRED="$UNPAIRED",TRIM_LOG_DIR="$TRIM_LOG_DIR" \
  --output="${LOG_DIR}/trim_%A_%a.out" \
  --error="${LOG_DIR}/trim_%A_%a.err" \
  "${SCRIPT_DIR}/3_pipeline_trim.slurm")

echo "Submitted: $job_trim"
echo "Monitor: sacct -j $job_trim"
