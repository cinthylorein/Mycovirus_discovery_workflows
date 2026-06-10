#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

source "$CONFIG"

IN="${CONTIGS_DIR:-/workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/contigs}"
OUT="${BLAST_DIR:-/workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/blast_results}"
LOG_DIR_WRAPPER="${LOG_DIR:-${OUT}/logs}"

# BLAST nucleotide DB prefix (must be a BLAST-formatted db, not .fasta unless you ran makeblastdb)
BLASTDB_NT="${BLASTDB_NT:-/workspace/hrakmc/DBs/NCBI_allVirusnt_DB_AUG2022}"

mkdir -p "$OUT" "$LOG_DIR_WRAPPER"

# Discover all samples by finding contigs.fasta
mapfile -t CONTIG_FILES < <(ls -1 "$IN"/*/contigs.fasta 2>/dev/null || true)
if (( ${#CONTIG_FILES[@]} == 0 )); then
  echo "ERROR: No contigs.fasta found under $IN/*/contigs.fasta" >&2
  exit 1
fi
array_max=$((${#CONTIG_FILES[@]} - 1))

echo "Submitting blastn array for ${#CONTIG_FILES[@]} samples (0..$array_max)"
job_blastn=$(sbatch --parsable \
  --array=0-"$array_max" \
  --export=ALL,CONFIG="$CONFIG",IN="$IN",OUT="$OUT",BLASTDB="$BLASTDB_NT" \
  --output="${LOG_DIR_WRAPPER}/blastn_%A_%a.out" \
  --error="${LOG_DIR_WRAPPER}/blastn_%A_%a.err" \
  6_pipeline_blastn.slurm)

echo "Submitted jobs:"
echo "  - blastn: $job_blastn"
echo "Monitor: sacct -j $job_blastn"

