#!/bin/bash


# Defaults
queue="normal"
project="MVoP_pipeline"
root_project="MVoPvirome"

show_help() {
    echo ""
    echo "Usage: $0 -f <file_of_accessions> [-p <project>] [-r <root_project>] [-q <queue>] [-h]"
    echo ""
    echo "  -f : Full path to text file with one sample/library ID per line (REQUIRED)"
    echo "  -p : Project name (default: JCOM_pipeline_virome)"
    echo "  -r : Root project directory (default: jcomvirome)"
    echo "  -q : SLURM partition or queue (default: normal)"
    echo "  -h : Show this help message"
    echo ""
    exit 1
}

while getopts "p:f:q:r:h" OPTKEY; do
    case "$OPTKEY" in
        'p') project="$OPTARG" ;;
        'f') file_of_accessions="$OPTARG" ;;
        'q') queue="$OPTARG" ;;
        'r') root_project="$OPTARG" ;;
        'h') show_help ;;
        *) show_help ;;
    esac
done
shift $((OPTIND - 1))

[[ -z "$project" ]] && { echo "Missing -p <project>"; show_help; }
[[ -z "$root_project" ]] && { echo "Missing -r <root_project>"; show_help; }

# If no file is provided, generate list from all raw reads
if [[ -z "$file_of_accessions" ]]; then
    echo "No accession file provided. Scanning raw_reads directory..."
    find "/scratch/$root_project/$project/raw_reads/" -name "*.fastq.gz" > "/scratch/$root_project/$project/raw_reads/file_of_accessions_for_assembly"
    file_of_accessions="/scratch/$root_project/$project/raw_reads/file_of_accessions_for_assembly"
else
    file_of_accessions=$(realpath "$file_of_accessions")
fi

# Count lines for SLURM array size
num_jobs=$(wc -l < "$file_of_accessions")
end_index=$((num_jobs - 1))
[[ "$end_index" -lt 0 ]] && end_index=0

# Set log directory
LOG_DIR="/project/$root_project/$project/logs"
mkdir -p "$LOG_DIR"

# Submit SLURM job array
sbatch \
  --array=0-${end_index} \
  --partition="$queue" \
  --time=84:00:00 \
  --cpus-per-task=8 \
  --mem=16G \
  --job-name=TrimAssembleAbund \
  --output="${LOG_DIR}/trim_assemble_abundance_%A_%a_${project}_$(date +%Y%m%d)_stdout.txt" \
  --error="${LOG_DIR}/trim_assemble_abundance_%A_%a_${project}_$(date +%Y%m%d)_stderr.txt" \
  --export=ALL,project="$project",file_of_accessions="$file_of_accessions",root_project="$root_project" \
  "/project/$root_project/$project/scripts/pipeline_trim_assembly_abundance.slurm"
s
