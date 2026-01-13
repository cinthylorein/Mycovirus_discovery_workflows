#!/bin/bash

##################################################################
#          Virus discovery workflow							 #
#              Cinthy Jimenez-Silva								 #
#						2025								     #
##################################################################

# This bash script sets up your project with a specific structure. 
#user id workspace 

# Root directory for all projects
root="/workspace/hraczj"

# project name with refer host-enviroment
project="Phytophthora_VirusDiscovery_2022"

# email name
email="cinthy.jimenez-silva@plantandfood.co.nz"

# Define directoy paths for convenience
project_dir="${root}/${project}"



#Define subdirectories paths within project
raw="000.raw"
fastq_raw="001.fastqc_raw"
trim="002.trim"
fastqc_trim="003.fastqc_trim"
temp="temp"

#create project directories

echo "Creating project main directory"
mkdir -p "$project_dir"

echo "Creating subdirectories .."
for subdir in "$raw" "$fastq_raw" "$trim" "$fastqc_trim" "$temp"; do
    mkdir -p "${project_dir}/${subdir}"
done

echo "Setup complete for project: $project"
echo "Directories created under $project_dir"


# Create symlinks of all input fastq files and put them in $raw

# Input base path
input_base="/input/genomic/viral/Phytophthora/MGS00464_Illumina_RNA-seq/X201SC21060659-Z01-F001/raw_data"

# Project raw directory (already created in setup.sh)
RAW="${project_dir}/000.raw"


# Loop through all RNAR directories (RNAR1, RNAR2, RNAR3, …)
for rnadir in "${input_base}"/RNAR*; do
    sample=$(basename "$rnadir")   # e.g. RNAR1, RNAR2, RNAR3
    echo "Processing sample: $sample"

    # Find FASTQ files inside (paired-end assumed: *_1.fq.gz, *_2.fq.gz)
    for fq in "$rnadir"/*.fq.gz; do
        fq_name=$(basename "$fq")

        # Detect if it's R1 or R2
        if [[ "$fq_name" == *"_1.fq.gz" ]]; then
            new_name="${sample}_R1.fq.gz"
        elif [[ "$fq_name" == *"_2.fq.gz" ]]; then
            new_name="${sample}_R2.fq.gz"
        else
            # fallback if naming doesn’t follow the convention
            new_name="${sample}_${fq_name}"
        fi

        # Create symlink in RAW directory
        ln -s "$fq" "${project_dir}/000.raw/${new_name}"
        echo "  Linked $fq → ${project_dir}/000.raw/${new_name}"
    done
done

echo "All symlinks created in $RAW"
