#!/bin/bash


IN="/workspace/hraczj/Phytophthora_VirusDiscovery_2022/008.blastn/RNAR1_nt_blast.csv"
LOG="/workspace/hraczj/Phytophthora_VirusDiscovery_2022/results"
BLASTDB="/workspace/hrakmc/DBs/NCBI_AllVirus_DB_2AUG2022_sequences.csv"


mkdir -p $LOG

#Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Submitting R_summary_result job"
job_R_summary_result=$(sbatch --parsable --export=ALL,IN="$IN",LOG="$LOG",BLASTDB="$BLASTDB" pipeline_summary_result.slurm)


echo " Submitted jobs:"
echo "   └─ Running blastn:   Job ID $job_R_summary_result"
echo " Monitor with: sacct -j $job_R_summary_result"
