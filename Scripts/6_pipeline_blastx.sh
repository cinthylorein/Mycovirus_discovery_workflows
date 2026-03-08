#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

source "$CONFIG"

IN="$CONTIGS_DIR"
OUT="$BLAST_DIR"
BLAST_LOG_DIR="${BLAST_DIR}/logs"

# DB paths (override in pipeline.env)
BLASTDB_NR="${BLASTDB_NR:-/input/genomic/viral/DBs/nr_09122025/nr}"                       # BLAST formatted prefix
DIAMONDDB_RDRP="${DIAMONDDB_RDRP:-/input/genomic/viral/DBs/RdRp-scan/RdRp-scan_0.90.dmnd}" # DIAMOND .dmnd

mkdir -p "$LOG_DIR" "$OUT" "$BLAST_LOG_DIR"

mapfile -t CONTIG_FILES < <(ls -1 "$IN"/*/contigs.fasta 2>/dev/null || true)
if (( ${#CONTIG_FILES[@]} == 0 )); then
  echo "ERROR: No contigs.fasta found under $IN/*/contigs.fasta" >&2
  exit 1
fi
array_max=$((${#CONTIG_FILES[@]} - 1))

submit_search() {
  local tag="$1"
  local tool="$2"   # blastx|diamond
  local db="$3"

  echo "Submitting $tool ($tag) array for ${#CONTIG_FILES[@]} samples (0..$array_max)"
  echo "  DB=$db"

  sbatch --parsable \
    --array=0-"$array_max" \
    --export=ALL,CONFIG="$CONFIG",IN="$IN",OUT="$OUT",BLAST_LOG_DIR="$BLAST_LOG_DIR",DB="$db",TAG="$tag",SEARCH_TOOL="$tool" \
    --output="${LOG_DIR}/${tool}_${tag}_%A_%a.out" \
    --error="${LOG_DIR}/${tool}_${tag}_%A_%a.err" \
    6_pipeline_blastx_nr.slurm
}

job_nr="$(submit_search nr blastx "$BLASTDB_NR")"
job_rdrp="$(submit_search rdrp diamond "$DIAMONDDB_RDRP")"

echo "Submitted jobs:"
echo "  - blastx_nr:    $job_nr"
echo "  - diamond_rdrp: $job_rdrp"
echo "Monitor: sacct -j $job_nr,$job_rdrp"