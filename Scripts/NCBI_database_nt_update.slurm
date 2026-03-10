#!/bin/bash

#SBATCH -J NCBI_database_update
#SBATCH -o /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/NCBI_database_update_%A_%a.out
#SBATCH -e /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/NCBI_database_update_%A_%a.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=10G
#SBATCH --time=22:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL

#################
#From your list the protein databases are (most relevant first):

#refseq_protein — RefSeq protein sequences (good, curated, relatively comprehensive)
#nr — NCBI non‑redundant protein database (very comprehensive, large)
#swissprot — UniProt/Swiss‑Prot (curated, smaller, high quality)
#env_nr, tsa_nr — specialized protein sets (environmental/translated shotgun assemblies)
#pdbaa — protein sequences from the PDB (structure sequences)
#refseq_select_prot — a selected subset of RefSeq proteins
#Which to use

#For general protein similarity searches: use refseq_protein or nr. nr is largest and most sensitive but slower and much bigger.
#For higher precision / fewer false positives and faster results: swissprot.
#For viral protein searches: refseq_protein is a good balance; if you need maximum sensitivity use nr (or a virus‑specific protein DB if you have one).
#If you want speed and you have many queries, consider DIAMOND with a protein DB (DIAMOND uses the same FASTA DBs but is far faster for large searches).

 module load ncbi-blast/2.11.0

DBDIR="/input/genomic/viral/NCBI_DBs/nt_09122025"

update_blastdb.pl --decompress --passive --source "DBDIR" nt 
