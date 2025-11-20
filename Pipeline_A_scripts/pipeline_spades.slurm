#!/bin/bash

#SBATCH -J rnaviralspades
#SBATCH -o /workspace/hraczj/Phytophthora_VirusDiscovery_2022/005.rnaviralspades/logs/spades.out
#SBATCH -e /workspace/hraczj/Phytophthora_VirusDiscovery_2022/005.rnaviralspades/logs/spades.err
#SBATCH --array=0-2
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --time=00:30:00
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL

# Sample prefixes for each job index
#SAMPLES=(RNAR1 RNAR2 RNAR3)
#LABEL="${SAMPLES[$SLURM_ARRAY_TASK_ID]}"

# Input files
#R1="${SPADES_IN}/${LABEL}.non-Phytophthora_1.fq.gz"
#R2="${SPADES_IN}/${LABEL}.non-Phytophthora_2.fq.gz"

# Load the SPAdes module:
#module load SPAdes/4.0.0

#writing a loop for running multiples RNAR1.non-Phytophthora_2.fq.gz, RNAR2.non-Phytophthora_2.fq.gz, RNAR3.non-Phytophthora_2.fq.gz so on

#rnaviralspades.py --pe1-1 $R1 --pe1-2 $R2 -o $SPADES_OUT
		

#module unload SPAdes/4.0.0

set -o pipefail

main() {
    if [[ -z "$SPADES_IN" ]] || [[ -z "$SPADES_OUT" ]]; then
        printf "Missing required environment variables SPADES_IN or SPADES_OUT\n" >&2
        return 1
    fi

    local samples
    samples=(RNAR1 RNAR2 RNAR3)

    local label
    label="${samples[$SLURM_ARRAY_TASK_ID]}"

    local r1; r1="${SPADES_IN}/${label}.non-Phytophthora_1.fq.gz"
    local r2; r2="${SPADES_IN}/${label}.non-Phytophthora_2.fq.gz"
    local outdir; outdir="${SPADES_OUT}/${label}"

    if [[ ! -s "$r1" ]] || [[ ! -s "$r2" ]]; then
        printf "Missing input files: %s or %s\n" "$r1" "$r2" >&2
        return 1
    fi

    if ! module load SPAdes/4.0.0; then
        printf "Failed to load SPAdes module\n" >&2
        return 1
    fi

    if ! rnaviralspades.py --pe1-1 "$r1" --pe1-2 "$r2" -o "$outdir"; then
        printf "SPAdes failed for sample %s\n" "$label" >&2
        module unload SPAdes/4.0.0
        return 1
    fi

    module unload SPAdes/4.0.0
}

main "$@"