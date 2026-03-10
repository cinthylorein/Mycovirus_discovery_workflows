#!/usr/bin/env bash
set -euo pipefail

# Required args
SAMPLE="${1:?Usage: $0 <SAMPLE_ID> <nt_filtered_hits.tsv>}"
HITS_TSV="${2:?Usage: $0 <SAMPLE_ID> <nt_filtered_hits.tsv>}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"
source "$CONFIG"

OUTDIR="${ANNOTATION_DIR}/orf_and_phylo/${SAMPLE}"
mkdir -p "$OUTDIR"

job_id=$(sbatch --parsable \
  --export=ALL,CONFIG="$CONFIG",SAMPLE="$SAMPLE",HITS_TSV="$HITS_TSV",OUTDIR="$OUTDIR" \
  "${SCRIPT_DIR}/pipeline_genemark_diamond_from_nt_hits.slurm")

echo "$job_id"
echo "Submitted: $job_id sample=$SAMPLE out=$OUTDIR" >&2