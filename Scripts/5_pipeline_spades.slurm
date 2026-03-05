#!/bin/bash
#SBATCH -J rnaviralspades
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL

set -euo pipefail
set -x

: "${CONFIG:?CONFIG not set}"
source "$CONFIG"

: "${SPADES_IN:?SPADES_IN not set}"
: "${SPADES_OUT:?SPADES_OUT not set}"
: "${SPADES_LOG:?SPADES_LOG not set}"

mkdir -p "$SPADES_OUT" "$SPADES_LOG"

# Must match wrapper's discovery logic/order
shopt -s nullglob

r1_list=( "$SPADES_IN"/*.non-host.fq.1.gz )

if (( ${#r1_list[@]} == 0 )); then
  echo "ERROR: No non-host R1 files found in $SPADES_IN (expected *.non-host*.1)" >&2
  exit 1
fi

r1="${r1_list[$SLURM_ARRAY_TASK_ID]:-}"
if [[ -z "$r1" ]]; then
  echo "ERROR: No r1 for task $SLURM_ARRAY_TASK_ID (n=${#r1_list[@]})" >&2
  exit 1
fi

r2="${r1/.fq.1.gz/.fq.2.gz}"
if [[ ! -s "$r2" ]]; then
  echo "ERROR: Missing r2 mate. Expected: $r2" >&2
  exit 1
fi

# Derive label from filename:
# Example r1: /mapping/SRR11783490.non-host.fq.gz.1
base="$(basename "$r1")"
label="${base%%.non-host.fq.1.gz}"

outdir="${SPADES_OUT}/${label}"

threads="${SLURM_CPUS_PER_TASK:-8}"
# SPAdes expects memory in GB as integer
mem_gb=64

module load SPAdes/4.0.0

echo "Running rnaviralspades for label=$label"
echo "r1=$r1"
echo "r2=$r2"
echo "outdir=$outdir"
echo "threads=$threads mem_gb=$mem_gb"


# Optional: keep a per-sample log file too
sample_log="${SPADES_LOG}/${label}.spades.log"

# Make SPAdes-friendly names (symlinks) inside output folder
mkdir -p "$outdir"
link_r1="${outdir}/${label}.non-host_1.fq.gz"
link_r2="${outdir}/${label}.non-host_2.fq.gz"

ln -sf "$r1" "$link_r1"
ln -sf "$r2" "$link_r2"

rnaviralspades.py \
  --pe1-1 "$link_r1" --pe1-2 "$link_r2" \
  -o "$outdir" \
  --threads "$threads" \
  --memory "$mem_gb" \
  > "$sample_log" 2>&1

module unload SPAdes/4.0.0
echo "Done label=$label"