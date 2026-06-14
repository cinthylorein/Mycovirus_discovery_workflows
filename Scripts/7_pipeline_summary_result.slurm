#!/usr/bin/env bash
#SBATCH -J R_summary_result
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --mail-type=ALL

set -euo pipefail

module load R/4.3.3

: "${IN_nt:?IN_nt not set}"
: "${IN_tx:?IN_tx not set}"
: "${IN_rdrp:?IN_rdrp not set}"
: "${LOG_nt:?LOG_nt not set}"
: "${LOG_tx:?LOG_tx not set}"
: "${LOG_rdrp:?LOG_rdrp not set}"
: "${BLASTDB:?BLASTDB not set}"
: "${BLASTDBtx:?BLASTDBtx not set}"

# keep only if you truly use it in R script
HIGHLIGHT_FAMILIES_FILE="mycovirus_families.txt"

mkdir -p "$LOG_nt" "$LOG_tx" "$LOG_rdrp"

echo "IN_nt=[$IN_nt]"
echo "IN_tx=[$IN_tx]"
echo "IN_rdrp=[$IN_rdrp]"
echo "LOG_nt=[$LOG_nt]"
echo "LOG_tx=[$LOG_tx]"
echo "LOG_rdrp=[$LOG_rdrp]"
echo "BLASTDB=[$BLASTDB]"
echo "BLASTDBtx=[$BLASTDBtx]"

[ -d "$IN_nt" ] || { echo "ERROR: IN_nt directory does not exist"; exit 1; }
[ -d "$IN_tx" ] || { echo "ERROR: IN_tx directory does not exist"; exit 1; }
[ -d "$IN_rdrp" ] || { echo "ERROR: IN_rdrp directory does not exist"; exit 1; }

############################
# NT / blastn
############################
INPUT_FILES_NT=$(find "$IN_nt" -mindepth 2 -maxdepth 2 -type f \( -name '*_nt_blast.tsv' -o -name '*_blastn_nt.tsv' \) | sort | paste -sd, -)
echo "INPUT_FILES_NT=[$INPUT_FILES_NT]"

if [[ -n "$INPUT_FILES_NT" ]]; then
  Rscript Summary_table.R \
    --db "$BLASTDB" \
    --inputs "$INPUT_FILES_NT" \
    --format blastn \
    --outdir "$LOG_nt"
else
  echo "No nt blast input files found in $IN_nt; skipping NT summary"
fi

############################
# TX / blastx
############################
INPUT_FILES_TX=$(find "$IN_tx" -mindepth 2 -maxdepth 2 -type f -name '*_nr_blastx.tsv' | sort | paste -sd, -)
echo "INPUT_FILES_TX=[$INPUT_FILES_TX]"

if [[ -n "$INPUT_FILES_TX" ]]; then
  Rscript Summary_table.R \
    --db "$BLASTDBtx" \
    --inputs "$INPUT_FILES_TX" \
    --format blastx \
    --outdir "$LOG_tx"
else
  echo "No blastx input files found in $IN_tx; skipping TX summary"
fi

############################
# RDRP / diamond
############################
INPUT_FILES_RDRP=$(find "$IN_rdrp" -mindepth 2 -maxdepth 2 -type f -name '*_rdrp_diamond.tsv' | sort | paste -sd, -)
echo "INPUT_FILES_RDRP=[$INPUT_FILES_RDRP]"

if [[ -n "$INPUT_FILES_RDRP" ]]; then
  Rscript Summary_table.R \
    --db "$BLASTDBtx" \
    --inputs "$INPUT_FILES_RDRP" \
    --format diamond \
    --outdir "$LOG_rdrp"
else
  echo "No rdrp diamond input files found in $IN_rdrp; skipping RDRP summary"
fi

echo "All summary jobs completed successfully."

if [[ -f "$LOG_nt/combined_blast_combined.csv" ]]; then
  Rscript plot_pident_by_sample.R \
    --input "$LOG_nt/combined_blast_combined.csv" \
    --output "$LOG_nt/nt_pident_by_sample.png"
	
	#The most relaxed
	
	Rscript plot_pident_by_sample_b.R \
  --input "$LOG_nt/combined_blast_combined.csv" \
  --output "$LOG_nt/nt_pident_MostRelaxestFiltered_Mycovirusesfamilies.png" \
  --filter-min-readlen 1 \
  --filter-min-coverage 0 \
  --filter-min-pident 0 \
  --filter-max-evalue 10 \
  --filter-min-alnlen 1 \
  --write-filtered "$LOG_nt/filtered_hits.csv" \
  --highlight-families-file "$HIGHLIGHT_FAMILIES_FILE"
   
   # A stricter scenario
   
	Rscript plot_pident_by_sample_b.R \
  --input "$LOG_nt/combined_blast_combined.csv" \
  --output "$LOG_nt/nt_pident_StricterFiltered_Mycovirusesfamilies.png" \
  --filter-min-readlen 1000 \
  --filter-min-coverage 0.5 \
  --filter-min-pident 75 \
  --filter-max-evalue 1e-5 \
  --filter-min-alnlen 150 \
  --write-filtered "$LOG_nt/filtered_hits.csv" \
  --highlight-families-file "$HIGHLIGHT_FAMILIES_FILE"
else
  echo "NT combined summary file not found; skipping NT plots"
fi

if [[ -f "$LOG_tx/combined_blast_combined.csv" ]]; then
  Rscript plot_pident_by_sample.R \
    --input "$LOG_tx/combined_blast_combined.csv" \
    --output "$LOG_tx/tx_pident_by_sample.png"
  
  #The most relaxed
  
  Rscript plot_pident_by_sample_b.R \
    --input "$LOG_tx/combined_blast_combined.csv" \
    --output "$LOG_tx/tx_pident_MostRelaxestFiltered_Mycovirusesfamilies.png" \
    --filter-min-readlen 1 \
    --filter-min-coverage 0 \
    --filter-min-pident 0 \
    --filter-max-evalue 10 \
    --filter-min-alnlen 1 \
     --write-filtered "$LOG_tx/filtered_hits.csv" \
    --highlight-families-file "$HIGHLIGHT_FAMILIES_FILE"

  # A stricter scenario

  Rscript plot_pident_by_sample_b.R \
    --input "$LOG_tx/combined_blast_combined.csv" \
    --output "$LOG_tx/tx_pident_StrictFiltered_Mycovirusesfamilies.png" \
    --filter-min-readlen 80 \
    --filter-min-alnlen 40 \
    --filter-min-pident 20 \
    --filter-max-evalue 1e-5 \
    --filter-min-coverage 0.15 \
    --write-filtered "$LOG_tx/filtered_hits.csv" \
    --highlight-families-file "$HIGHLIGHT_FAMILIES_FILE"
else
  echo "TX combined summary file not found; skipping TX plots"
fi

if [[ -f "$LOG_rdrp/combined_blast_combined.csv" ]]; then
  Rscript plot_pident_by_sample.R \
    --input "$LOG_rdrp/combined_blast_combined.csv" \
    --output "$LOG_rdrp/rdrp_pident_by_sample.png"
  
  #The most relaxed
  
  Rscript plot_pident_by_sample_b.R \
    --input "$LOG_rdrp/combined_blast_combined.csv" \
    --output "$LOG_rdrp/rdrp_pident_MostRelaxestFiltered_Mycovirusesfamilies.png" \
    --filter-min-readlen 1 \
    --filter-min-coverage 0 \
    --filter-min-pident 0 \
    --filter-max-evalue 10 \
    --filter-min-alnlen 1 \
    --write-filtered "$LOG_rdrp/filtered_hits.csv" \
    --highlight-families-file "$HIGHLIGHT_FAMILIES_FILE"
	
  # A stricter scenario

  Rscript plot_pident_by_sample_b.R \
    --input "$LOG_rdrp/combined_blast_combined.csv" \
    --output "$LOG_rdrp/rdrp_pident_StricterFiltered_Mycovirusesfamilies.png" \
    --filter-min-readlen 150 \
    --filter-min-alnlen 60 \
    --filter-min-pident 30 \
    --filter-max-evalue 1e-5 \
    --filter-min-coverage 0.30 \
    --write-filtered "$LOG_rdrp/filtered_hits.csv" \
    --highlight-families-file "$HIGHLIGHT_FAMILIES_FILE"
else
  echo "RDRP combined summary file not found; skipping RDRP plots"
fi

echo "Summary step completed."