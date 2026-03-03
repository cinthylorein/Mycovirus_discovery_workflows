#!/bin/bash

#SBATCH -J Bowtie_align
#SBATCH -o /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/Bowtie_align_%A_%a.out
#SBATCH -e /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/Bowtie_align_%A_%a.err
#SBATCH --array=0-2
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=12:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=END,FAIL
 
# Load the Bowtie2 module:
module load bowtie2/2.3.4.3


# Sample prefixes for each job index
SAMPLES=(SRR11783518 SRR11783490 SRR11783495)
LABEL="${SAMPLES[$SLURM_ARRAY_TASK_ID]}"

# Input files
R1="${MAP_IN}/${LABEL}_trimmomatic_R1.fq"
R2="${MAP_IN}/${LABEL}_trimmomatic_R2.fq"
UNMAPPED="${MAP_OUT}/${LABEL}.non-host.fq.gz"

# Step 2: Run Bowtie2 alignment using the index
#generate loop for multiples RNAR1_1_trimmomatic....
echo "[$LABEL] Running Bowtie2 alignment..."

if bowtie2 --end-to-end --sensitive -p 2 -x "$INDEX" \
    -1 "$R1" -2 "$R2" \
    --un-conc-gz "$UNMAPPED" -S /dev/null; then
    printf "[%s] Bowtie2 alignment completed successfully.\n" "$LABEL"
else
    printf "[%s] Bowtie2 alignment failed.\n" "$LABEL" >&2
    exit 1
fi

echo "Bowtie2 alignment completed. Non-host reads saved to: ${MAP_OUT}/.non-host.fq.gz"


module unload bowtie2/2.3.4.3