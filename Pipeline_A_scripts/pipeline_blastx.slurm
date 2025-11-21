#!/bin/bash

#SBATCH -J blastx_batch
#SBATCH -o /workspace/hraczj/Phytophthora_VirusDiscovery_2022/009.blastx/logs/blastx_%A.out
#SBATCH -e /workspace/hraczj/Phytophthora_VirusDiscovery_2022/009.blastx/logs/blastx_%A.err
#SBATCH --array=0-2
#SBATCH --cpus-per-task=2
#SBATCH --mem=10G
#SBATCH --time=00:10:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL
 
set -o pipefail
set -e
set -x

main() {
    module load ncbi-blast/2.11.0 || {
        printf "Failed to load BLAST module\n" >&2
        return 1
    }

    local base_dir="$IN"
    local out_dir="$OUT"
    local log_dir="$LOG"
    #local BLASTDB="/your/blast/db/path/nt"  # Replace this with actual BLAST DB path

    mkdir -p "$out_dir" "$log_dir"

    local fasta; local sample; local outfile

    for fasta in "$base_dir"/RNAR*/scaffolds.fasta; do
        if [[ ! -s "$fasta" ]]; then
            printf "Skipping missing or empty file: %s\n" "$fasta" >&2
            continue
        fi

        sample=$(basename "$(dirname "$fasta")")
        outfile="${out_dir}/${sample}_nt_blast.csv"

        printf "Running BLASTN for sample: %s\n" "$sample"

        if ! blastx -db "$BLASTDB" \
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