#!/bin/bash

#SBATCH -J blastn_batch
#SBATCH -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/blastn_%A_%a.out
#SBATCH -e /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/blastn_%A_%a.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=18:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL

set -o pipefail

main() {
    module load ncbi-blast/2.11.0 || {
        printf "Failed to load BLAST module\n" >&2
        return 1
    }
	
    local samples=(SRR*)

    local base_dir="$IN"
    local out_dir="$OUT"
    local log_dir="$LOG"
    #local BLASTDB="/your/blast/db/path/nt"  # Replace this with actual BLAST DB path

    mkdir -p "$out_dir" "$log_dir"

    local fasta; local sample; local outfile

   for fasta in "$base_dir"/"$samples"/contigs.fasta; do
   
        if [[ ! -s "$fasta" ]]; then
            printf "Skipping missing or empty file: %s\n" "$fasta" >&2
            continue
        fi

        sample=$(basename "$(dirname "$fasta")")
        outfile="${out_dir}/${sample}_nt_blast.csv"

        printf "Running BLASTN for sample: %s\n" "$sample"

        if ! blastn -db "$BLASTDB" \
            -query "$fasta" \
            -outfmt '6 qseqid sacc pident staxid ssciname length mismatch gapopen qstart qend sstart send evalue bitscore qlen' \
            -max_target_seqs 5 \
            -num_threads 2 \
            -out "$outfile"; then
            printf "BLAST failed for %s\n" "$fasta" >&2
        fi
    done

    module unload ncbi-blast/2.11.0
}

main "$@"
