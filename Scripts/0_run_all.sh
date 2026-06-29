#!/usr/bin/env bash
set -euo pipefail

echo "Starting virus discovery pipeline (dependency chained)..."

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

# Helper: submit a wrapper script and capture the job id (must print --parsable output)
submit_step() {
  local dep="${1:-}"   # dependency job id, or empty
  local name="$2"
  local cmd="$3"

  echo "Submitting: $name"
  if [[ -n "$dep" ]]; then
    # pass dependency down to wrapper
    job_id="$(DEPENDENCY="$dep" bash -lc "$cmd")"
  else
    job_id="$(bash -lc "$cmd")"
  fi

  # keep only the first token (some wrappers may echo extra text)
  job_id="$(echo "$job_id" | head -n 1 | tr -d '[:space:]')"

  if [[ -z "$job_id" ]]; then
    echo "ERROR: $name wrapper did not return a job id" >&2
    exit 1
  fi

  echo "  job_id=$job_id"
  echo "$job_id"
}

# IMPORTANT:
# Your wrappers must support DEPENDENCY by adding:
#   dep_opt=()
#   [[ -n "${DEPENDENCY:-}" ]] && dep_opt=(--dependency="afterok:${DEPENDENCY}")
# and then calling sbatch "${dep_opt[@]}" --parsable ...

job_fastqc="$(submit_step "" "FastQC"       "${SCRIPT_DIR}/2_pipeline_fastqc.sh")"
job_trim="$(submit_step "$job_fastqc" "Trimmomatic" "${SCRIPT_DIR}/3_pipeline_trim.sh")"
job_bowtie="$(submit_step "$job_trim"  "Bowtie2"     "${SCRIPT_DIR}/4_pipeline_bowtie2.sh")"
job_spades="$(submit_step "$job_bowtie" "SPAdes"     "${SCRIPT_DIR}/5_pipeline_spades.sh")"
job_blastn="$(submit_step "$job_spades" "BLASTn"     "${SCRIPT_DIR}/6_pipeline_blastn.sh")"
job_blastx="$(submit_step "$job_blastn" "BLASTx"     "${SCRIPT_DIR}/6_pipeline_blastx.sh")"
job_sum="$(submit_step "$job_blastx"    "Summary"    "${SCRIPT_DIR}/7_pipeline_summary_result.sh")"

echo ""
echo "Pipeline submitted."
echo "Final job (Summary) id: $job_sum"
echo "Monitor with: squeue -j $job_fastqc,$job_trim,$job_bowtie,$job_spades,$job_blastn,$job_blastx,$job_sum"