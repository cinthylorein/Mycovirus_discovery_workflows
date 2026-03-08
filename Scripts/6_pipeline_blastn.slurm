#!/bin/bash
#SBATCH -J blastn_batch
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=18:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL

set -euo pipefail
set -x

module load ncbi-blast/2.11.0

: "${CONFIG:?CONFIG not set}"
source "$CONFIG"

: "${IN:?IN not set}"
: "${OUT:?OUT not set}"
: "${BLASTDB:?BLASTDB not set}"

mkdir -p "$OUT"

threads="${SLURM_CPUS_PER_TASK:-2}"

# Discover contigs in a stable order (same logic as wrapper)
shopt -s nullglob
contig_files=( "$IN"/*/contigs.fasta )

if (( ${#contig_files[@]} == 0 )); then
  echo "ERROR: No contigs.fasta found under $IN/*/contigs.fasta" >&2
  exit 1
fi

fasta="${contig_files[$SLURM_ARRAY_TASK_ID]:-}"
if [[ -z "$fasta" || ! -s "$fasta" ]]; then
  echo "ERROR: Missing/empty fasta for task $SLURM_ARRAY_TASK_ID: $fasta" >&2
  exit 1
fi

sample="$(basename "$(dirname "$fasta")")"
outfile="${OUT}/${sample}_nt_blast.tsv"
sample_log="${OUT}/logs/${sample}.blastn.log"

mkdir -p "${OUT}/logs"

blastn -db "$BLASTDB" \
  -query "$fasta" \
  -outfmt "6 qseqid sacc pident staxid ssciname length mismatch gapopen qstart qend sstart send evalue bitscore qlen" \
  -max_target_seqs 5 \
  -num_threads "$threads" \
  -out "$outfile" \
  > "$sample_log" 2>&1

module unload ncbi-blast/2.11.0
echo "Done sample=$sample out=$outfile"