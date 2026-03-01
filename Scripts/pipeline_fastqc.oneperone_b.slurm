#!/usr/bin/env bash
#
#
#SBATCH -J fastqc_array
#SBATCH -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/fastqc_%A_%a.out
#SBATCH -e /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/logs/fastqc_%A_%a.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --time=12:00:00


module load FastQC/0.12.1

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655084_1.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655084_2.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655085_1.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655085_2.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655086_1.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655086_2.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655087_1.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655087_2.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655088_1.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655088_2.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655089_1.fastq

fastqc --nogroup -q -t 2 -o /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/fastqc /workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/raw_reads/SRR14655089_2.fastq



# Unload module
module unload FastQC/0.12.1