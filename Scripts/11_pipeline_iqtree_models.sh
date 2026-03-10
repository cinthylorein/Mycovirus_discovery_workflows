#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Where aligned fasta files are
ALIGN_DIR="${ALIGN_DIR:-${SCRIPT_DIR}/../alignments/aligned}"

# Output directory for IQ-TREE results
IQTREE_OUTDIR="${IQTREE_OUTDIR:-${SCRIPT_DIR}/../alignments/iqtree}"

mkdir -p "$IQTREE_OUTDIR"

mapfile -t ALN_FILES < <(ls -1 "$ALIGN_DIR"/*.aligned.fasta 2>/dev/null || true)
if (( ${#ALN_FILES[@]} == 0 )); then
  echo "ERROR: No *.aligned.fasta found in $ALIGN_DIR" >&2
  exit 1
fi

array_max=$((${#ALN_FILES[@]} - 1))

job_id=$(sbatch --parsable \
  --array=0-"$array_max" \
  --export=ALL,ALIGN_DIR="$ALIGN_DIR",IQTREE_OUTDIR="$IQTREE_OUTDIR" \
  "${SCRIPT_DIR}/pipeline_iqtree_models.slurm")

echo "$job_id"
echo "Submitted IQ-TREE array: $job_id (0..$array_max)" >&2
echo "Input alignments: $ALIGN_DIR" >&2
echo "Output dir:       $IQTREE_OUTDIR" >&2