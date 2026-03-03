#!/bin/bash

#SBATCH -J fastqc_array
#SBATCH --array=0-3
#SBATCH --job-name=ascp_SRA_download
#SBATCH --output=../logs/sra_download_%A_%.out
#SBATCH --error=../logs/sra_download_%A_%.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=30G
#SBATCH --time=12:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL


module load sratoolkit/3.0.0


#readarray -t myarray <"$file_of_accessions"
#library_id="${myarray[$SLURM_ARRAY_TASK_ID]}"
library_id="SRR11783518"

fasterq-dump "$library_id" --split-files
#fasterq-dump "$library_id" --split-files -o "$inpath"


#while read -r accession; do
#    fasterq-dump "$accession" --split-files -o "$inpath"
#done < "$file_of_accessions"