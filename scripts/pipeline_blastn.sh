


IN="/workspace/hraczj/Phytophthora_VirusDiscovery_2022/005.rnaviralspades/scaffolds.fasta"
###loop forcalling multiple folder call them rnaviralspades,1, 2 so on
OUT="/workspace/hraczj/Phytophthora_VirusDiscovery_2022/008.blastn/"
LOG="$OUT/logs"
BLASTDB="/workspace/hrakmc/DBs/NCBI_allVirusnt_DB_AUG2022"

mkdir -p $OUT
mkdir -p $LOG

#Avoid literal expansion when no files are present
shopt -s nullglob

# Track submitted job IDs
declare -a job_ids=()

echo "Submitting SPADES job"
job_blastn=$(sbatch --parsable --export=ALL,IN="$IN",OUT="$OUT",LOG="$LOG",BLASTDB="$BLASTDB" pipeline_blastn.slurm)


echo " Submitted jobs:"
echo "   └─ Running blastn:   Job ID $job_blastn"
echo " Monitor with: sacct -j $job_blastn"


