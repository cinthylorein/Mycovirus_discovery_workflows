#!/bin/bash
#SBATCH -J rsem_abundance
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL
#SBATCH --output=../logs/rsem_abundance_%A_%a.out
#SBATCH --error=../logs/rsem_abundance_%A_%a.err

set -euo pipefail
set -x

# Load modules (edit versions as needed on PowerPlant)
module load rsem/1.3.0
module load bowtie2
module load samtools
module load perl/5.24.0

TRINITY_ALIGN="/usr/local/trinity/2.5.1/util/align_and_estimate_abundance.pl"
if [[ ! -x "$TRINITY_ALIGN" ]]; then
  echo "ERROR: Trinity script not executable: $TRINITY_ALIGN" >&2
  exit 1
fi

: "${CONFIG:?CONFIG not set}"
source "$CONFIG"

: "${TRIM_DIR:?TRIM_DIR not set in pipeline.env}"
: "${CONTIGS_DIR:?CONTIGS_DIR not set in pipeline.env}"
: "${ANNOTATION_DIR:?ANNOTATION_DIR not set in pipeline.env}"
: "${ACCESSIONS_FILE:?ACCESSIONS_FILE not set (path to SRR list)}"

mkdir -p "$ANNOTATION_DIR/abundance" "$ANNOTATION_DIR/abundance/logs"

# Read accessions, ignore blanks/comments, strip CRLF
mapfile -t accs < <(grep -vE '^\s*($|#)' "$ACCESSIONS_FILE" | sed 's/\r$//')
acc="${accs[$SLURM_ARRAY_TASK_ID]:-}"
if [[ -z "$acc" ]]; then
  echo "ERROR: No accession for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID" >&2
  exit 1
fi

library_id="$(basename "$acc")"
library_id="${library_id%.fastq.gz}"
library_id="${library_id%.fastq}"

contigs="${CONTIGS_DIR}/${library_id}/contigs.fasta"
if [[ ! -s "$contigs" ]]; then
  echo "ERROR: Missing contigs: $contigs" >&2
  exit 1
fi

r1="${TRIM_DIR}/${library_id}_trimmomatic_R1.fastq"
r2="${TRIM_DIR}/${library_id}_trimmomatic_R2.fastq"
single="${TRIM_DIR}/${library_id}_trimmomatic.fastq"

layout=""
if [[ -s "$r1" && -s "$r2" ]]; then
  layout="paired"
elif [[ -s "$single" ]]; then
  layout="single"
else
  echo "ERROR: Trimmed reads not found for $library_id" >&2
  echo "Expected paired: $r1 and $r2" >&2
  echo "or single: $single" >&2
  exit 1
fi

CPU="${SLURM_CPUS_PER_TASK:-1}"
workdir="${ANNOTATION_DIR}/abundance/${library_id}_rsem_work"
out_isoforms="${ANNOTATION_DIR}/abundance/${library_id}_RSEM.isoforms.results"

mkdir -p "$workdir"

if [[ "$layout" == "paired" ]]; then
  "$TRINITY_ALIGN" \
    --transcripts "$contigs" \
    --seqType fq \
    --left "$r1" \
    --right "$r2" \
    --est_method RSEM \
    --aln_method bowtie2 \
    --output_dir "$workdir" \
    --thread_count "$CPU" \
    --prep_reference
else
  "$TRINITY_ALIGN" \
    --transcripts "$contigs" \
    --seqType fq \
    --single "$single" \
    --est_method RSEM \
    --aln_method bowtie2 \
    --output_dir "$workdir" \
    --thread_count "$CPU" \
    --prep_reference
fi

# Collect result
isoforms_file="$(ls -1 "$workdir"/*RSEM.isoforms.results 2>/dev/null | head -n 1 || true)"
if [[ -z "$isoforms_file" || ! -s "$isoforms_file" ]]; then
  echo "ERROR: RSEM isoforms results not found in $workdir" >&2
  ls -lah "$workdir" >&2 || true
  exit 1
fi

cp -f "$isoforms_file" "$out_isoforms"

# Optional cleanup
rm -f "$workdir"/bowtie2.bam 2>/dev/null || true

echo "Done: $library_id -> $out_isoforms"