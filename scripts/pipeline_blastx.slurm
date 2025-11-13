#!/bin/bash
#SBATCH -J blastxPa1
#SBATCH -o ${LOG}/blastxPa1.out
#SBATCH -e ${LOG}/blastxPa1.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:10:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL
 
# Load the ncbi-blast module:
module load ncbi-blast/2.11.0

blastx -db $BLASTDB -query $IN -outfmt '6 qseqid sacc pident staxid ssciname length mismatch gapopen qstart qend sstart send evalue bitscore qlen'  -max_target_seqs 5 -out $OUT/PhytophthoraVirus_Discovery_RNA1_aa_names.csv

module unload ncbi-blast/2.11.0