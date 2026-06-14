#!/usr/bin/env bash

####################################################################################
# Mycovirus Discovery Workflow - Step VII: Summary Result Submitter                #
# Author: Cinthy Jimenez-Silva (2026)                                              #
#                                                                                  #
# Description:                                                                     #
# This script submits the R-based summary/plotting step for BLAST results.         #
####################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CONFIG:-${SCRIPT_DIR}/../config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

source "$CONFIG"

: "${BLAST_DIR:?Need BLAST_DIR set in config/pipeline.env or environment}"
: "${LOG_DIR:?Need LOG_DIR set in config/pipeline.env or environment}"
: "${LOG_NT:?Need LOG_NT set in config/pipeline.env or environment}"
: "${LOG_TX:?Need LOG_TX set in config/pipeline.env or environment}"
: "${LOG_RDRP:?Need LOG_RDRP set in config/pipeline.env or environment}"
: "${BLASTDB_NT_METADATA:?Need BLASTDB_NT_METADATA set in config/pipeline.env or environment}"
: "${BLASTDB_NR_METADATA:?Need BLASTDB_NR_METADATA set in config/pipeline.env or environment}"
: "${SCRIPTS_DIR:?Need SCRIPTS_DIR set in config/pipeline.env or environment}"
: "${EMAIL:?EMAIL not set (load it in pipeline.env)}"

IN_nt="$BLAST_DIR"
IN_tx="$BLAST_DIR"
IN_rdrp="$BLAST_DIR"

mkdir -p "$LOG_NT" "$LOG_TX" "$LOG_RDRP" "$LOG_DIR"

echo "Submitting R_summary_result job"

job_R_summary_result="$(sbatch --parsable \
  --chdir="$SCRIPTS_DIR" \
  --mail-user="$EMAIL" \
  --export=ALL,CONFIG="$CONFIG",IN_nt="$IN_nt",IN_tx="$IN_tx",IN_rdrp="$IN_rdrp",LOG_nt="$LOG_NT",LOG_tx="$LOG_TX",LOG_rdrp="$LOG_RDRP",BLASTDB="$BLASTDB_NT_METADATA",BLASTDBtx="$BLASTDB_NR_METADATA" \
  --output="${LOG_DIR}/summary_%A.out" \
  --error="${LOG_DIR}/summary_%A.err" \
  "${SCRIPT_DIR}/7_pipeline_summary_result.slurm")"

if [[ -z "$job_R_summary_result" ]]; then
  echo "ERROR: sbatch did not return a job ID — submission may have failed" >&2
  exit 1
fi

job_R_summary_result_id="${job_R_summary_result%%;*}"

echo "Submitted jobs:"
echo "  - R_summary_result: $job_R_summary_result"

echo "Monitor:"
echo "  sacct -j $job_R_summary_result_id"
echo "  squeue -u ${USER:-$(whoami)}"