#!/bin/bash

#Extracting and de novo assembly
#Step I: BOWTIE2 - MAKING REF INDEX</u>
#The aim is to next step is to match the reads to host genome and remove host reads.
#To achieve this task, we must first build the index that will be used as the reference.

echo "Defining global variables and directories" 

PROJECT="/workspace/hraczj/Phytophthora_VirusDiscovery_2022/"
BOWTIE_OUT="$PROJECT/010.PhytophthoraHostIndex"
LOG_DIR="${BOWTIE_OUT}/logs"
REF="/input/genomic/viral/Phytophthora/P_agathidicida_3770_56996300_v2.fna"
INDEX="${BOWTIE_OUT}/bt2index"
#MAP_IN="$PROJECT/002.trimmomatic"
MAP_IN="/workspace/hrakmc/PhytophthoraVirus_Discovery_2022/002.trimmomatic/"
MAP_OUT="$PROJECT/004.MapPhytophthora"
MAP_LOG="$MAP_OUT/logs"

mkdir -p $BOWTIE_OUT
mkdir -p $LOG_DIR
mkdir -p $MAP_IN
mkdir -p $MAP_OUT
mkdir -p $MAP_LOG


##Unzip reference genom if it is necessary
##gunzip $PROJECT/Sclerotinia_sclerotiorum_GCA_000146945.2_ASM14694v2_genomic.fna.gz

mkdir -p $INDEX

#Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Submitting Bowtie2 index build job..."
job_index=$(sbatch --parsable --export=ALL,REF="$REF",INDEX="$INDEX",LOG_DIR="$LOG_DIR" pipeline_bowtie2_build_index.slurm)

echo "Submitting Bowtie2 alignment job array..."
#job_align=$(sbatch --parsable --export=ALL,INDEX="$INDEX",MAP_IN="$MAP_IN",MAP_OUT="$MAP_OUT",MAP_LOG="$MAP_LOG" pipeline_bowtie2.slurm)
job_align=$(sbatch --parsable --dependency=afterok:$job_index \
   --export=ALL,INDEX="$INDEX",MAP_IN="$MAP_IN",MAP_OUT="$MAP_OUT",MAP_LOG="$MAP_LOG" \
   pipeline_bowtie2.slurm)

echo " Submitted jobs:"
echo "   └─ Bowtie2 index:   Job ID $job_index"
echo "   └─ Bowtie2 align:   Job ID $job_align (after index build)"
echo " Monitor with: sacct -j $job_index,$job_align"
# It is critical to set the -X settings for Java for the program to run correctly
# Here, the VM is instantiated with 8GB of heap space, with a max of 8GB...
