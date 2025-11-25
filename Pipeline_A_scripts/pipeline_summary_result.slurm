#!/bin/bash

#SBATCH -J R_summary_result
#SBATCH -o /workspace/hraczj/Phytophthora_VirusDiscovery_2022/results/summary_%A.out
#SBATCH -e /workspace/hraczj/Phytophthora_VirusDiscovery_2022/results/summary_%A.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL



module load R/4.3.3

#Rscript Summary_table.R --db "$BLASTDB" --inputs "$IN_nt/RNA1_nt_names.csv,$IN_nt/RNA2_nt_names.csv,$IN_nt/RNA3_nt_names.csv" --format blastn --outdir "$LOG_nt"

Rscript Summary_table.R --db "$BLASTDB" --inputs "$IN_tx/PhytophthoraVirus_Discovery_RNA1_aa_names.csv,$IN_tx/PhytophthoraVirus_Discovery_RNA2_aa_names.csv,$IN_tx/PhytophthoraVirus_Discovery_RNA3_aa_names.csv" --format blastx --outdir "$LOG_tx"

#Rscript plot_pident_by_sample.R --input "$LOG_nt/combined_blast_combined.csv" --output "$LOG_nt/pident_by_sample.png"

Rscript plot_pident_by_sample.R --input "$LOG_tx/combined_blast_combined.csv" --output "$LOG_tx/pident_by_sample.png"