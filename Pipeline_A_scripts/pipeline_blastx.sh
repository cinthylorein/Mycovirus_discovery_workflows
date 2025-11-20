## Blastx for Phytophthora Virus Discovery RNA-seq data RNA1, 2, 3 samples
#Redoing the analysis with "sacc" that means Subject accession rather than sseqid as this has other text such as ref|| which makes it difficult to merge datasets later

IN="/workspace/hraczj/Phytophthora_VirusDiscovery_2022/005.rnaviralspades/"
###loop forcalling multiple folder call them rnaviralspades,1, 2 so on
OUT="/workspace/hraczj/Phytophthora_VirusDiscovery_2022/009.blastx/"
LOG="$OUT/logs"

mkdir -p $OUT
mkdir -p $LOG

BLASTDB="/workspace/hrakmc/DBs/NCBI_RefVirus_DB_2AUG2022"

#Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Submitting SPADES job"
job_blastx=$(sbatch --parsable --export=ALL,IN="$IN",OUT="$OUT",LOG="$LOG",BLASTDB="$BLASTDB" pipeline_blastx.slurm)


echo " Submitted jobs:"
echo "   └─ Running blastx:   Job ID $job_blastx"
echo " Monitor with: sacct -j $job_blastx"




