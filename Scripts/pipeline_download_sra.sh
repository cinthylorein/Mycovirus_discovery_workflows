#!/usr/bin/env bash
#
# Simple wrapper to submit pipeline_download_sra.slurm as a Slurm job array.
# Edit the variables below or set them in the environment before running.
#
# Usage (edit variables in the script) or:
#   ROOT_PROJECT=yourroot PROJECT=yourproj ACCESSIONS=/path/to/list.txt MAIL=you@x ./pipeline_download_sra.sh
#
set -euo pipefail

echo "Defining global variables and directories"


# Ensure required vars are exported from the .sh wrapper
inpath="/workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/accession_lists"
file_of_accessions="${inpath}/accessions.txt"

#Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Downloading metatranscriptomes from SRA-NCBI in: ${inpath}"


#Submit FastQC job based on input files 

job_sra=$(sbatch --export=inpath="$inpath",file_of_accessions="$file_of_accessions" pipeline_download_sra.slurm) 

echo " Submitted jobs:"
echo "   └─ sratoolkit index: $job_sra"
echo " Monitor with: sacct -j $job_sra"
# It is critical to set the -X settings for Java for the program to run correctly
# Here, the VM is instantiated with 8GB of heap space, with a max of 8GB...
