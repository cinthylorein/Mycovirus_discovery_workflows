IN="PhytophthoraVirus_Discovery_2022/005.rnaviralspades/scaffolds.fasta"
OUT="PhytophthoraVirus_Discovery_2022/008.blastn/allVirus_nt_Aug2022"
LOG="$OUT/logs"

mkdir -p $OUT
mkdir -p $LOG

BLASTDB="/workspace/hrakmc/DBs/NCBI_allVirusnt_DB_AUG2022"


COMMAND="blastn -db $BLASTDB -query $IN -outfmt '6 qseqid sacc pident staxid ssciname length mismatch gapopen qstart qend sstart send evalue bitscore qlen'  -max_target_seqs 5 -out $OUT/PhytophthoraVirus_2022_RNA1_nt_names.csv"
echo $COMMAND

sbatch << EOF
#!/bin/bash
#SBATCH -J blastn1
#SBATCH -o ${LOG}/blastn1.out
#SBATCH -e ${LOG}/blastn1.err
#SBATCH --cpus-per-task=16
#SBATCH --mem=10G
#SBATCH --time=20:00:00
#SBATCH --mail-user=karmun.chooi@plantandfood.co.nz
#SBATCH --mail-type=ALL
 
# Load the ncbi-blast module:
module load ncbi-blast/2.11.0 

${COMMAND}


EOF
squeue


module unload ncbi-blast/2.11.0