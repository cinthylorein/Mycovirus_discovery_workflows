#!/bin/bash
#SBATCH --job-name=ascp_SRA_download
#SBATCH --output=/project/%x/logs/sra_download_%A_%a_stdout.txt
#SBATCH --error=/project/%x/logs/sra_download_%A_%a_stderr.txt
#SBATCH --cpus-per-task=2
#SBATCH --mem=30G
#SBATCH --time=12:00:00
#SBATCH --array=0-9  # Replace with the actual number of jobs minus 1
#SBATCH --mail-user=your.email@example.com
#SBATCH --mail-type=ALL

module load kingfisher
module load sratoolkit/2.11.0

# Ensure required vars are exported from the .sh wrapper
inpath="/scratch/$root_project/$project/raw_reads"
cd "$inpath" || exit 1

readarray -t myarray <"$file_of_accessions"
library_id="${myarray[$SLURM_ARRAY_TASK_ID]}"

kingfisher get -r "$library_id" -m ena-ascp ena-ftp prefetch aws-http aws-cp --force --prefetch-max-size 100000000 --output-format-possibilities fastq.gz fastq

# Single-end handling
if [[ (-f "$inpath"/"$library_id".sra.fastq || -f "$inpath"/"$library_id".fastq) && (! -f "$inpath"/"$library_id".sra.fastq.gz || ! -f "$inpath"/"$library_id".fastq.gz) ]]; then
    gzip -c "$inpath"/"$library_id".fastq >"$inpath"/"$library_id".fastq.gz || gzip -c "$inpath"/"$library_id".sra.fastq >"$inpath"/"$library_id".fastq.gz
    rm -f "$inpath"/"$library_id".fastq "$inpath"/"$library_id".sra.fastq
fi

# Paired-end handling
if [[ (-f "$inpath"/"$library_id".sra_1.fastq || -f "$inpath"/"$library_id"_1.fastq) && (-f "$inpath"/"$library_id".sra_2.fastq || -f "$inpath"/"$library_id"_2.fastq) ]]; then
    gzip -c "$inpath"/"$library_id"_1.fastq >"$inpath"/"$library_id"_1.fastq.gz || gzip -c "$inpath"/"$library_id".sra_1.fastq >"$inpath"/"$library_id"_1.fastq.gz
    gzip -c "$inpath"/"$library_id"_2.fastq >"$inpath"/"$library_id"_2.fastq.gz || gzip -c "$inpath"/"$library_id".sra_2.fastq >"$inpath"/"$library_id"_2.fastq.gz
    rm -f "$inpath"/"$library_id"_1.fastq "$inpath"/"$library_id"_2.fastq "$inpath"/"$library_id".sra_1.fastq "$inpath"/"$library_id".sra_2.fastq
fi

# Retry if _2 missing
if [[ -f "$inpath"/"$library_id"_1.fastq.gz && ! -f "$inpath"/"$library_id"_2.fastq.gz ]]; then
    kingfisher get -r "$library_id" -m ena-ascp ena-ftp prefetch --force --prefetch-max-size 100000000 --output-format-possibilities fastq.gz fastq
fi

# Retry if _1 missing
if [[ ! -f "$inpath"/"$library_id"_1.fastq.gz && -f "$inpath"/"$library_id"_2.fastq.gz ]]; then
    kingfisher get -r "$library_id" -m ena-ascp ena-ftp prefetch --force --prefetch-max-size 100000000 --output-format-possibilities fastq.gz fastq
fi

# Re-gzip corrupt files
for i in "$inpath"/"${library_id}"*.gz; do
    if ! gzip -t "$i"; then
        mv "$i" "$inpath"/temp_"$library_id"_file
        gzip -c "$inpath"/temp_"$library_id"_file >"$i"
        rm -f "$inpath"/temp_"$library_id"_file
    fi
done

# Cleanup
rm -f "$inpath"/"$library_id"*aria2* "$inpath"/"$library_id"*.aspera-ckpt "$inpath"/"$library_id"*.partial*
