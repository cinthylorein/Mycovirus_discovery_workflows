#!/usr/bin/env bash

####################################################################################
# Mycovirus Discovery Workflow - Step VI: BLASTn Batch Submitter                   #
# Author: Cinthy Jimenez-Silva (2026)                                              #
#                                                                                  #
# Description:                                                                     #
# This script submits a batch of BLASTn jobs to the SLURM scheduler.               #
# It searches assembled contigs against the configured nucleotide BLAST database.  #
####################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

source "$CONFIG"

: "${CONTIGS_DIR:?Need CONTIGS_DIR set in config/pipeline.env or environment}"
: "${BLAST_DIR:?Need BLAST_DIR set in config/pipeline.env or environment}"
: "${BLASTDB_NT:?Need BLASTDB_NT set in config/pipeline.env or environment}"
: "${LOG_DIR:?Need LOG_DIR set in config/pipeline.env or environment}"
: "${EMAIL:?Need EMAIL set in config/pipeline.env or environment}"

IN="$CONTIGS_DIR"
OUT="$BLAST_DIR"
LOG_DIR_WRAPPER="${LOG_DIR}"

mkdir -p "$OUT" "$LOG_DIR_WRAPPER"

if [[ ! -d "$IN" ]]; then
  echo "ERROR: CONTIGS_DIR not found: $IN" >&2
  exit 1
fi

# BLAST databases are prefixes, so check a few common companion files
if [[ ! -f "${BLASTDB_NT}.nin" && ! -f "${BLASTDB_NT}.00.nin" && ! -f "${BLASTDB_NT}.nal" ]]; then
  echo "ERROR: BLAST nucleotide database not found or not formatted: $BLASTDB_NT" >&2
  echo "Expected BLAST db prefix with files like .nin, .00.nin, or .nal" >&2
  exit 1
fi

# Discover all samples by finding contigs.fasta
mapfile -t CONTIG_FILES < <(find "$IN" -mindepth 2 -maxdepth 2 -type f -name 'contigs.fasta' | sort)

if (( ${#CONTIG_FILES[@]} == 0 )); then
  echo "ERROR: No contigs.fasta found under $IN/*/contigs.fasta" >&2
  exit 1
fi

array_max=$((${#CONTIG_FILES[@]} - 1))

echo "Submitting BLASTn array for ${#CONTIG_FILES[@]} samples (0..$array_max)"
echo "IN=$IN"
echo "OUT=$OUT"
echo "BLASTDB_NT=$BLASTDB_NT"

job_blastn=$(sbatch --parsable \
  --mail-user="$EMAIL" \
  --mail-type=ALL \
  --array=0-"$array_max" \
  --export=ALL,CONFIG="$CONFIG",IN="$IN",OUT="$OUT",BLASTDB="$BLASTDB_NT" \
  --output="${LOG_DIR_WRAPPER}/blastn_%A_%a.out" \
  --error="${LOG_DIR_WRAPPER}/blastn_%A_%a.err" \
  "${SCRIPT_DIR}/6_pipeline_blastn.slurm")

echo "Submitted jobs:"
echo "  - blastn: $job_blastn"
echo "Monitor:"
echo "  sacct -j $job_blastn"
echo "  squeue -u ${USER:-$(whoami)}"
