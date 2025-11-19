#!/bin/bash


PROJECT="/workspace/hraczj/Phytophthora_VirusDiscovery_2022/"
SPADES_IN="$PROJECT"/004.MapPhytophthora
SPADES_OUT="$PROJECT"/005.rnaviralspades
SPADES_LOG="$SPADES_OUT"/logs

mkdir -p $SPADES_OUT
mkdir -p $SPADES_LOG


#Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Submitting SPADES job"
job_spades=$(sbatch --parsable --export=ALL,SPADES_IN="$SPADES_IN",SPADES_OUT="$SPADES_OUT",SPADES_LOG="$SPADES_LOG" pipeline_spades.slurm)


echo " Submitted jobs:"
echo "   └─ Spades assembler:   Job ID $job_spades"
echo " Monitor with: sacct -j $job_spades"

