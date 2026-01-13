#!/bin/bash

#Step III: TRIMMOMATIC
# Now that the reads are filtered, we will remove adapters, over-represented sequences, and poor-quality bases from the reads
# The command specifies that bases with quality scores less than 30 will be clipped
# Also, after clipping, the min length for a read will be 50 bp
# The `Illumina.fa` file contains the TruSeq adapter sequences and homo-polymer sequences to clip
# This file needs to be edited to contain the appropriate sequences.
# The input for this step are the SortMeRNA filtered reads
# The output are the trimmed reads

# Run the Trimmomatic program on the filtered data to remove Illumina adapters, homo-polymers, and low quality reads:
  # Note that to do this, it is necessary to edit the file containing the adapter sequences
  # to include all sequences that you wish to remove:
  # This file is called Illumina.fa and is in the 000.raw directory.

#set -euo pipefail
# Defining paths

echo "Defining global variables and directories" 

PROJECT="/workspace/hraczj/Phytophthora_VirusDiscovery_2022/"
TRIM_OUT="${PROJECT}/002.trimmomatic"
UNPAIRED="${TRIM_OUT}/unpaired"
LOG_DIR="${TRIM_OUT}/logs"
TRIMMOMATIC="/workspace/cflcyd/software/Trimmomatic/Trimmomatic-0.39/trimmomatic-0.39.jar"
# Set the path to the adapter file:
CLIP="/workspace/hraczj/Virus_discovery_workflow/adapters/Illumina.fa"


mkdir -p $UNPAIRED
mkdir -p $LOG_DIR


#Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Submitting Trimmomatic jobs for files in: ${PROJECT}"


#Submit FastQC job based on input files 

sbatch --export=TRIMMOMATIC="$TRIMMOMATIC",LOG_DIR="$LOG_DIR",TRIM_OUT="$TRIM_OUT",UNPAIRED="$UNPAIRED",PROJECT="$PROJECT",CLIP="$CLIP" pipeline_trim.slurm 

echo "Submitted ${#job_ids[@]} jobs."
echo "Monitor with: sacct -j $(IFS=,; echo "${job_ids[*]}")"
# It is critical to set the -X settings for Java for the program to run correctly
# Here, the VM is instantiated with 8GB of heap space, with a max of 8GB...
