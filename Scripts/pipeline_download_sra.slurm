#!/bin/bash
#SBATCH --job-name=sra_download
#SBATCH --cpus-per-task=2
#SBATCH --mem=30G
#SBATCH --time=12:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL
#SBATCH --output=../logs/sra_download_%A_%a.out
#SBATCH --error=../logs/sra_download_%A_%a.err

set -euo pipefail
set -x

module load sratoolkit/3.0.0

: "${ACCESSIONS_FILE:?ACCESSIONS_FILE not set}"
: "${OUTDIR:?OUTDIR not set}"

mkdir -p "$OUTDIR"

# Read non-empty, non-comment lines into array
mapfile -t accessions < <(grep -vE '^\s*($|#)' "$ACCESSIONS_FILE")

acc="${accessions[$SLURM_ARRAY_TASK_ID]:-}"
if [[ -z "$acc" ]]; then
  echo "ERROR: No accession for task $SLURM_ARRAY_TASK_ID" >&2
  exit 1
fi

echo "Downloading accession: $acc"
echo "OUTDIR: $OUTDIR"

# Prefer writing temp files to node-local scratch if available
#TMPDIR="${SLURM_TMPDIR:-${TMPDIR:-/tmp}}"

# Download and split paired reads into *_1.fastq and *_2.fastq
fasterq-dump "$acc" \
  --split-files \
  --outdir "$OUTDIR" \
#  --threads "${SLURM_CPUS_PER_TASK:-2}" \
#  --temp "$TMPDIR"

echo "Done: $acc"
ls -lh "$OUTDIR" | grep -E "^.*${acc}.*" || true