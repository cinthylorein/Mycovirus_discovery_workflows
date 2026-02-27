#!/bin/bash

# Parse CLI args
while getopts "p:f:q:r:h" 'OPTKEY'; do
    case "$OPTKEY" in
        'p') project="$OPTARG" ;;
        'f') file_of_accessions="$OPTARG" ;;
        'q') queue="$OPTARG" ;;  # Not used in Slurm but parsed for compatibility
        'r') root_project="$OPTARG" ;;
        'h') exit 0 ;;
        *) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    esac
done

# Validate args
[[ -z "$file_of_accessions" ]] && { echo "Missing accessions file"; exit 1; }

export file_of_accessions=$(realpath "$file_of_accessions")
jMax=$(wc -l <"$file_of_accessions")
jIndex=$((jMax - 1))

# Submit job array
sbatch --array=0-"$jIndex" \
  --job-name=sra_download \
  --export=ALL,file_of_accessions="$file_of_accessions",root_project="$root_project",project="$project" \
  --output="/project/$root_project/$project/logs/sra_download_%A_%a_stdout.txt" \
  --error="/project/$root_project/$project/logs/sra_download_%A_%a_stderr.txt" \
  2_B_pipeline_download_sra.slurm
