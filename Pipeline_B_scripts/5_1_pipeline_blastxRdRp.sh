#!/bin/bash

# Default values
queue="default"
project="JCOM_pipeline_virome"
root_project="jcomvirome"

show_help() {
    echo ""
    echo "Usage: $0 [-f file_of_accessions] [-h]"
    echo "  -f file_of_accessions: Full path to text file containing library ids (Required)"
    echo ""
    exit 1
}

while getopts "p:f:q:r:h" 'OPTKEY'; do
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

if [ -z "$file_of_accessions" ]; then
    echo "No file provided. Defaulting to: /project/$root_project/$project/contigs/final_contigs/"
    ls -d /project/"$root_project"/"$project"/contigs/final_contigs/*.fa > /project/"$root_project"/"$project"/contigs/final_contigs/file_of_accessions_for_blastx_rdrp
    file_of_accessions="/project/$root_project/$project/contigs/final_contigs/file_of_accessions_for_blastx_rdrp"
fi

jMax=$(wc -l <"$file_of_accessions")
jIndex=$((jMax - 1))
jPhrase="0-$jIndex"
if [ "$jPhrase" == "0-0" ]; then
    jPhrase="0-1"
fi

sbatch --array=$jPhrase \
    --output="/project/$root_project/$project/logs/blastxRdRp_%A_%a_${project}_$(date '+%Y%m%d')_stout.txt" \
    --error="/project/$root_project/$project/logs/blastxRdRp_%A_%a_${project}_$(date '+%Y%m%d')_stderr.txt" \
    --partition="$queue" \
    --time=24:00:00 \
    --account="$root_project" \
    --export=ALL,project="$project",file_of_accessions="$file_of_accessions",root_project="$root_project" \
    /project/"$root_project"/"$project"/scripts/JCOM_pipeline_blastxRdRp_slurm.sh
