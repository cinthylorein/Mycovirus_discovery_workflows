#!/bin/bash

IN_nt="/workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/blast_results"
IN_tx="/workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/blast_results"
LOG_nt="/workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/blast_results/nt"
LOG_tx="/workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/blast_results/tx"
BLASTDB="/workspace/hrakmc/DBs/NCBI_AllVirus_DB_2AUG2022_sequences.csv"
BLASTDBtx="/workspace/hrakmc/DBs/NCBI_allVirusaa_DB_Nov2022"

mkdir -p "$LOG_nt"
mkdir -p "$LOG_tx"

# Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Submitting R_summary_result job"
job_R_summary_result=$(sbatch --parsable --export=ALL,IN_nt="$IN_nt",IN_tx="$IN_tx",LOG_nt="$LOG_nt",LOG_tx="$LOG_tx",BLASTDB="$BLASTDB" 7_pipeline_summary_result.slurm)

if [[ -z "$job_R_summary_result" ]]; then
  echo "sbatch did not return a job ID — submission may have failed" >&2
  exit 1
fi

echo " Submitted jobs:"
echo "   └─ Running blastn:Job ID $job_R_summary_result"
echo " Monitor with: sacct -j $job_R_summary_result"
