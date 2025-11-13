#!/bin/bash

set -euo pipefail

# 1. Setup directory

echo "🚀 Starting virus discovery pipeline on SLURM..."

# Optional: Load paths if defined in setup.sh
if [[ -f ./setup.sh ]]; then
    source ./setup.sh
    echo "✅ Loaded paths from setup.sh"
else
    echo "⚠️  setup.sh not found — assuming variables are hardcoded inside SLURM scripts"
fi

# 2. FASTQC
./pipeline_fastqc.sh

./ pipeline_trim.sh

# 4. Bowtie2 index (no dependency needed, after trimming + index)
./ pipeline_bowtie2.sh

# 5.SPAdes (after Bowtie2 alignment)
./pipeline_spades.sh

# 6. blastn + blastx
./pipeline_blastn.sh
./pipeline_blastx.sh 



echo "Submitted jobs:"
echo "FastQC:         $job_fastqc"
echo "Trimmomatic:    $job_trim"
echo "Bowtie2 Index:  $job_bowtie_index"
echo "Bowtie2 Align:  $job_bowtie_align"
echo "SPAdes:         $job_spades"
