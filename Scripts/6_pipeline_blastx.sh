#!/usr/bin/env bash

####################################################################################
# Mycovirus Discovery Workflow - Step VI: BLASTx / DIAMOND Batch Submitter         #
# Author: Cinthy Jimenez-Silva (2026)                                              #
#                                                                                  #
# Description:                                                                     #
# This script submits batch searches for assembled contigs against:                #
#   1) NR using BLASTx                                                             #
#   2) RdRp database using DIAMOND                                                 #
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
: "${BLASTDB_NR:?Need BLASTDB_NR set in config/pipeline.env or environment}"
: "${DIAMONDDB_RDRP:?Need DIAMONDDB_RDRP set in config/pipeline.env or environment}"
: "${LOG_DIR:?Need LOG_DIR set in config/pipeline.env or environment}"
: "${EMAIL:?Need EMAIL set in config/pipeline.env or environment}"

IN="$CONTIGS_DIR"
OUT="$BLAST_DIR"
BLAST_LOG_DIR="${BLAST_DIR}/logs"

mkdir -p "$LOG_DIR" "$OUT" "$BLAST_LOG_DIR"

if [[ ! -d "$IN" ]]; then
  echo "ERROR: CONTIGS_DIR not found: $IN" >&2
  exit 1
fi

# Basic DB checks
if [[ ! -f "${BLASTDB_NR}.pin" && ! -f "${BLASTDB_NR}.00.pin" && ! -f "${BLASTDB_NR}.pal" ]]; then
  echo "ERROR: BLASTDB_NR not found or not formatted: $BLASTDB_NR" >&2
  echo "Expected BLAST db prefix with files like .pin, .00.pin, or .pal" >&2
  exit 1
fi

if [[ ! -f "$DIAMONDDB_RDRP" ]]; then
  echo "ERROR: DIAMONDDB_RDRP not found: $DIAMONDDB_RDRP" >&2
  exit 1
fi

mapfile -t CONTIG_FILES < <(find "$IN" -mindepth 2 -maxdepth 2 -type f -name 'contigs.fasta' | sort)

if (( ${#CONTIG_FILES[@]} == 0 )); then
  echo "ERROR: No contigs.fasta found under $IN/*/contigs.fasta" >&2
  exit 1
fi

array_max=$((${#CONTIG_FILES[@]} - 1))

submit_search() {
  local tag="$1"
  local tool="$2"   # blastx | diamond
  local db="$3"

  echo "Submitting $tool ($tag) array for ${#CONTIG_FILES[@]} samples (0..$array_max)"
  echo "  DB=$db"

  sbatch --parsable \
    --mail-user="$EMAIL" \
    --mail-type=ALL \
    --array=0-"$array_max" \
    --export=ALL,CONFIG="$CONFIG",IN="$IN",OUT="$OUT",BLAST_LOG_DIR="$BLAST_LOG_DIR",DB="$db",TAG="$tag",SEARCH_TOOL="$tool" \
    --output="${LOG_DIR}/${tool}_${tag}_%A_%a.out" \
    --error="${LOG_DIR}/${tool}_${tag}_%A_%a.err" \
    "${SCRIPT_DIR}/6_pipeline_blastx_nr.slurm"
}

job_nr="$(submit_search nr blastx "$BLASTDB_NR")"
job_rdrp="$(submit_search rdrp diamond "$DIAMONDDB_RDRP")"

echo "Submitted jobs:"
echo "  - blastx_nr:    $job_nr"
echo "  - diamond_rdrp: $job_rdrp"
echo "Monitor:"
echo "  sacct -j $job_nr,$job_rdrp"
echo "  squeue -u ${USER:-$(whoami)}"