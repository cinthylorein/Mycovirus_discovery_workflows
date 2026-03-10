#!/usr/bin/env bash
set -euo pipefail

ids="${1:?Usage: $0 ids.txt contigs.fasta output.fasta}"
contigs="${2:?Usage: $0 ids.txt contigs.fasta output.fasta}"
out="${3:?Usage: $0 ids.txt contigs.fasta output.fasta}"

module load seqkit || true

seqkit grep -f "$ids" "$contigs" > "$out"