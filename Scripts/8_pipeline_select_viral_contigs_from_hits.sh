#!/usr/bin/env bash
set -euo pipefail

in_tsv="${1:?Usage: $0 nt_filtered_hits.tsv > selected_contigs.txt}"
min_ident="${MIN_IDENT:-75}"
min_len="${MIN_LEN:-1000}"
require_complete="${REQUIRE_COMPLETE:-0}"  # set to 1 if you want "complete cds/genome" required

# Columns (based on your header):
# 1 qseqid
# 3 pident
# 15 qlen
# last column is GenBank_Title (can contain spaces? in TSV it is still one field)
awk -F'\t' -v MINID="$min_ident" -v MINLEN="$min_len" -v REQCOMP="$require_complete" '
BEGIN { OFS="\t" }
NR==1 { next }  # skip header
{
  qseqid=$1
  pident=$3+0
  qlen=$15+0
  title=$NF

  if (pident < MINID) next
  if (qlen < MINLEN) next

  if (REQCOMP==1) {
    t=tolower(title)
    if (t !~ /complete cds/ && t !~ /complete genome/) next
  }

  print qseqid
}
' "$in_tsv" | sort -u