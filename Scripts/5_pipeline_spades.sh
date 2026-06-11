#!/usr/bin/env bash

####################################################################################
# Mycovirus Discovery Workflow - Step V: SPAdes Batch Submitter                    #
# Author: Cinthy Jimenez-Silva (2026)                                              #
#                                                                                  #
# Description:                                                                     #
# This script submits a batch of rnaviralSPAdes jobs to the SLURM scheduler.       #
# It uses Bowtie2 non-host paired reads as input for de novo assembly.             #
####################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

source "$CONFIG"

: "${MAPPING_DIR:?Need MAPPING_DIR set in config/pipeline.env or environment}"
: "${CONTIGS_DIR:?Need CONTIGS_DIR set in config/pipeline.env or environment}"
: "${LOG_DIR:?Need LOG_DIR set in config/pipeline.env or environment}"
: "${EMAIL:?Need EMAIL set in config/pipeline.env or environment}"

# Inputs/outputs from config
SPADES_IN="$MAPPING_DIR"
SPADES_OUT="$CONTIGS_DIR"
SPADES_LOG="${CONTIGS_DIR}/logs"

mkdir -p "$LOG_DIR" "$SPADES_OUT" "$SPADES_LOG"

# Build sample list based on Bowtie2 unmapped paired outputs.
# bowtie2 --un-conc-gz <prefix> creates paired files with .1 and .2 inserted.
mapfile -t R1_FILES < <(ls -1 "$SPADES_IN"/*.non-host.fq.1.gz 2>/dev/null || true)

if (( ${#R1_FILES[@]} == 0 )); then
  echo "ERROR: No Bowtie2 non-host R1 files found in $SPADES_IN (expected *.non-host.fq.1.gz)" >&2
  exit 1
fi

array_max=$((${#R1_FILES[@]} - 1))

echo "Submitting rnaviralSPAdes array for ${#R1_FILES[@]} samples (0..$array_max)"
echo "SPADES_IN=$SPADES_IN"
echo "SPADES_OUT=$SPADES_OUT"
echo "SPADES_LOG=$SPADES_LOG"

job_spades=$(sbatch --parsable \
  --mail-user="$EMAIL" \
  --mail-type=ALL \
  --array=0-"$array_max" \
  --export=ALL,CONFIG="$CONFIG",SPADES_IN="$SPADES_IN",SPADES_OUT="$SPADES_OUT",SPADES_LOG="$SPADES_LOG" \
  --output="${LOG_DIR}/spades_%A_%a.out" \
  --error="${LOG_DIR}/spades_%A_%a.err" \
  "${SCRIPT_DIR}/5_pipeline_spades.slurm")

echo "Submitted: $job_spades"
echo "Monitor:"
echo "  sacct -j $job_spades"
echo "  squeue -u ${USER:-$(whoami)}"