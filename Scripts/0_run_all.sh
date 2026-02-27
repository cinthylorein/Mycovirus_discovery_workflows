#!/bin/bash
#set -euo pipefail

echo "🚀 Starting virus discovery pipeline..."

# Optional: Load path configs
if [[ -f ./setup.sh ]]; then
    source ./setup.sh
    echo "✅ Loaded paths from setup.sh"
fi

# 🔁 Function to wait for SLURM job to finish
wait_for_job() {
    local job_id=$1
    local stage=$2

    echo "⏳ Waiting for $stage job to finish: $job_id"
    while squeue -j "$job_id" &>/dev/null && squeue -j "$job_id" | grep -q "$job_id"; do
        sleep 10
    done
    echo "✅ $stage completed."
}

############################
# STEP 1: FASTQC
############################
job_fastqc=$(./pipeline_fastqc.sh | awk '/Submitted batch job/ {print $NF}')
wait_for_job "$job_fastqc" "FASTQC"

############################
# STEP 2: TRIMMOMATIC
############################
job_trim=$(./pipeline_trim.sh | awk '/Submitted batch job/ {print $NF}')
wait_for_job "$job_trim" "Trimmomatic"

############################
# STEP 3: BOWTIE2 INDEX
############################
job_index=$(./pipeline_bowtie2.sh | awk '/Submitted batch job/ {print $NF}')
wait_for_job "$job_index" "Bowtie2 Index + Align"

############################
# STEP 4: SPADES
############################
job_spades=$(./pipeline_spades.sh | awk '/Submitted batch job/ {print $NF}')
wait_for_job "$job_spades" "SPAdes Assembly"

############################
# STEP 5: BLASTn
############################
job_blastn=$(./pipeline_blastn.sh | awk '/Submitted batch job/ {print $NF}')
wait_for_job "$job_blastn" "BLASTn"

############################
# STEP 6: BLASTx
############################
job_blastx=$(./pipeline_blastx.sh | awk '/Submitted batch job/ {print $NF}')
wait_for_job "$job_blastx" "BLASTx"

############################
# STEP 7: Summary
############################
job_sum=$(./pipeline_summary_result.sh | awk '/Submitted batch job/ {print $NF}')
wait_for_job "$job_sum" "Summary"


echo ""
echo " Pipeline complete! All jobs finished successfully."