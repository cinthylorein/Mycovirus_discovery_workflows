#!/bin/bash

#SBATCH -J rnaviralspades
#SBATCH -o /workspace/hraczj/Phytophthora_VirusDiscovery_2022/005.rnaviralspades/logs/spades.out
#SBATCH -e /workspace/hraczj/Phytophthora_VirusDiscovery_2022/005.rnaviralspades/logs/spades.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --time=00:10:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL

# Sample prefixes for each job index
SAMPLES=(RNAR1 RNAR2 RNAR3)
LABEL="${SAMPLES[$SLURM_ARRAY_TASK_ID]}"

# Input files
R1="${SPADES_IN}/${LABEL}.non-Phytophthora_1.fq.gz"
R2="${SPADES_IN/${LABEL}.non-Phytophthora_2.fq.gz"



# Load the SPAdes module:
module load SPAdes/3.15.4


#writing a loop for running multiples RNAR1.non-Phytophthora_2.fq.gz, RNAR2.non-Phytophthora_2.fq.gz, RNAR3.non-Phytophthora_2.fq.gz so on
rnaviralspades.py --pe1-1 $R1 --pe1-2 $R2 -o $SPADES_OUT
		

module unload SPAdes/3.15.4