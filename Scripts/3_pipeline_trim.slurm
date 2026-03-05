#!/bin/bash
#SBATCH -J TRIM
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=10:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL

set -euo pipefail
set -x

: "${CONFIG:?Need CONFIG exported (path to pipeline.env)}"
source "$CONFIG"

: "${TRIMMOMATIC_JAR:?Need TRIMMOMATIC_JAR (path to Trimmomatic .jar)}"
: "${CLIP:?Need CLIP (adapter fasta for ILLUMINACLIP)}"
: "${TRIM_OUT:?Need TRIM_OUT}"
: "${UNPAIRED:?Need UNPAIRED}"
: "${TRIM_LOG_DIR:?Need TRIM_LOG_DIR}"

THREADS="${SLURM_CPUS_PER_TASK:-2}"

mkdir -p "$TRIM_OUT" "$UNPAIRED" "$TRIM_LOG_DIR"

# Java memory settings (you can tune; keep consistent with SBATCH --mem)
JAVA_MIN_MEM="${JAVA_MIN_MEM:-4G}"
JAVA_MAX_MEM="${JAVA_MAX_MEM:-4G}"

shopt -s nullglob

# Support .fastq and .fastq.gz (adjust if you only want .fastq)
read1_list=( "$RAW_DIR"/SRR*_1.fastq "$RAW_DIR"/SRR*_1.fastq.gz )

if (( ${#read1_list[@]} == 0 )); then
  echo "ERROR: No SRR*_1.fastq(.gz) files found in $RAW_DIR" >&2
  exit 1
fi

read1="${read1_list[$SLURM_ARRAY_TASK_ID]:-}"
if [[ -z "$read1" ]]; then
  echo "ERROR: No read1 for task $SLURM_ARRAY_TASK_ID (n=${#read1_list[@]})" >&2
  exit 1
fi

# Determine mate + extension
if [[ "$read1" == *.fastq.gz ]]; then
  prefix="$(basename "${read1%_1.fastq.gz}")"
  read2="$RAW_DIR/${prefix}_2.fastq.gz"
  ext="fastq.gz"
else
  prefix="$(basename "${read1%_1.fastq}")"
  read2="$RAW_DIR/${prefix}_2.fastq"
  ext="fastq"
fi

if [[ ! -f "$read2" ]]; then
  echo "ERROR: Missing mate for $prefix. Expected: $read2" >&2
  exit 1
fi

Out_PAIRED_1="${TRIM_OUT}/${prefix}_trimmomatic_R1.${ext}"
Out_UNPAIRED_1="${UNPAIRED}/${prefix}_trimmomatic_unpaired_1.${ext}"
Out_PAIRED_2="${TRIM_OUT}/${prefix}_trimmomatic_R2.${ext}"
Out_UNPAIRED_2="${UNPAIRED}/${prefix}_trimmomatic_unpaired_2.${ext}"

sample_log="${TRIM_LOG_DIR}/${prefix}.trimmomatic.log"

echo "Trimming sample=${prefix}"
echo "read1=$read1"
echo "read2=$read2"
echo "threads=$THREADS"
echo "out_paired_1=$Out_PAIRED_1"
echo "out_paired_2=$Out_PAIRED_2"

java -jar -Xms"${JAVA_MIN_MEM}" -Xmx"${JAVA_MAX_MEM}" \
  "$TRIMMOMATIC_JAR" PE -threads "$THREADS" \
  "$read1" "$read2" \
  "$Out_PAIRED_1" "$Out_UNPAIRED_1" "$Out_PAIRED_2" "$Out_UNPAIRED_2" \
  ILLUMINACLIP:"$CLIP":2:30:10 SLIDINGWINDOW:5:20 MINLEN:50 \
  > "$sample_log" 2>&1

echo "Done sample=${prefix}"