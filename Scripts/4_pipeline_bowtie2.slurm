#!/usr/bin/env bash
#SBATCH -J Bowtie_align
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=12:00:00

set -euo pipefail
set -x

module load bowtie2/2.3.4.3

: "${CONFIG:?CONFIG not set}"
source "$CONFIG"

: "${INDEX_DIR:?INDEX_DIR not set}"
: "${MAP_IN:?MAP_IN not set}"
: "${MAP_OUT:?MAP_OUT not set}"
: "${MAP_LOG:?MAP_LOG not set}"

mkdir -p "$MAP_OUT" "$MAP_LOG"

find_trimmed_r1_files() {
  local dir="$1"
  find "$dir" -maxdepth 1 -type f \( \
      -name '*_trimmomatic_R1.fastq'    -o \
      -name '*_trimmomatic_R1.fastq.gz' -o \
      -name '*_trimmomatic_R1.fq'       -o \
      -name '*_trimmomatic_R1.fq.gz' \
    \) | sort
}

mapfile -t read1_list < <(find_trimmed_r1_files "$MAP_IN")

if (( ${#read1_list[@]} == 0 )); then
  echo "ERROR: No trimmed R1 files found in $MAP_IN" >&2
  echo "Supported patterns: *_trimmomatic_R1.fastq, *_trimmomatic_R1.fastq.gz, *_trimmomatic_R1.fq, *_trimmomatic_R1.fq.gz" >&2
  exit 1
fi

TASK_ID="${SLURM_ARRAY_TASK_ID:-0}"
R1="${read1_list[$TASK_ID]:-}"

if [[ -z "$R1" ]]; then
  echo "ERROR: No R1 for task $TASK_ID (n=${#read1_list[@]})" >&2
  exit 1
fi

base="$(basename "$R1")"

if [[ "$base" == *_trimmomatic_R1.fastq.gz ]]; then
  LABEL="${base%_trimmomatic_R1.fastq.gz}"
  R2="${MAP_IN}/${LABEL}_trimmomatic_R2.fastq.gz"
  ext="fastq.gz"
elif [[ "$base" == *_trimmomatic_R1.fq.gz ]]; then
  LABEL="${base%_trimmomatic_R1.fq.gz}"
  R2="${MAP_IN}/${LABEL}_trimmomatic_R2.fq.gz"
  ext="fq.gz"
elif [[ "$base" == *_trimmomatic_R1.fastq ]]; then
  LABEL="${base%_trimmomatic_R1.fastq}"
  R2="${MAP_IN}/${LABEL}_trimmomatic_R2.fastq"
  ext="fastq"
elif [[ "$base" == *_trimmomatic_R1.fq ]]; then
  LABEL="${base%_trimmomatic_R1.fq}"
  R2="${MAP_IN}/${LABEL}_trimmomatic_R2.fq"
  ext="fq"
else
  echo "ERROR: Unsupported R1 filename: $base" >&2
  exit 1
fi

if [[ ! -f "$R2" ]]; then
  echo "ERROR: Missing mate R2 for $LABEL. Expected: $R2" >&2
  exit 1
fi

INDEX_BASE="${INDEX_DIR}/host"

# Bowtie2 inserts .1 and .2 before the extension
UNMAPPED_PREFIX="${MAP_OUT}/${LABEL}.non-host.fq.gz"

echo "[$LABEL] Running Bowtie2 alignment..."
echo "R1=$R1"
echo "R2=$R2"
echo "INDEX_BASE=$INDEX_BASE"
echo "UNMAPPED_PREFIX=$UNMAPPED_PREFIX"

THREADS="${SLURM_CPUS_PER_TASK:-2}"

bowtie2 --end-to-end --sensitive -p "$THREADS" -x "$INDEX_BASE" \
  -1 "$R1" -2 "$R2" \
  --un-conc-gz "$UNMAPPED_PREFIX" \
  -S /dev/null

echo "[$LABEL] Done. Non-host reads written with prefix: $UNMAPPED_PREFIX"

module unload bowtie2/2.3.4.3