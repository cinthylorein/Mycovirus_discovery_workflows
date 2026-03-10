#!/bin/bash
#SBATCH --job-name=align_fasta
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=../logs/align_fasta_%A_%a.out
#SBATCH --error=../logs/align_fasta_%A_%a.err

set -euo pipefail
set -x

: "${ALIGN_DIR:?ALIGN_DIR not set}"
: "${OUT_DIR:?OUT_DIR not set}"

mkdir -p "$OUT_DIR"

# Load aligner
module load mafft || true

mapfile -t FASTA_FILES < <(ls -1 "$ALIGN_DIR"/*.fasta)
FASTA="${FASTA_FILES[$SLURM_ARRAY_TASK_ID]}"

base="$(basename "$FASTA" .fasta)"

# Decide type by filename (your files include Aminoacid or Nucleotide)
if [[ "$base" == *Aminoacid* || "$base" == *AminoAcid* || "$base" == *Protein* ]]; then
  mode="protein"
elif [[ "$base" == *Nucleotide* || "$base" == *Nucleotides* || "$base" == *Nucleotid* ]]; then
  mode="nucleotide"
else
  # fallback: treat as nucleotide (safer default)
  mode="nucleotide"
fi

out_fa="${OUT_DIR}/${base}.aligned.fasta"

echo "Input: $FASTA"
echo "Mode:  $mode"
echo "Out:   $out_fa"

# MAFFT works for both; we keep mode only for logging / future tuning
mafft --auto --thread "${SLURM_CPUS_PER_TASK:-1}" "$FASTA" > "$out_fa"

echo "Done: $out_fa"