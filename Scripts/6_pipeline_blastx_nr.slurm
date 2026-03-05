#!/bin/bash
#SBATCH -J blastx_nr
#SBATCH --cpus-per-task=2
#SBATCH --mem=10G
#SBATCH --time=00:10:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL

set -euo pipefail
set -x

module load ncbi-blast/2.11.0

: "${CONFIG:?CONFIG not set}"
source "$CONFIG"

: "${IN:?IN not set (contigs base dir)}"
: "${OUT:?OUT not set (blast results dir)}"
: "${BLAST_LOG_DIR:?BLAST_LOG_DIR not set}"
: "${BLASTDB:?BLASTDB not set (blast database path)}"

mkdir -p "$OUT" "$BLAST_LOG_DIR"

threads="${SLURM_CPUS_PER_TASK:-2}"

# Must match wrapper discovery logic/order
shopt -s nullglob
contig_files=( "$IN"/*/contigs.fasta )

if (( ${#contig_files[@]} == 0 )); then
  echo "ERROR: No contigs.fasta found under $IN/*/contigs.fasta" >&2
  exit 1
fi

fasta="${contig_files[$SLURM_ARRAY_TASK_ID]:-}"
if [[ -z "$fasta" ]]; then
  echo "ERROR: No fasta for task $SLURM_ARRAY_TASK_ID (n=${#contig_files[@]})" >&2
  exit 1
fi

sample="$(basename "$(dirname "$fasta")")"
outfile="${OUT}/${sample}_txnr_blast.tsv"
sample_log="${BLAST_LOG_DIR}/${sample}.blastx_nr.log"

echo "Sample=$sample"
echo "FASTA=$fasta"
echo "DB=$BLASTDB"
echo "OUT=$outfile"
echo "threads=$threads"

blastx -db "$BLASTDB" \
  -query "$fasta" \
  -outfmt "6 qseqid sacc pident staxid ssciname length mismatch gapopen qstart qend sstart send evalue bitscore qlen" \
  -max_target_seqs 5 \
  -num_threads "$threads" \
  -out "$outfile" \
  > "$sample_log" 2>&1

module unload ncbi-blast/2.11.0