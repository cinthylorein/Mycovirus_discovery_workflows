#!/usr/bin/env bash
#
#
#SBATCH -J fastqc_array
#SBATCH -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/fastqc_%A_%a.out
#SBATCH -e /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/fastqc_%A_%a.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --time=06:00:00


module load FastQC/0.12.1

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655079_1.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655079_2.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655080_1.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655080_2.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655081_1.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655081_2.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655082_1.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655082_2.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655083_1.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655083_2.fastq



# Unload module
module unload FastQC/0.12.1