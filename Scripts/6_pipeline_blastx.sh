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

detect_blast_db_prefix() {
  local input="$1"

  if [[ -f "${input}.pal" || -f "${input}.pin" || -f "${input}.00.pin" || -f "${input}.000.pin" ]]; then
    printf '%s\n' "$input"
    return 0
  fi

  return 1
}

format_fasta_as_blastdb() {
  local fasta="$1"

  if ! command -v makeblastdb >/dev/null 2>&1; then
    echo "ERROR: makeblastdb is required to format FASTA input, but it is not in PATH." >&2
    exit 1
  fi

  local db_prefix
  case "$fasta" in
    *.tar.gz|*.gz)
      echo "ERROR: BLASTDB_NR points to a compressed file. Please decompress it first: $fasta" >&2
      exit 1
      ;;
    *.fasta)
      db_prefix="${fasta%.fasta}"
      ;;
    *.fa)
      db_prefix="${fasta%.fa}"
      ;;
    *.faa)
      db_prefix="${fasta%.faa}"
      ;;
    *.fna)
      db_prefix="${fasta%.fna}"
      ;;
    *)
      db_prefix="$fasta"
      ;;
  esac

  echo "Formatting FASTA as BLAST protein database:" >&2
  echo "  input:  $fasta" >&2
  echo "  output: $db_prefix" >&2

  makeblastdb -in "$fasta" -dbtype prot -out "$db_prefix" >&2

  printf '%s\n' "$db_prefix"
}

resolve_blastdb_nr() {
  local input="$1"
  local resolved_prefix

  if resolved_prefix="$(detect_blast_db_prefix "$input")"; then
    printf '%s\n' "$resolved_prefix"
    return 0
  fi

  if [[ -f "$input" ]]; then
    case "$input" in
      *.fa|*.fasta|*.faa|*.fna)
        format_fasta_as_blastdb "$input"
        return 0
        ;;
      *)
        echo "ERROR: BLASTDB_NR exists but is not a recognized BLAST db prefix or FASTA file: $input" >&2
        exit 1
        ;;
    esac
  fi

  echo "ERROR: BLASTDB_NR not found or not formatted: $input" >&2
  echo "Expected one of:" >&2
  echo "  - formatted BLAST db prefix with files like .pal, .pin, .00.pin, or .000.pin" >&2
  echo "  - FASTA file (.fa, .fasta, .faa, .fna) to be formatted with makeblastdb" >&2
  exit 1
}

BLASTDB_NR_RESOLVED="$(resolve_blastdb_nr "$BLASTDB_NR")"

echo "Resolved BLASTDB_NR:"
echo "  input:    $BLASTDB_NR"
echo "  resolved: $BLASTDB_NR_RESOLVED"

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
  local tool="$2"
  local db="$3"
  local job_id

  echo "Submitting $tool ($tag) array for ${#CONTIG_FILES[@]} samples (0..$array_max)" >&2
  echo "  DB=$db" >&2

  job_id=$(sbatch --parsable \
    --mail-user="$EMAIL" \
    --mail-type=ALL \
    --array=0-"$array_max" \
    --export=ALL,CONFIG="$CONFIG",IN="$IN",OUT="$OUT",BLAST_LOG_DIR="$BLAST_LOG_DIR",DB="$db",TAG="$tag",SEARCH_TOOL="$tool",DIAMOND_BIN="${DIAMOND_BIN:-diamond}" \
    --output="${LOG_DIR}/${tool}_${tag}_%A_%a.out" \
    --error="${LOG_DIR}/${tool}_${tag}_%A_%a.err" \
    "${SCRIPT_DIR}/6_pipeline_blastx_nr.slurm")

  printf '%s\n' "$job_id"
}

job_nr="$(submit_search nr blastx "$BLASTDB_NR_RESOLVED")"
job_rdrp="$(submit_search rdrp diamond "$DIAMONDDB_RDRP")"

job_nr_id="${job_nr%%;*}"
job_rdrp_id="${job_rdrp%%;*}"

echo "Submitted jobs:"
echo "  - blastx_nr:    $job_nr"
echo "  - diamond_rdrp: $job_rdrp"

echo "Monitor:"
echo "  sacct -j $job_nr_id,$job_rdrp_id"
echo "  squeue -u ${USER:-$(whoami)}"

echo "Track jobs individually:"
echo "  sacct -j $job_nr_id"
echo "  sacct -j $job_rdrp_id"