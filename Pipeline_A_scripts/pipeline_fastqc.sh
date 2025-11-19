#!/bin/bash

########################################################################
#  Mycovirus Discovery Workflow - FastQC Batch Submitter              #
#  Author: Cinthy Jimenez-Silva (2025)                                #
#                                                                      #
#  Description:                                                       #
#  This script submits a batch of FastQC jobs to the SLURM scheduler. #
########################################################################

#In this pipeline, we will run our analysis using powerPlant High-Performance computing 
#The input for this step is the raw data from the provider in FASTQ format
#The output from this step are the HTML FASTQC Reports

#Notes:
#Using Environment modules - listing
#ml list 
#To see the full list of fastQC versions  we have available
#ml avail FastQC

set -euo pipefail
# Defining paths

echo "Defining global variables and directories"

RAW_DIR="/workspace/hraczj/Phytophthora_VirusDiscovery_2022/000.raw"
#Optional: cetral output folder for FastQC reports 
FASTQC_OUT="/workspace/hraczj/Phytophthora_VirusDiscovery_2022/001.fastqc_raw"
# whre SLURM .out .err will go (frm the .slurm script) 
LOG_DIR="${FASTQC_OUT}/logs"

files=($(ls /workspace/hraczj/Phytophthora_VirusDiscovery_2022/000.raw/*.fq.gz))
threads=2


#Create output directories if they don't exist
mkdir -p "${LOG_DIR}" 

#Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Submitting FastQC jobs for files in: ${RAW_DIR}"


#Submit FastQC job based on input files 

sbatch --export=files="$files",LOG_DIR="$LOG_DIR",threads="$threads" pipeline_fastqc.slurm 

echo "Submitted ${#job_ids[@]} jobs."
echo "Monitor with: sacct -j $(IFS=,; echo "${job_ids[*]}")"

