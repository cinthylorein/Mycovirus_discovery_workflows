#!/bin/bash

# Default values
queue="default"
project="JCOM_pipeline_virome"
root_project="jcomvirome"

show_help() {
    echo ""
    echo "Usage: $0 [-f file_of_accessions] [-d db] [-h]"
    echo "  -f file_of_accessions: Full path to text file with .fa inputs (Required)"
    echo "  -d db: Path to DIAMOND NR database (.dmnd) (Required)"
    exit 1
}

while getopts "p:f:q:r:d:h" 'OPTKEY'; do
    case "$OPTKEY" in
    'p') project="$OPTARG" ;;
    'f') file_of_accessions="$OPTARG" ;;
    'd') db="$OPTARG" ;;
    'q') queue="$OPTARG" ;;
    'r') root_project="$OPTARG" ;;
    'h') show_help ;;
    *) show_help ;;
    esac
done
shift $((OPTIND - 1))

if [ -z "$file_of_accessions" ]; then
    echo "ERROR: Must specify accession file with -f"
    exit 1
fi

if [ -z "$db" ]; then
    echo "ERROR: Must specify NR diamond DB with -d"
    exit 1
fi

if [ "$queue" == "defaultQ" ]; then
    time_limit="120:00:00"
    slurm_account="$root_project"
    cpus=24
    mem="220G"
    diamond_para="-e 1E-4 -c1 -b 4 -p 20 --more-sensitive -k10 --tmpdir /scratch/$root_project/"
fi

if [ "$queue" == "intensive" ]; then
    time_limit="124:00:00"
    slurm_account="VELAB"
    queue="defaultQ"
    cpus=24
    mem="220G"
    diamond_para="-e 1E-4 -c1 -b 8 -p 24 --more-sensitive -k5 --tmpdir /scratch/$root_project/"
fi

sbatch \
    --output="/project/$root_project/$project/logs/blastnr_${project}_${queue}_$(basename "$db")_$(date '+%Y%m%d')_stout.txt" \
    --error="/project/$root_project/$project/logs/blastnr_${project}_${queue}_$(basename "$db")_$(date '+%Y%m%d')_stderr.txt" \
    --partition="$queue" \
    --time="$time_limit" \
    --account="$slurm_account" \
    --cpus-per-task="$cpus" \
    --mem="$mem" \
    --export=ALL,project="$project",file_of_accessions="$file_of_accessions",root_project="$root_project",diamond_para="$diamond_para",db="$db" \
    /project/"$root_project"/"$project"/scripts/JCOM_pipeline_blastnr_slurm.sh
