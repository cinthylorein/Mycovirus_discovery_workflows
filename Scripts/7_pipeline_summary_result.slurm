#!/bin/bash

#SBATCH -J R_summary_result
#SBATCH -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/summary_%A.out
#SBATCH -e /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/summary_%A.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL



module load R/4.3.3

#Rscript Summary_table.R --db "$BLASTDB" --inputs "$IN_nt/SRR14655079_nt_blast.csv,$IN_nt/SRR14655078_nt_blast.csv,$IN_nt/SRR14655080_nt_blast.csv,$IN_nt/SRR14655082_nt_blast.csv,$IN_nt/SRR14655083_nt_blast.csv,$IN_nt/SRR14655084_nt_blast.csv,$IN_nt/SRR14655085_nt_blast.csv,$IN_nt/SRR14655086_nt_blast.csv,$IN_nt/SRR14655087_nt_blast.csv,$IN_nt/SRR14655088_nt_blast.csv,$IN_nt/SRR14655089_nt_blast.csv" --format blastn --outdir "$LOG_nt"

#Rscript Summary_table.R --db "$BLASTDBtx" --inputs "$IN_tx/SRR11783490_tx_blast.csv" --format blastx --outdir "$LOG_tx"

#Rscript plot_pident_by_sample.R --input "$LOG_nt/combined_blast_combined.csv" --output "$LOG_nt/pident_by_sample.png"

Rscript plot_pident_by_sample_b.R \
  --input "$LOG_nt/combined_blast_combined.csv" \
  --output "$LOG_nt/pident_filtered_len200.png" \
  --filter-min-readlen 200 \
  --filter-min-coverage 0.5 \
  --filter-min-pident 75 \
  --filter-max-evalue 1e-5 \
  --filter-min-alnlen 150 \
  --write-filtered "$LOG_nt/filtered_hits.tsv"
  --highlight-families-file mycovirus_families.txt
#Rscript plot_pident_by_sample.R --input "$LOG_tx/combined_blast_combined.csv" --output "$LOG_tx/txdent_by_sample.png"
