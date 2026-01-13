#!/bin/bash

#This script runs trimming using Trimal tools, startng with Trimmomatic 

#SBATCH -J TRIM
#SBATCH -o /workspace/hraczj/Phytophthora_VirusDiscovery_2022/002.trimmomatic/logs/Trim2.out
#SBATCH -e /workspace/hraczj/Phytophthora_VirusDiscovery_2022/002.trimmomatic/logs/Trim2.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:10:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL

In_File1=$PROJECT/000.raw/RNAR3_1.fq.gz
In_File2=$PROJECT/000.raw/RNAR3_2.fq.gz
Out_PAIRED_1=${TRIM_OUT}/RNAR3_1_trimmomatic_R1.fq
Out_UNPAIRED_1=${UNPAIRED}/RNAR3_1_trimmomatic_unpaired_1.fq
Out_PAIRED_2=${TRIM_OUT}/RNAR3_2_trimmomatic_R2.fq
Out_UNPAIRED_2=${UNPAIRED}/RNAR3_2_trimmomatic_unpaired_2.fq

# Load the Trimmomatic module:
module load Trimmomatic/0.39


java -jar -Xms8G -Xmx8G \
                 ${TRIMMOMATIC} PE -threads 3 \
                <(zcat ${In_File1}) <(zcat ${In_File2}) \
                 ${Out_PAIRED_1} ${Out_UNPAIRED_1} ${Out_PAIRED_2} ${Out_UNPAIRED_2} \
                 ILLUMINACLIP:${CLIP}:2:30:10 SLIDINGWINDOW:5:20 MINLEN:50
				 
				 
module unload Trimmomatic/0.36