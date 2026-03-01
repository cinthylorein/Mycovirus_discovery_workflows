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

RAW_DIR="/workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads"
#Optional: cetral output folder for FastQC reports 
FASTQC_OUT="/workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc"

files=($(ls /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/*.fastq))
threads=2



#Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Submitting FastQC jobs for files in: ${RAW_DIR}"


#Submit FastQC job based on input files 

job_fqc=$(sbatch --export=files="$files",FASTQC_OUT="$FASTQC_OUT",threads="$threads" pipeline_fastqc.a.slurm) 

echo " Submitted jobs:"
echo "   └─ FastQC index:   Job ID $job_fqc"
echo " Monitor with: sacct -j $job_fqc"
# It is critical to set the -X settings for Java for the program to run correctly
# Here, the VM is instantiated with 8GB of heap space, with a max of 8GB...