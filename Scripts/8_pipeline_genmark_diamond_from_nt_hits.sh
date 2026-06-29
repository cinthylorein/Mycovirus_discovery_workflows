#!/usr/bin/env bash
set -euo pipefail

SAMPLE="${1:?Usage: $0 <SAMPLE_ID> <nt_filtered_hits.tsv>}"
HITS_TSV="${2:?Usage: $0 <SAMPLE_ID> <nt_filtered_hits.tsv>}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

[[ -f "$CONFIG" ]] || { echo "ERROR: Config not found: $CONFIG" >&2; exit 1; }
[[ -s "$HITS_TSV" ]] || { echo "ERROR: TSV not found/empty: $HITS_TSV" >&2; exit 1; }

source "$CONFIG"

OUTDIR="${ANNOTATION_DIR}/orf_and_phylo/${SAMPLE}"
mkdir -p "$OUTDIR" "$LOG_DIR"

job_id=$(sbatch --parsable \
  --job-name="gm_dia_${SAMPLE}" \
  --output="${LOG_DIR}/genemark_diamond_${SAMPLE}_%j.out" \
  --error="${LOG_DIR}/genemark_diamond_${SAMPLE}_%j.err" \
  --export=ALL,CONFIG="$CONFIG",SAMPLE="$SAMPLE",HITS_TSV="$HITS_TSV",OUTDIR="$OUTDIR" \
  "${SCRIPT_DIR}/8_pipeline_genmark_diamond_from_nt_hits.slurm")

echo "Submitted: $job_id sample=$SAMPLE out=$OUTDIR"
echo "$job_id"