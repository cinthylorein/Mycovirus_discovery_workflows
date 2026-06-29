#!/usr/bin/env python3

import re
import sys
from io import StringIO
from pathlib import Path
from collections import Counter
from Bio import Phylo


ACCESSION_RE = re.compile(r'^[A-Z]{1,2}\d{5,6}(?:\.\d+)?$')


def clean_label(label):
    """Remove leading/trailing underscores and collapse empty fields."""
    if not label:
        return ""
    return label.strip("_")


def extract_genus(label):
    """
    Extract genus from underscore-separated tree labels.

    Rule:
    - split label on underscores
    - find first accession-like token
    - genus = next meaningful token after that accession,
      skipping placeholders like NOT/ON/SPREADSHEET if present

    Examples:
      _MK584845_Acremonium_sclerotigenum_ourmia-like_virus_1_
        -> Acremonium

      _AF039063_NOT_ON_SPREADSHEET_Saccharomyces_20S_RNA_narnavirus_.1_
        -> Saccharomyces

      Viral_read_1
        -> NA
    """
    label = clean_label(label)
    if not label or label == "Viral_read_1":
        return "NA"

    parts = [p for p in label.split("_") if p]
    if not parts:
        return "NA"

    acc_index = None
    for i, part in enumerate(parts):
        if ACCESSION_RE.match(part):
            acc_index = i
            break

    if acc_index is None:
        return "NA"

    i = acc_index + 1

    # Skip spreadsheet placeholder words if present
    skip_words = {"NOT", "ON", "SPREADSHEET"}
    while i < len(parts) and parts[i] in skip_words:
        i += 1

    if i < len(parts):
        return parts[i]

    return "NA"


def find_target_terminal(tree, target_name="Viral_read_1"):
    for term in tree.get_terminals():
        if term.name and term.name.strip() == target_name:
            return term
    return None


def smallest_informative_clade(tree, target_terminal):
    """
    Return the smallest clade containing target_terminal and at least one
    other terminal.
    """
    path = tree.get_path(target_terminal)

    for clade in reversed(path):
        if len(clade.get_terminals()) > 1:
            return clade

    return tree.root


def clade_genus(clade, target_name="Viral_read_1"):
    genera = []
    for term in clade.get_terminals():
        if not term.name:
            continue
        label = term.name.strip()
        if label == target_name:
            continue
        genus = extract_genus(label)
        if genus != "NA":
            genera.append(genus)

    if not genera:
        return "NA"

    counts = Counter(genera)
    return counts.most_common(1)[0][0]


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <tree_file>")
        sys.exit(1)

    tree_file = Path(sys.argv[1])

    if not tree_file.is_file():
        print(f"ERROR: file not found: {tree_file}")
        sys.exit(1)

    output_table = tree_file.with_name(f"{tree_file.stem}_genus_table.txt")

    try:
        tree = Phylo.read(str(tree_file), "newick")
    except Exception as e:
        print(f"ERROR: could not parse tree: {tree_file}")
        print(e)
        sys.exit(1)

    # Write header/genus table
    rows = []
    for term in tree.get_terminals():
        header = term.name.strip() if term.name else ""
        genus = extract_genus(header)
        rows.append((header, genus))

    with open(output_table, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("Header\tGenus\n")
        for header, genus in rows:
            fh.write(f"{header}\t{genus}\n")

    print(f"Table written to {output_table}")

    # Find Viral_read_1
    target = find_target_terminal(tree, "Viral_read_1")
    if target is None:
        print("Viral_read_1 was not found in the tree.")
        sys.exit(0)

    # Extract smallest informative clade
    target_clade = smallest_informative_clade(tree, target)

    print("\nClade containing Viral_read_1:")
    handle = StringIO()
    Phylo.write([target_clade], handle, "newick")
    print(handle.getvalue().strip())

    inferred = clade_genus(target_clade, "Viral_read_1")
    print(f"\nInferred genus category for the Viral_read_1 clade: {inferred}")


if __name__ == "__main__":
    main()
