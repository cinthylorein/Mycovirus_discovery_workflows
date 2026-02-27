#!/bin/bash
#SBATCH --job-name=blastx_rvdb
#SBATCH --output=/project/%x/logs/blastx_rvdb_%A_%a_stdout.txt
#SBATCH --error=/project/%x/logs/blastx_rvdb_%A_%a_stderr.txt
#SBATCH --time=90:00:00
#SBATCH --array=0-1
#SBATCH --account=jcomvirome
#SBATCH --partition=default
#SBATCH --export=ALL

echo "Running SLURM job ID: $SLURM_JOB_ID, task ID: $SLURM_ARRAY_TASK_ID"

if [[ -z "$project" || -z "$file_of_accessions" || -z "$root_project" || -z "$db" ]]; then
    echo "ERROR: Missing required environment variables."
    exit 1
fi

accession_file=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$file_of_accessions")
echo "Processing: $accession_file"

# Output directory
outdir="/project/$root_project/$project/blastx_rvdb/$(basename "$accession_file" .fa)"
mkdir -p "$outdir"

# Run diamond blastx
diamond blastx -q "$accession_file" \
    -d "$db" \
    -o "$outdir/$(basename "$accession_file" .fa)_diamond_out.txt" \
    -f 6 \
    -e 1e-5 \
    -k 1 \
    --threads 4

echo "Finished processing $accession_file"
