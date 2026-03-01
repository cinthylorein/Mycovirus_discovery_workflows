#!/bin/bash

#SBATCH -J blastx_batch
#SBATCH -o /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/blastx_%A_%a.out
#SBATCH -e /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/blastx_%A_%a.err
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

local samples=(SRR14655089)

    local base_dir="$IN"
    local out_dir="$OUT"
    local log_dir="$LOG"
    

    mkdir -p "$out_dir" "$log_dir"

    local fasta; local sample; local outfile

    for fasta in "$base_dir"/"$samples"/contigs.fasta; do

		if [[ ! -s "$fasta" ]]; then
            printf "Skipping missing or empty file: %s\n" "$fasta" >&2
            continue
        fi

        sample=$(basename "$(dirname "$fasta")")
        outfile="${out_dir}/${sample}_txRsRP_blast.csv"

        printf "Running BLASTN for sample: %s\n" "$sample"

        if ! blastx -db "$BLASTDBRsRP" \
            -query "$fasta" \
			-evalue 1e-5 \
            -outfmt 6 \
            -num_threads 4 \
            -out "$outfile"; then
            printf "BLAST failed for %s\n" "$fasta" >&2
        fi
    done

    module unload ncbi-blast/2.11.0
	

}