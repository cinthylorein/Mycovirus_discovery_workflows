#!/bin/bash

# This script runs Trimmomatic on all pairs matching SRR*_1.fastq / SRR*_2.fastq
# Submit with sbatch trim_loop.sh
#
# SBATCH directives (adjust as needed)
#SBATCH -J TRIM
#SBATCH -o /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/Trim2.out
#SBATCH -e /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/Trim2.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=10:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL

set -euo pipefail

# Required environment variables (must be set before running)
: "${PROJECT:?Need to set PROJECT (path to project root)}"
: "${TRIMMOMATIC:?Need to set TRIMMOMATIC (path to trimmomatic .jar)}"
: "${CLIP:?Need to set CLIP (path to adapter file for ILLUMINACLIP)}"
: "${TRIM_OUT:?Need to set TRIM_OUT (directory for paired output)}"
: "${UNPAIRED:?Need to set UNPAIRED (directory for unpaired output)}"

# Use SLURM-provided CPUs if available, otherwise fallback to 2
THREADS=${SLURM_CPUS_PER_TASK:-2}

# Make sure output directories exist
mkdir -p "${TRIM_OUT}"
mkdir -p "${UNPAIRED}"

# Memory settings for Java - adjust if needed (use environment or SLURM if desired)
JAVA_MIN_MEM=4G
JAVA_MAX_MEM=4G

# Loop over all read1 files that match SRR*_1.fastq
shopt -s nullglob
read1_list=( "${PROJECT}/raw_reads"/SRR*_1.fastq )
if [ ${#read1_list[@]} -eq 0 ]; then
  echo "No SRR*_1.fastq files found in ${PROJECT}/raw_reads. Exiting."
  exit 1
fi

for read1 in "${read1_list[@]}"; do
  # derive sample prefix like SRR000001
  prefix=$(basename "${read1%_1.fastq}")
  read2="${PROJECT}/raw_reads/${prefix}_2.fastq"

 if [[ ! -f "${read2}" ]]; then
    echo "Paired file missing for ${prefix}: expected ${read2}. Skipping."
    continue
  fi

  Out_PAIRED_1="${TRIM_OUT}/${prefix}_trimmomatic_R1.fq"
  Out_UNPAIRED_1="${UNPAIRED}/${prefix}_trimmomatic_unpaired_1.fq"
  Out_PAIRED_2="${TRIM_OUT}/${prefix}_trimmomatic_R2.fq"
  Out_UNPAIRED_2="${UNPAIRED}/${prefix}_trimmomatic_unpaired_2.fq"

  echo "Starting trimming for ${prefix} (threads=${THREADS})"
  # run Trimmomatic (PE mode)
  java -jar -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} \
    "${TRIMMOMATIC}" PE -threads "${THREADS}" \
    "${read1}" "${read2}" \
    "${Out_PAIRED_1}" "${Out_UNPAIRED_1}" "${Out_PAIRED_2}" "${Out_UNPAIRED_2}" \
    ILLUMINACLIP:"${CLIP}":2:30:10 SLIDINGWINDOW:5:20 MINLEN:50 \
    > "${TRIM_OUT}/${prefix}.trimmomatic.log" 2>&1 || {
      echo "Trimmomatic failed for ${prefix}. See ${TRIM_OUT}/${prefix}.trimmomatic.log"
      # continue to next sample rather than exiting the whole job
      continue
    }

  echo "Finished ${prefix}. Paired outputs: ${Out_PAIRED_1}, ${Out_PAIRED_2}"
done

echo "All done."