#!/bin/bash
#SBATCH --job-name=blastnr
#SBATCH --cpus-per-task=24
#SBATCH --mem=220G
#SBATCH --time=120:00:00
#SBATCH --partition=default
#SBATCH --output=/project/%x/logs/blastnr_%j_stdout.txt
#SBATCH --error=/project/%x/logs/blastnr_%j_stderr.txt
#SBATCH --export=ALL

echo "Running BLASTNR with SLURM Job ID: $SLURM_JOB_ID"

if [[ -z "$project" || -z "$file_of_accessions" || -z "$db" || -z "$diamond_para" ]]; then
    echo "Missing required environment variables"
    exit 1
fi

# Results directory
results_dir="/project/$root_project/$project/blastnr_results"
mkdir -p "$results_dir"

# Run diamond blastx on each file
while read -r contig_file; do
    base=$(basename "$contig_file" .fa)
    echo "Running DIAMOND on $contig_file"
    diamond blastx -q "$contig_file" \
                   -d "$db" \
                   -o "$results_dir/${base}_blastnr.txt" \
                   $diamond_para
done < "$file_of_accessions"

echo "Completed all blastnr runs"
