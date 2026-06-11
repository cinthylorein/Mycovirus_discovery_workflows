#!/usr/bin/env bash
#SBATCH -J BowtieBuildIndexHost
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=00:30:00

set -euo pipefail
set -x

module load bowtie2/2.3.4.3

: "${CONFIG:?CONFIG not set}"
source "$CONFIG"

: "${REF:?REF not set}"
: "${INDEX_DIR:?INDEX_DIR not set}"

mkdir -p "$INDEX_DIR"

INDEX_BASE="${INDEX_DIR}/host"

echo "Building Bowtie2 index from reference: $REF"
echo "Index basename: $INDEX_BASE"

bowtie2-build "$REF" "$INDEX_BASE"

echo "Index build done."

module unload bowtie2/2.3.4.3
