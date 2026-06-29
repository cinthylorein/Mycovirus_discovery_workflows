#!/usr/bin/env python3

import sys
from pathlib import Path


def read_fasta(path):
    return Path(path).read_text(encoding="utf-8").strip()


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <viral_read.fasta> <reference.fasta>")
        sys.exit(1)

    viral_file = Path(sys.argv[1])
    reference_file = Path(sys.argv[2])

    if not viral_file.is_file():
        print(f"ERROR: file not found: {viral_file}")
        sys.exit(1)

    if not reference_file.is_file():
        print(f"ERROR: file not found: {reference_file}")
        sys.exit(1)

    viral_text = read_fasta(viral_file)
    reference_text = read_fasta(reference_file)

    output_file = reference_file.with_name(
        f"{reference_file.stem}_ViralReadasignment.fasta"
    )

    combined_text = viral_text + "\n" + reference_text + "\n"

    with open(output_file, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(combined_text)

    print(f"Combined FASTA written to {output_file}")


if __name__ == "__main__":
    main()