#!/bin/bash

#SBATCH -J BowtieBuildPhytophthora
#SBATCH -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/Indexhost_%A_%a.out
#SBATCH -e /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/Indexhost_%A_%a.err 
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=00:30:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL
 
# Load the Bowtie2 module:
module load bowtie2/2.3.4.3

#Step 1: Build Bowtie2 index
echo "Building Bowtie2 index from reference: $REF"
if bowtie2-build "$REF" "$INDEX"; then
	printf "Bowtie2 index built successfully at: %s\n" "$INDEX"
else
    printf "Failed to build Bowtie2 index for: %s\n" "$REF" >&2
    exit 1
fi