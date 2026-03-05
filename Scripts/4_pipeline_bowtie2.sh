#!/usr/bin/env bash

#Extracting and de novo assembly
#Step I: BOWTIE2 - MAKING REF INDEX</u>
#The aim is to next step is to match the reads to host genome and remove host reads.
#To achieve this task, we must first build the index that will be used as the reference.


set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

source "$CONFIG"

# Cluster-specific reference genome path (override via env if needed)
REF="${REF:-/input/genomic/viral/Botrytis_cinerea_Refseq/Botrytiscinerea_RefSeq_B0510_ASM14353v4.fasta}"

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

echo "Submitting Bowtie2 index build job..."
job_index=$(sbatch --parsable \
  --export=ALL,CONFIG="$CONFIG",REF="$REF",INDEX_DIR="$INDEX_DIR" \
  --output="${LOG_DIR}/bowtie2_index_%A.out" \
  --error="${LOG_DIR}/bowtie2_index_%A.err" \
  4_pipeline_bowtie2_build_index.slurm)

echo "Submitting Bowtie2 alignment job array (after index job $job_index)..."

# Build sample list from trimmed reads (R1 files). This defines array size.
mapfile -t R1_FILES < <(ls -1 "$MAP_IN"/*_trimmomatic_R1.fastq 2>/dev/null || true)
if (( ${#R1_FILES[@]} == 0 )); then
  echo "ERROR: No trimmed R1 files found in $MAP_IN (expected SRR*_trimmomatic_R1.fq[.gz])" >&2
  exit 1
fi
array_max=$((${#R1_FILES[@]} - 1))

job_align=$(sbatch --parsable \
  --dependency=afterok:"$job_index" \
  --array=0-"$array_max" \
  --export=ALL,CONFIG="$CONFIG",INDEX_DIR="$INDEX_DIR",MAP_IN="$MAP_IN",MAP_OUT="$MAP_OUT",MAP_LOG="$MAP_LOG" \
  --output="${LOG_DIR}/bowtie2_align_%A_%a.out" \
  --error="${LOG_DIR}/bowtie2_align_%A_%a.err" \
  4_pipeline_bowtie2.slurm)

echo "Submitted jobs:"
echo "  - index: $job_index"
echo "  - align: $job_align (afterok:$job_index)"
echo "Monitor: sacct -j $job_index,$job_align"