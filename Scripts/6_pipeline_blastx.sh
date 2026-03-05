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

# Cluster-specific DB paths (override via env if needed)
BLASTDB_NT="${BLASTDB_NT:-/input/genomic/viral/DBs/nr_09122025/nr}"
BLASTDB_RDRP="${BLASTDB_RDRP:-/input/genomic/viral/DBs/RdRp-scan/nr}"
BLASTDB_RVDB="${BLASTDB_RVDB:-/input/genomic/viral/DBs/RVDB/}"

mkdir -p "$LOG_DIR" "$OUT" "$BLAST_LOG_DIR"

# Discover sample contig files (expects: CONTIGS_DIR/<sample>/contigs.fasta)
mapfile -t CONTIG_FILES < <(ls -1 "$IN"/*/contigs.fasta 2>/dev/null || true)
if (( ${#CONTIG_FILES[@]} == 0 )); then
  echo "ERROR: No contigs.fasta found under $IN/*/contigs.fasta" >&2
  exit 1
fi
array_max=$((${#CONTIG_FILES[@]} - 1))

echo "Submitting blastx nr array for ${#CONTIG_FILES[@]} samples (0..$array_max)"
job_blastx_nr=$(sbatch --parsable \
  --array=0-"$array_max" \
  --export=ALL,CONFIG="$CONFIG",IN="$IN",OUT="$OUT",BLAST_LOG_DIR="$BLAST_LOG_DIR",BLASTDB="$BLASTDB_NT" \
  --output="${LOG_DIR}/blastx_nr_%A_%a.out" \
  --error="${LOG_DIR}/blastx_nr_%A_%a.err" \
  6_pipeline_blastx_nr.slurm)

echo "Submitted jobs:"
echo "  - blastx_nr: $job_blastx_nr"
echo "Monitor: sacct -j $job_blastx_nr"