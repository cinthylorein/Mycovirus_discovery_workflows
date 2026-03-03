#!/bin/bash

#SBATCH -J rnaviralspades                   # Job name
#SBATCH -o /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/spades_%A_%a.out  # Output log
#SBATCH -e /workspace/hraczj/Virus_discovery_workflows/MVoPvirome/MVoP_pipeline/logs/spades_%A_%a.err  # Error log
#SBATCH --array=0-10                        # Job array size for 11 samples (index 0–10)
#SBATCH --cpus-per-task=8                   # Set 8 CPUs per task
#SBATCH --mem=64G                           # Allocate 64GB of memory per task
#SBATCH --time=24:00:00                     # Extend the job time to 24 hours
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL                     # Notify the user about start, end, and failure

set -o pipefail  # Ensure the script stops on pipeline failures

# Main function
main() {
    # Check if environment variables SPADES_IN and SPADES_OUT are defined
    if [[ -z "$SPADES_IN" ]] || [[ -z "$SPADES_OUT" ]]; then
        printf "Missing required environment variables SPADES_IN or SPADES_OUT\n" >&2
        return 1
    fi

    # Define the sample array
    local samples
    samples=(SRR11783490 SRR11783518 SRR11783495)

    # Get sample based on the SLURM task ID
    local label="${samples[$SLURM_ARRAY_TASK_ID]}"
    local r1="${SPADES_IN}/${label}.non-host.1.fq.gz"
    local r2="${SPADES_IN}/${label}.non-host.2.fq.gz"
    local outdir="${SPADES_OUT}/${label}"

    # Check input files existence
    if [[ ! -s "$r1" ]] || [[ ! -s "$r2" ]]; then
        printf "Missing input files: %s or %s\n" "$r1" "$r2" >&2
        return 1
    fi

    # Load SPAdes module
    if ! module load SPAdes/4.0.0; then
        printf "Failed to load SPAdes module\n" >&2
        return 1
    fi

    # Run SPAdes with adjusted threads and memory allocation
    if ! rnaviralspades.py --pe1-1 "$r1" --pe1-2 "$r2" -o "$outdir" --threads 8 --memory 64; then
        printf "SPAdes failed for sample %s\n" "$label" >&2
        module unload SPAdes/4.0.0
        return 1
    fi

    # Unload SPAdes module after completion
    module unload SPAdes/4.0.0
}

# Execute the main function
main "$@"
