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

#!/usr/bin/env bash
set -euo pipefail

# Find installed config (assumes wrappers are run from PROJECT_DIR/scripts)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  echo "Run 1_setup.sh first, or set CONFIG=/full/path/to/pipeline.env" >&2
  exit 1
fi

source "$CONFIG"


mapfile -t FASTQ_FILES < <(ls -1 "$RAW_DIR"/*.fastq* 2>/dev/null || true)
N="${#FASTQ_FILES[@]}"
if (( N == 0 )); then
  echo "ERROR: No FASTQ files found in $RAW_DIR" >&2
  exit 1
fi
ARRAY_MAX=$((N-1))

#Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Submitting FastQC jobs for files in: ${RAW_DIR}"


#Submit FastQC job based on input files 

job_fqc=$(sbatch --parsable \
  --array=0-"$ARRAY_MAX" \
  --export=ALL,CONFIG="$CONFIG" \
  --output="${LOG_DIR}/fastqc_%A_%a.out" \
  --error="${LOG_DIR}/fastqc_%A_%a.err" \
  2_pipeline_fastqc.slurm) 
  

echo "Submitted FastQC job: $job_fqc"
echo "Monitor with: sacct -j $job_fqc"
# It is critical to set the -X settings for Java for the program to run correctly
# Here, the VM is instantiated with 8GB of heap space, with a max of 8GB...