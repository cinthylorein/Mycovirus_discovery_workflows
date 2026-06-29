#!/usr/bin/env python3
import sys
import csv

if len(sys.argv) < 3:
    print("Usage: python3 assign_family_nopandas.py <input_nt_filtered_hits.tsv> <output_assigned_family.tsv>")
    sys.exit(1)

in_tsv = sys.argv[1]
out_tsv = sys.argv[2]

best = {}  # qseqid -> (bitscore, family)

def norm_family(x):
    x = (x or "").strip()
    if x.lower() in {"", "na", "n/a", "none", "null"}:
        return "NA"
    return x

with open(in_tsv, "r", newline="", encoding="utf-8") as f:
    r = csv.DictReader(f, delimiter="\t")
    required = {"qseqid", "bitscore", "Family"}
    missing = required - set(r.fieldnames or [])
    if missing:
        print(f"ERROR: Missing required columns: {', '.join(sorted(missing))}")
        sys.exit(1)

    for row in r:
        q = row["qseqid"].strip()
        if not q:
            continue
        try:
            bs = float(row["bitscore"])
        except Exception:
            bs = -1.0
        fam = norm_family(row.get("Family", ""))

        if q not in best:
            best[q] = (bs, fam)
        else:
            prev_bs, prev_fam = best[q]
            # higher bitscore wins; on tie prefer non-NA family
            if bs > prev_bs or (bs == prev_bs and prev_fam == "NA" and fam != "NA"):
                best[q] = (bs, fam)

with open(out_tsv, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f, delimiter="\t")
    w.writerow(["qseqid", "assigned_family"])
    for q in sorted(best.keys()):
        fam = best[q][1]
        if fam == "NA":
            fam = "Unclassified"
        w.writerow([q, fam])

print(f"Saved: {out_tsv}")