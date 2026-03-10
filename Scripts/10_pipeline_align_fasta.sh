#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# input folder (relative to Scripts/)
ALIGN_DIR="${ALIGN_DIR:-${SCRIPT_DIR}/../alignments}"
OUT_DIR="${OUT_DIR:-${ALIGN_DIR}/aligned}"

mkdir -p "$OUT_DIR"

mapfile -t FASTA_FILES < <(ls -1 "$ALIGN_DIR"/*.fasta 2>/dev/null || true)
if (( ${#FASTA_FILES[@]} == 0 )); then
  echo "ERROR: No .fasta files found in $ALIGN_DIR" >&2
  exit 1
fi

array_max=$((${#FASTA_FILES[@]} - 1))

job_id=$(sbatch --parsable \
  --array=0-"$array_max" \
  --export=ALL,ALIGN_DIR="$ALIGN_DIR",OUT_DIR="$OUT_DIR" \
  "${SCRIPT_DIR}/pipeline_align_fasta.slurm")

echo "$job_id"
echo "Submitted alignment array job: $job_id (0..$array_max)" >&2
echo "Output dir: $OUT_DIR" >&2