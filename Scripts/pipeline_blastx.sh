#!/bin/bash

## Blastx for Phytophthora Virus Discovery RNA-seq data RNA1, 2, 3 samples
#Redoing the analysis with "sacc" that means Subject accession rather than sseqid as this has other text such as ref|| which makes it difficult to merge datasets later

IN="/workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/contigs"
###loop forcalling multiple folder call them rnaviralspades,1, 2 so on
OUT="/workspace/hraczj/Epichloe_mycoviruses/MVoPvirome/MVoP_pipeline/blast_results"
LOG="$OUT/logs"
BLASTDBnt="/input/genomic/viral/DBs/nr_09122025/nr"
#NCBI_NonHumanViral_nt_May2025
BLASTDBRsRP="/input/genomic/viral/DBs/RdRp-scan/nr"
BLASTDBRVDB="/input/genomic/viral/DBs/RVDB/" 


mkdir -p $OUT
mkdir -p $LOG


#Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Submitting blastx job"
job_blastx_nr=$(sbatch --parsable --export=ALL,IN="$IN",OUT="$OUT",LOG="$LOG",BLASTDBnt="$BLASTDBnt" pipeline_blastx_nr.slurm)

echo "Submitting BLASTDBRsRP alignment job array..."

job_blastx_BLASTDBRsRP=$(sbatch --parsable --export=ALL,IN="$IN",OUT="$OUT",LOG="$LOG",BLASTDBRsRP="$BLASTDBRsRP" pipeline_blastx_RsRP.slurm)

#echo "Submitting Bowtie2 alignment job array..."

#job_blastx_BLASTDBRVDB=$(sbatch --parsable --export=ALL,IN="$IN",OUT="$OUT",LOG="$LOG",BLASTDBRVDB="$BLASTDBRVDB" pipeline_blastx_RVDB.slurm)

echo " Submitted jobs:"
echo "   └─ Running blastx_nr:   Job ID $job_blastx_nr"
echo "   └─ Running blastx_BLASTDBRsRP:   Job ID $job_blastx_nr"
echo "   └─ Running blastx_BLASTDBRVDB:   Job ID $job_blastx_BLASTDBRVDB"
echo " Monitor with: sacct -j $job_blastx_nr,$job_blastx_BLASTDBRsRP,$job_blastx_BLASTDBRVDB"
