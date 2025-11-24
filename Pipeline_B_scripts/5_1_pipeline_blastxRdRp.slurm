#!/bin/bash
#SBATCH --job-name=blastx_rdrp
#SBATCH --output=/project/%x/logs/blastx_rdrp_%A_%a_stdout.txt
#SBATCH --error=/project/%x/logs/blastx_rdrp_%A_%a_stderr.txt
#SBATCH --time=24:00:00
#SBATCH --array=0-1
#SBATCH --account=jcomvirome
#SBATCH --partition=default
#SBATCH --export=ALL

echo "SLURM Job ID: $SLURM_JOB_ID, Task ID: $SLURM_ARRAY_TASK_ID"

if [[ -z "$project" || -z "$file_of_accessions" || -z "$root_project" ]]; then
    echo "Missing required environment variables."
    exit 1
fi

accession_file=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$file_of_accessions")
echo "Processing: $accession_file"

# Define paths
db="/project/$root_project/$project/databases/RdRp"  # Adjust as needed
outdir="/project/$root_project/$project/blastx/$accession_file"

mkdir -p "$outdir"

# Run BLASTX
blastx -query "$accession_file" \
       -db "$db" \
       -evalue 1e-5 \
       -out "$outdir/${SLURM_ARRAY_TASK_ID}_blastx_out.txt" \
       -outfmt 6 \
       -num_threads 4

echo "BLASTX completed for: $accession_file"
