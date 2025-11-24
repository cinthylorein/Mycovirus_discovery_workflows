#!/bin/bash

# Default values
queue="default"
project="JCOM_pipeline_virome"
root_project="jcomvirome"

show_help() {
    echo ""
    echo "Usage: $0 [-f file_of_accessions] [-d db] [-h]"
    echo "  -f file_of_accessions: Path to file with accession IDs (Required)"
    echo "  -d db: Full path to RVDB diamond database (.dmnd) (Required)"
    echo ""
    exit 1
}

while getopts "p:f:q:r:d:h" 'OPTKEY'; do
    case "$OPTKEY" in
    'p') project="$OPTARG" ;;
    'f') file_of_accessions="$OPTARG" ;;
    'q') queue="$OPTARG" ;;
    'r') root_project="$OPTARG" ;;
    'd') db="$OPTARG" ;;
    'h') show_help ;;
    *) show_help ;;
    esac
done
shift $((OPTIND - 1))

if [ -z "$file_of_accessions" ]; then
    echo "Scanning for fasta files in: /project/$root_project/$project/contigs/final_contigs/"
    ls -d /project/"$root_project"/"$project"/contigs/final_contigs/*.fa > /project/"$root_project"/"$project"/contigs/final_contigs/file_of_accessions_for_blastx_RVDB
    file_of_accessions="/project/$root_project/$project/contigs/final_contigs/file_of_accessions_for_blastx_RVDB"
fi

if [ -z "$db" ]; then
    echo "ERROR: No database specified. Use -d to provide the path to a .dmnd file."
    exit 1
fi

jMax=$(wc -l <"$file_of_accessions")
jIndex=$((jMax - 1))
jPhrase="0-$jIndex"
if [ "$jPhrase" == "0-0" ]; then jPhrase="0-1"; fi

sbatch --array=$jPhrase \
    --output="/project/$root_project/$project/logs/blastxRVDB_%A_%a_${project}_$(date '+%Y%m%d')_stout.txt" \
    --error="/project/$root_project/$project/logs/blastxRVDB_%A_%a_${project}_$(date '+%Y%m%d')_stderr.txt" \
    --partition="$queue" \
    --time=90:00:00 \
    --account="$root_project" \
    --export=ALL,project="$project",file_of_accessions="$file_of_accessions",root_project="$root_project",db="$db" \
    /project/"$root_project"/"$project"/scripts/JCOM_pipeline_blastxRVDB_slurm.sh
