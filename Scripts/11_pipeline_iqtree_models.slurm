#!/bin/bash
#SBATCH --job-name=iqtree_MF
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=06:00:00
#SBATCH --output=../logs/iqtree_%A_%a.out
#SBATCH --error=../logs/iqtree_%A_%a.err

set -euo pipefail
set -x

: "${ALIGN_DIR:?ALIGN_DIR not set}"
: "${IQTREE_OUTDIR:?IQTREE_OUTDIR not set}"

module load iqtree

mkdir -p "$IQTREE_OUTDIR"

mapfile -t ALN_FILES < <(ls -1 "$ALIGN_DIR"/*.aligned.fasta)
aln="${ALN_FILES[$SLURM_ARRAY_TASK_ID]}"
base="$(basename "$aln" .aligned.fasta)"

# Decide sequence type by filename
if [[ "$base" == *Aminoacid* || "$base" == *AminoAcid* || "$base" == *Protein* ]]; then
  seqtype="AA"
elif [[ "$base" == *Nucleotide* || "$base" == *Nucleotides* || "$base" == *Nucleotid* ]]; then
  seqtype="DNA"
else
  # fallback; you can change this default
  seqtype="DNA"
fi

# One results subfolder per alignment
outdir="${IQTREE_OUTDIR}/${base}"
mkdir -p "$outdir"

# IQ-TREE uses -pre for prefix; all output files will start with this
prefix="${outdir}/${base}"

# Copy alignment into output dir (optional but keeps runs self-contained)
cp -f "$aln" "${outdir}/"

echo "Alignment: $aln"
echo "SeqType:   $seqtype"
echo "Prefix:    $prefix"

# Recommended: Ultrafast bootstrap (-B) + SH-aLRT
# If you must use classic bootstrap: replace -B 100 with -b 100
iqtree \
  -s "$aln" \
  -st "$seqtype" \
  -m MFP \
  -T "${SLURM_CPUS_PER_TAS:-1}" \
  -B 1000 \
#  --alrt 1000 \
  -pre "$prefix"

echo "Done. Tree files are in: $outdir"
ls -lah "$outdir" || true