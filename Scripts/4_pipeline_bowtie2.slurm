#!/bin/bash
#SBATCH -J Bowtie_align
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=12:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=END,FAIL

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

# Must match wrapper patterns/order
shopt -s nullglob
read1_list=( "$MAP_IN"/*_trimmomatic_R1.fastq )

if (( ${#read1_list[@]} == 0 )); then
  echo "ERROR: No trimmed R1 files found in $MAP_IN" >&2
  exit 1
fi

R1="${read1_list[$SLURM_ARRAY_TASK_ID]:-}"
if [[ -z "$R1" ]]; then
  echo "ERROR: No R1 for task $SLURM_ARRAY_TASK_ID (n=${#read1_list[@]})" >&2
  exit 1
fi

# Derive label and mate filename
LABEL="$(basename "${R1%_trimmomatic_R1.fastq}")"
R2="${MAP_IN}/${LABEL}_trimmomatic_R2.fastq"

if [[ ! -f "$R2" ]]; then
  echo "ERROR: Missing mate R2 for $LABEL. Expected: $R2" >&2
  exit 1
fi

# Index basename must match build step
INDEX_BASE="${INDEX_DIR}/host"

# Bowtie2 will create two files: <prefix>.1 and <prefix>.2 for paired reads
UNMAPPED_PREFIX="${MAP_OUT}/${LABEL}.non-host.fq.gz"

echo "[$LABEL] Running Bowtie2 alignment..."
echo "R1=$R1"
echo "R2=$R2"
echo "INDEX_BASE=$INDEX_BASE"
echo "UNMAPPED_PREFIX=$UNMAPPED_PREFIX"

# Use Slurm CPUs
THREADS="${SLURM_CPUS_PER_TASK:-2}"

bowtie2 --end-to-end --sensitive -p "$THREADS" -x "$INDEX_BASE" \
  -1 "$R1" -2 "$R2" \
  --un-conc-gz "$UNMAPPED_PREFIX" \
  -S /dev/null

echo "[$LABEL] Done. Non-host reads written with prefix: $UNMAPPED_PREFIX"
module unload bowtie2/2.3.4.3