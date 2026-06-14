#!/usr/bin/env bash
#SBATCH -J searchx
#SBATCH --cpus-per-task=2
#SBATCH --mem=10G
#SBATCH --mail-user=cinthy.jimenez-silva@plantandfood.co.nz
#SBATCH --mail-type=ALL
#SBATCH --time=06:00:00

set -euo pipefail
set -x

: "${CONFIG:?CONFIG not set}"
source "$CONFIG"

: "${IN:?IN not set}"
: "${OUT:?OUT not set}"
: "${BLAST_LOG_DIR:?BLAST_LOG_DIR not set}"
: "${DB:?DB not set}"
: "${TAG:?TAG not set (nr/rdrp)}"
: "${SEARCH_TOOL:?SEARCH_TOOL not set (blastx/diamond)}"

THREADS="${SLURM_CPUS_PER_TASK:-2}"
TASK_ID="${SLURM_ARRAY_TASK_ID:-0}"
DIAMOND_BIN="${DIAMOND_BIN:-diamond}"

mkdir -p "$OUT" "$BLAST_LOG_DIR"

if [[ ! -d "$IN" ]]; then
  echo "ERROR: Input directory not found: $IN" >&2
  exit 1
fi

mapfile -t CONTIG_FILES < <(find "$IN" -mindepth 2 -maxdepth 2 -type f -name 'contigs.fasta' | sort)

if (( ${#CONTIG_FILES[@]} == 0 )); then
  echo "ERROR: No contigs.fasta found under $IN/*/contigs.fasta" >&2
  exit 1
fi

fasta="${CONTIG_FILES[$TASK_ID]:-}"
if [[ -z "$fasta" ]]; then
  echo "ERROR: No contigs.fasta for task $TASK_ID (n=${#CONTIG_FILES[@]})" >&2
  exit 1
fi

sample="$(basename "$(dirname "$fasta")")"
sample_outdir="${OUT}/${sample}"
mkdir -p "$sample_outdir"

outfile="${sample_outdir}/${sample}_${TAG}_${SEARCH_TOOL}.tsv"
sample_log="${BLAST_LOG_DIR}/${sample}.${TAG}.${SEARCH_TOOL}.log"

echo "Running search"
echo "  task_id=$TASK_ID"
echo "  sample=$sample"
echo "  fasta=$fasta"
echo "  db=$DB"
echo "  tag=$TAG"
echo "  tool=$SEARCH_TOOL"
echo "  threads=$THREADS"
echo "  outfile=$outfile"
echo "  sample_log=$sample_log"

if [[ "$SEARCH_TOOL" == "blastx" ]]; then
  if ! command -v blastx >/dev/null 2>&1; then
    module load ncbi-blast/2.11.0
  fi

  if ! command -v blastx >/dev/null 2>&1; then
    echo "ERROR: blastx not found in PATH after attempting module load." >&2
    exit 1
  fi

  blastx \
    -db "$DB" \
    -query "$fasta" \
    -out "$outfile" \
    -outfmt "6 qseqid sacc pident staxid ssciname length mismatch gapopen qstart qend sstart send evalue bitscore qlen" \
    -max_target_seqs 5 \
    -num_threads "$THREADS" \
    > "$sample_log" 2>&1

elif [[ "$SEARCH_TOOL" == "diamond" ]]; then
  if ! command -v "$DIAMOND_BIN" >/dev/null 2>&1; then
    echo "ERROR: DIAMOND executable not found: $DIAMOND_BIN" >&2
    echo "Set DIAMOND_BIN in the environment or ensure diamond is in PATH." >&2
    exit 1
  fi

  "$DIAMOND_BIN" blastx \
    --db "$DB" \
    --query "$fasta" \
    --threads "$THREADS" \
    --evalue 1e-4 \
    --max-target-seqs 5 \
    --out "$outfile" \
    --outfmt 6 qseqid qlen sseqid stitle pident length evalue bitscore \
    > "$sample_log" 2>&1

else
  echo "ERROR: SEARCH_TOOL must be blastx or diamond; got: $SEARCH_TOOL" >&2
  exit 1
fi

if [[ "$TAG" == "rdrp" ]]; then
  hits_list="${sample_outdir}/${sample}_rdrp_hit_contigs.txt"
  hits_fasta="${sample_outdir}/${sample}_rdrp_blastcontigs.fasta"

  awk -F'\t' '{print $1}' "$outfile" | sort -u > "$hits_list"

  awk '
    BEGIN {
      while ((getline < ARGV[2]) > 0) keep[$0]=1
      ARGV[2]=""
    }
    /^>/ {
      h=$0
      sub(/^>/,"",h)
      split(h,a,/ /)
      id=a[1]
      print_it=(id in keep)
    }
    {
      if (print_it) print
    }
  ' "$fasta" "$hits_list" > "$hits_fasta" || true
fi

echo "Done sample=$sample tag=$TAG tool=$SEARCH_TOOL out=$outfile"