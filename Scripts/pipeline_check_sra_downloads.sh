#!/usr/bin/env bash
set -euo pipefail

show_help() {
  echo "Usage: $0 -f file_of_accessions -d directory [-h]"
  echo ""
  echo "  -f  Full path to text file containing SRA run ids (SRR...), one per line"
  echo "  -d  Directory containing downloaded FASTQ(.gz) files"
  echo "  -h  Show help"
  echo ""
  echo "Example:"
  echo "  $0 -f /path/accessions.txt -d /path/raw_reads"
  exit 1
}

directory=""
file_of_accessions=""

while getopts "d:f:h" OPTKEY; do
  case "$OPTKEY" in
    d) directory="$OPTARG" ;;
    f) file_of_accessions="$OPTARG" ;;
    h) show_help ;;
    *) show_help ;;
  esac
done
shift $((OPTIND - 1))

if [[ -z "$directory" ]]; then
  echo "ERROR: -d directory is required" >&2
  show_help
fi
if [[ -z "$file_of_accessions" ]]; then
  echo "ERROR: -f file_of_accessions is required" >&2
  show_help
fi
if [[ ! -d "$directory" ]]; then
  echo "ERROR: directory not found: $directory" >&2
  exit 1
fi
if [[ ! -f "$file_of_accessions" ]]; then
  echo "ERROR: accessions file not found: $file_of_accessions" >&2
  exit 1
fi

missing_file="${directory}/missing_sra_ids.txt"
: > "$missing_file"

# Read expected accessions (ignore blank lines and comments; strip CRLF; trim spaces)
mapfile -t expected < <(grep -vE '^\s*($|#)' "$file_of_accessions" | sed 's/\r$//' | awk '{$1=$1;print}')

if (( ${#expected[@]} == 0 )); then
  echo "ERROR: No accessions found in $file_of_accessions" >&2
  exit 1
fi

echo "Checking ${#expected[@]} accessions in: $directory"
echo "Writing missing list to: $missing_file"
echo ""

for acc in "${expected[@]}"; do
  # Files that might exist for this accession
  single="${directory}/${acc}.fastq.gz"
  r1="${directory}/${acc}_1.fastq.gz"
  r2="${directory}/${acc}_2.fastq.gz"

  # Determine status
  if [[ -s "$r1" && -s "$r2" ]]; then
    # paired OK
    continue
  elif [[ -s "$single" && ! -e "$r1" && ! -e "$r2" ]]; then
    # single OK
    continue
  elif [[ -s "$single" && -s "$r1" && -s "$r2" ]]; then
    # "triple" case: keep paired, single is unnecessary
    rm -f "$single"
    continue
  else
    # Missing or partial
    echo "$acc" >> "$missing_file"

    # cleanup partial paired if one mate missing/empty
    if [[ -e "$r1" && ! -s "$r2" ]]; then rm -f "$r1"; fi
    if [[ -e "$r2" && ! -s "$r1" ]]; then rm -f "$r2"; fi

    # cleanup empty single
    if [[ -e "$single" && ! -s "$single" ]]; then rm -f "$single"; fi
  fi
done

# Deduplicate missing list
awk '!a[$0]++' "$missing_file" > "${missing_file}.tmp" && mv "${missing_file}.tmp" "$missing_file"

missing_count=$(grep -c . "$missing_file" || true)

if (( missing_count == 0 )); then
  echo "All accessions were downloaded successfully."
  rm -f "$missing_file"
  exit 0
else
  echo "Some accessions are missing or partially downloaded."
  echo "Count: $missing_count"
  echo ""
  cat "$missing_file"
  echo ""
  echo "Re-download using:"
  echo "  -f $missing_file"
  exit 2
fi