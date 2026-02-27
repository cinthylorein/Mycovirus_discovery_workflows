#!/bin/bash

# Default values
queue="default"
project="JCOM_pipeline_virome"
root_project="jcomvirome"

show_help() {
    echo ""
    echo "Usage: $0 [-f file_of_accessions] [-d db] [-h]"
    echo "  -f file_of_accessions: Path to file with .fa inputs (Required)"
    echo "  -d db: Full path to blastn database (Required)"
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
    echo "ERROR: Must provide a file of accessions using -f"
    exit 1
fi

if [ -z "$db" ]; then
    echo "ERROR: Must provide a BLASTN database using -d"
    exit 1
fi

if [ "$queue" == "defaultQ" ]; then
    time_limit="120:00:00"
    slurm_account="$root_project"
    cpus=24
    mem="220G"
fi

if [ "$queue" == "intensive" ]; then
    time_limit="124:00:00"
    slurm_account="VELAB"
    queue="defaultQ"
    cpus=24
    mem="220G"
fi

blast_para="-max_target_seqs 10 -num_threads $cpus -mt_mode 1 -evalue 1E-10 -subject_besthit -outfmt '6 qseqid qlen sacc salltitles staxids pident length evalue'"

sbatch \
    --output="/project/$root_project/$project/logs/blastnt_${project}_${queue}_$(basename "$db")_$(date '+%Y%m%d')_stout.txt" \
    --error="/project/$root_project/$project/logs/blastnt_${project}_${queue}_$(basename "$db")_$(date '+%Y%m%d')_stderr.txt" \
    --partition="$queue" \
    --time="$time_limit" \
    --account="$slurm_account" \
    --cpus-per-task="$cpus" \
    --mem="$mem" \
    --export=ALL,project="$project",file_of_accessions="$file_of_accessions",root_project="$root_project",blast_para="$blast_para",db="$db" \
    /project/"$root_project"/"$project"/scripts/JCOM_pipeline_blastnt_slurm.sh
