#!/bin/bash

#SBATCH -J R_summary_result
#SBATCH -o /workspace/hraczj/Phytophthora_VirusDiscovery_2022/results
#SBATCH -e /workspace/hraczj/Phytophthora_VirusDiscovery_2022/results
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL



module load R/4.3.3

Rscript Summary_table.R --db "$BLASTDB" --inputs "$IN" --format blastx --outdir "$LOG"

Rscript plot_pident_by_sample.R --input "$LOG/combined_blast_combined.csv" --output "$LOG/pident_by_sample.png"

