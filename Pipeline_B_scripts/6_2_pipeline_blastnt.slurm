#!/bin/bash
#SBATCH --job-name=blastnt
#SBATCH --cpus-per-task=24
#SBATCH --mem=220G
#SBATCH --time=120:00:00
#SBATCH --partition=default
#SBATCH --output=/project/%x/logs/blastnt_%j_stdout.txt
#SBATCH --error=/project/%x/logs/blastnt_%j_stderr.txt
#SBATCH --export=ALL

echo "Starting BLASTN job ID: $SLURM_JOB_ID"

if [[ -z "$project" || -z "$file_of_accessions" || -z "$db" || -z "$blast_para" ]]; then
    echo "Missing environment variables."
    exit 1
fi

# Create results directory
results_dir="/project/$root_project/$project/blastn_results"
mkdir -p "$results_dir"

# Process all listed contigs
while read -r contig_file; do
    out_prefix=$(basename "$contig_file" .fa)
    echo "Running blastn for $contig_file..."
    blastn -query "$contig_file" \
           -db "$db" \
           -out "$results_dir/${out_prefix}_blastn.txt" \
           $blast_para
done < "$file_of_accessions"

echo "Finished BLASTN for all contigs."
