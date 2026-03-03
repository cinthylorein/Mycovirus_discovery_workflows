#!/bin/bash

#SBATCH -J blastx_batch
#SBATCH -o /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/blastx_%A_%a.out
#SBATCH -e /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/blastx_%A_%a.err
#SBATCH --array=0-1
#SBATCH --cpus-per-task=2
#SBATCH --mem=10G
#SBATCH --time=00:10:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL
 
set -o pipefail
set -e
set -x


    module load ncbi-blast/2.11.0
	
	samples=(SRR11783518)

    base_dir="$IN"
    out_dir="$OUT"
    log_dir="$LOG"
    


    sample="${samples[$SLURM_ARRAY_TASK_ID]}"
	fasta="$base_dir/$sample/contigs.fasta"
	outfile="${out_dir}/${sample}_txnr_blast.csv"


     if   ! blastx -db "$BLASTDBnt" \
            -query "$fasta" \
            -outfmt "6 qseqid sacc pident staxid ssciname length mismatch gapopen qstart qend sstart send evalue bitscore qlen" \
			-max_target_seqs 5 \
			-num_threads 2 \
			-out "$outfile"; then
            printf "BLAST failed for %s\n" "$fasta" >&2
        fi
    done

    module unload ncbi-blast/2.11.0
	

}