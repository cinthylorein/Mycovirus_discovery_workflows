#!/bin/bash
#SBATCH --job-name=genemark_diamond
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=06:00:00
#SBATCH --output=../logs/genemark_diamond_%A.out
#SBATCH --error=../logs/genemark_diamond_%A.err

set -euo pipefail
set -x

: "${CONFIG:?CONFIG not set}"
: "${SAMPLE:?SAMPLE not set}"
: "${HITS_TSV:?HITS_TSV not set}"
: "${OUTDIR:?OUTDIR not set}"

source "$CONFIG"

module load GeneMark/4.73
module load diamond || true
module load seqkit || true

contigs_fa="${CONTIGS_DIR}/${SAMPLE}/contigs.fasta"
[[ -s "$contigs_fa" ]] || { echo "ERROR: Missing contigs: $contigs_fa" >&2; exit 1; }
[[ -s "$HITS_TSV" ]] || { echo "ERROR: Missing TSV: $HITS_TSV" >&2; exit 1; }

mkdir -p "$OUTDIR"
cd "$OUTDIR"

# 1) select contig ids from TSV
MIN_IDENT="${MIN_IDENT:-75}"
MIN_LEN="${MIN_LEN:-1000}"
REQUIRE_COMPLETE="${REQUIRE_COMPLETE:-0}"

selected_ids="${OUTDIR}/${SAMPLE}.selected_contigs.txt"
bash "${SCRIPTS_DIR}/select_viral_contigs_from_nt_hits.sh" "$HITS_TSV" > "$selected_ids"

# 2) extract contigs
selected_fa="${OUTDIR}/${SAMPLE}.selected_contigs.fasta"
seqkit grep -f "$selected_ids" "$contigs_fa" > "$selected_fa"

# 3) GeneMark ORF prediction (COMMAND MAY NEED ADJUSTMENT)
# On many systems you might have: gmhmmp, gmsn.pl, or GeneMarkS.
# Here we leave placeholders that you can adapt once you confirm which GeneMark executable is installed.
echo "GeneMark module loaded. Now run the correct GeneMark command for viral contigs."

# Example placeholder (DO NOT TRUST until you confirm your cluster’s GeneMark program):
# gmsn.pl --sequence "$selected_fa" --output "$OUTDIR/genemark" --format GFF

# 4) DIAMOND blastp on predicted proteins (after you generate proteins.faa)
# proteins_faa="${OUTDIR}/genemark/proteins.faa"
# diamond blastp -d "$DIAMONDDB_RDRP" -q "$proteins_faa" -o "${OUTDIR}/${SAMPLE}.rdrp_diamond.tsv" -f 6 qseqid sseqid pident length evalue bitscore stitle -p "$SLURM_CPUS_PER_TASK"

echo "DONE (script skeleton). Next step: confirm GeneMark command + protein output path."