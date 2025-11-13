#!/bin/bash


#SBATCH -J blastn
#SBATCH -o ${LOG}/blastn.out
#SBATCH -e ${LOG}/blastn.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL


 
module load ncbi-blast/2.11.0 


blastn -db $BLASTDB -query $IN -outfmt '6 qseqid sacc pident staxid ssciname length mismatch gapopen qstart qend sstart send evalue bitscore qlen'  -max_target_seqs 5 -out $OUT/PhytophthoraVirus_2022_RNA1_nt_names.csv


module unload ncbi-blast/2.11.0

