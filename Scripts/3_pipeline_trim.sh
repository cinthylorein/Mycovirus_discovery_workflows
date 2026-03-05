#!/bin/bash

#Step III: TRIMMOMATIC
# Now that the reads are filtered, we will remove adapters, over-represented sequences, and poor-quality bases from the reads
# The command specifies that bases with quality scores less than 30 will be clipped
# Also, after clipping, the min length for a read will be 50 bp
# The `Illumina.fa` file contains the TruSeq adapter sequences and homo-polymer sequences to clip
# This file needs to be edited to contain the appropriate sequences.
# The input for this step are the SortMeRNA filtered reads
# The output are the trimmed reads

# Run the Trimmomatic program on the filtered data to remove Illumina adapters, homo-polymers, and low quality reads:
  # Note that to do this, it is necessary to edit the file containing the adapter sequences
  # to include all sequences that you wish to remove:
  # This file is called Illumina.fa and is in the 000.raw directory.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

source "$CONFIG"

# ---- Tool locations (cluster-specific; keep here, not inside slurm) ----
TRIMMOMATIC_JAR="${TRIMMOMATIC_JAR:-/workspace/cflcyd/software/Trimmomatic/Trimmomatic-0.39/trimmomatic-0.39.jar}"
CLIP="${CLIP:-${ADAPTER_DIR}/Illumina.fa}"

# ---- Output dirs (from config) ----
TRIM_OUT="$TRIM_DIR"
UNPAIRED="${TRIM_DIR}/unpaired"
TRIM_LOG_DIR="${TRIM_DIR}/logs"

mkdir -p "$LOG_DIR" "$TRIM_OUT" "$UNPAIRED" "$TRIM_LOG_DIR"

# Optional: fail early if inputs/tools missing
if [[ ! -f "$TRIMMOMATIC_JAR" ]]; then
  echo "ERROR: Trimmomatic jar not found: $TRIMMOMATIC_JAR" >&2
  exit 1
fi
if [[ ! -f "$CLIP" ]]; then
  echo "ERROR: Adapter file not found: $CLIP" >&2
  exit 1
fi

echo "Submitting Trimmomatic job"
echo "RAW_DIR=$RAW_DIR"
echo "TRIM_OUT=$TRIM_OUT"
echo "UNPAIRED=$UNPAIRED"
echo "CLIP=$CLIP"
echo "TRIMMOMATIC_JAR=$TRIMMOMATIC_JAR"

# Build list of read1 files to size the array (same patterns as slurm)
mapfile -t read1_list < <(
  ls -1 "$RAW_DIR"/SRR*_1.fastq "$RAW_DIR"/SRR*_1.fastq.gz 2>/dev/null || true
)

if (( ${#read1_list[@]} == 0 )); then
  echo "ERROR: No SRR*_1.fastq(.gz) files found in $RAW_DIR" >&2
  exit 1
fi

array_max=$((${#read1_list[@]} - 1))
echo "Submitting Trimmomatic array: ${#read1_list[@]} samples (0..$array_max)"


job_trim=$(sbatch --parsable \
  --array=0-"$array_max" \
  --export=ALL,CONFIG="$CONFIG",TRIMMOMATIC_JAR="$TRIMMOMATIC_JAR",CLIP="$CLIP",TRIM_OUT="$TRIM_OUT",UNPAIRED="$UNPAIRED",TRIM_LOG_DIR="$TRIM_LOG_DIR" \
  --output="${LOG_DIR}/trim_%A_%a.out" \
  --error="${LOG_DIR}/trim_%A_%a.err" \
  3_pipeline_trim.slurm)

echo "Submitted: $job_trim"
echo "Monitor: sacct -j $job_trim"
