#!/bin/bash

#This script allows us to run fastqc fr the raw and trimmed (included removed reads) 
#Note
#Always match the array size to the number of files — it’s more robust, efficient, and avoids job failures.
#--array=0-<N-1>

#SBATCH -J fastqc_array
#SBATCH --array=0-5
#SBATCH -o /workspace/hraczj/Phytophthora_VirusDiscovery_2022/001.fastqc_raw/logs/fastqc_%A_%a.out
#SBATCH -e /workspace/hraczj/Phytophthora_VirusDiscovery_2022/001.fastqc_raw/logs/fastqc_%A_%a.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --time=00:10:00

file="${files[$SLURM_ARRAY_TASK_ID]}"

# Load the FastQC module:
module load FastQC/0.12.1

if [[ -z "$threads" || -z "$LOG_DIR" ]]; then
    echo "Missing required variables: threads, or log_dir" >&2
    exit 1
fi


[[ -z "$file" ]] && { echo "No file for task ID $SLURM_ARRAY_TASK_ID"; exit 1; }

fastqc --nogroup -q -t "$threads" -o "$LOG_DIR" "$file"

printf "All jobs finished.\n"


# Unloading 

module unload FastQC/0.12.1
   

