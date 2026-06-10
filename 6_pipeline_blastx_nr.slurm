#!/bin/bash
#SBATCH -J searchx
#SBATCH --cpus-per-task=2
#SBATCH --mem=10G
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL
#SBATCH --time=06:00:00

set -euo pipefail
set -x

: "${CONFIG:?CONFIG not set}"
source "$CONFIG"

: "${IN:?IN not set}"
: "${OUT:?OUT not set}"
: "${BLAST_LOG_DIR:?BLAST_LOG_DIR not set}"
: "${DB:?DB not set}"
: "${TAG:?TAG not set (nr/rdrp)}"
: "${SEARCH_TOOL:?SEARCH_TOOL not set (blastx/diamond)}"

mkdir -p "$OUT" "$BLAST_LOG_DIR"
threads="${SLURM_CPUS_PER_TASK:-2}"

shopt -s nullglob
contig_files=( "$IN"/*/contigs.fasta )
fasta="${contig_files[$SLURM_ARRAY_TASK_ID]:-}"
if [[ -z "${fasta}" ]]; then
  echo "ERROR: No contigs.fasta for task $SLURM_ARRAY_TASK_ID" >&2
  exit 1
fi

sample="$(basename "$(dirname "$fasta")")"
outfile="${OUT}/${sample}_${TAG}_${SEARCH_TOOL}.tsv"
sample_log="${BLAST_LOG_DIR}/${sample}.${TAG}.${SEARCH_TOOL}.log"

if [[ "$SEARCH_TOOL" == "blastx" ]]; then
  module load ncbi-blast/2.11.0
  blastx -db "$DB" \
    -query "$fasta" \
    -outfmt "6 qseqid sacc pident staxid ssciname length mismatch gapopen qstart qend sstart send evalue bitscore qlen" \
    -max_target_seqs 5 \
    -num_threads "$threads" \
    -out "$outfile" \
    > "$sample_log" 2>&1
  module unload ncbi-blast/2.11.0

elif [[ "$SEARCH_TOOL" == "diamond" ]]; then
  #module load diamond
  /workspace/hraczj/Virus_discovery_workflows/./diamond blastx \
    --db "$DB" \
    --query "$fasta" \
    --threads "$threads" \
    --evalue 1e-4 \
    --max-target-seqs 5 \
    --out "$outfile" \
    --outfmt 6 qseqid qlen sseqid stitle pident length evalue bitscore \
    > "$sample_log" 2>&1
  #module unload diamond

else
  echo "ERROR: SEARCH_TOOL must be blastx or diamond; got: $SEARCH_TOOL" >&2
  exit 1
fi

# Optional extraction of RdRp-hit contigs
if [[ "$TAG" == "rdrp" ]]; then
  hits_list="${OUT}/${sample}_rdrp_hit_contigs.txt"
  hits_fasta="${OUT}/${sample}_rdrp_blastcontigs.fasta"

  awk -F'\t' '{print $1}' "$outfile" | sort -u > "$hits_list"

  awk 'BEGIN{while((getline<ARGV[2])>0) keep[$0]=1; ARGV[2]=""}
       /^>/{h=$0; sub(/^>/,"",h); print_it=(h in keep)}
       {if(print_it) print}' "$fasta" "$hits_list" > "$hits_fasta" || true
fi

echo "Done sample=$sample tag=$TAG tool=$SEARCH_TOOL out=$outfile"