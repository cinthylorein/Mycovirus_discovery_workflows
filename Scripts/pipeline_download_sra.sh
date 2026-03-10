#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

# Optional: if you use pipeline.env for common dirs, load it
if [[ -f "$CONFIG" ]]; then
  source "$CONFIG"
fi

# Where the accession list lives
INPATH="${INPATH:-/workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/accession_lists}"
ACCESSIONS_FILE="${ACCESSIONS_FILE:-${INPATH}/accessions.txt}"

# Where to write FASTQs (set this to your raw reads directory)
OUTDIR="${OUTDIR:-${RAW_DIR:-/workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/raw_reads}}"

if [[ ! -f "$ACCESSIONS_FILE" ]]; then
  echo "ERROR: accessions file not found: $ACCESSIONS_FILE" >&2
  exit 1
fi

# Count non-empty, non-comment lines
n=$(grep -vE '^\s*($|#)' "$ACCESSIONS_FILE" | wc -l | tr -d ' ')
if (( n == 0 )); then
  echo "ERROR: No accessions found in $ACCESSIONS_FILE" >&2
  exit 1
fi
array_max=$((n - 1))

mkdir -p "$OUTDIR"

echo "Submitting SRA download array: ${n} accessions (0..$array_max)"
echo "  ACCESSIONS_FILE=$ACCESSIONS_FILE"
echo "  OUTDIR=$OUTDIR"

job_sra=$(sbatch --parsable \
  --array=0-"$array_max" \
  --export=ALL,ACCESSIONS_FILE="$ACCESSIONS_FILE",OUTDIR="$OUTDIR" \
  "${SCRIPT_DIR}/pipeline_download_sra.slurm")

echo "Submitted job: $job_sra"
echo "Monitor: sacct -j $job_sra"
