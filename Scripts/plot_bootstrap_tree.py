#!/usr/bin/env python3
import argparse
import os
import re
import sys
from Bio import Phylo
import matplotlib.pyplot as plt

def parse_args():
    p = argparse.ArgumentParser(description="Plot tree and color Viral_read_* tips red.")
    p.add_argument("tree_file")
    p.add_argument("--format", default="newick")
    p.add_argument("--threshold", type=float, default=70.0)
    p.add_argument("--out", default=None)
    p.add_argument("--width", type=float, default=30)
    p.add_argument("--height", type=float, default=45)
    p.add_argument("--dpi", type=int, default=300)
    p.add_argument("--label-size", type=float, default=6.0)
    p.add_argument("--bootstrap-size", type=float, default=6.0)
    p.add_argument("--marker-size", type=float, default=2.5)
    p.add_argument("--no-show", action="store_true")
    return p.parse_args()

def compute_clade_heights(tree):
    heights = {}
    def calc_row(clade, row):
        if clade.is_terminal():
            heights[clade] = row
            return row + 1
        rows = []
        for c in clade.clades:
            row = calc_row(c, row)
            rows.append(heights[c])
        heights[clade] = (rows[0] + rows[-1]) / 2.0
        return row
    calc_row(tree.root, 0)
    return heights

# case-insensitive Viral_read_* matcher
VIRAL_RE = re.compile(r"\bviral_read_[A-Za-z0-9_.:-]+\b", re.IGNORECASE)

def short_label(name: str) -> str:
    if not name:
        return ""
    s = str(name).strip()
    m = VIRAL_RE.search(s)
    if m:
        return m.group(0)  # keep Viral_read_1 style
    return s if len(s) <= 90 else s[:87] + "..."

def is_viral_label(txt: str) -> bool:
    return VIRAL_RE.search((txt or "").strip()) is not None

def main():
    a = parse_args()

    if not os.path.exists(a.tree_file):
        print(f"ERROR: file not found: {a.tree_file}", file=sys.stderr)
        sys.exit(1)

    tree = Phylo.read(a.tree_file, a.format)
    out_png = a.out or f"{os.path.basename(a.tree_file)}.bootstrap_gt{int(a.threshold)}.png"

    fig = plt.figure(figsize=(a.width, a.height), dpi=a.dpi)
    ax = fig.add_subplot(1, 1, 1)

    Phylo.draw(tree, axes=ax, do_show=False, label_func=lambda c: short_label(c.name))

    viral_count = 0
    for t in ax.texts:
        t.set_fontsize(a.label_size)
        if is_viral_label(t.get_text()):
            t.set_color("red")
            t.set_fontweight("bold")
            viral_count += 1
        else:
            t.set_color("black")

    depths = tree.depths()
    if not max(depths.values()):
        depths = tree.depths(unit_branch_lengths=True)
    heights = compute_clade_heights(tree)

    boot_count = 0
    for clade in tree.find_clades():
        conf = clade.confidence
        if conf is not None and conf > a.threshold:
            x = depths.get(clade, 0.0)
            y = heights.get(clade, 0.0)
            ax.plot(x, y, "ro", markersize=a.marker_size)
            ax.text(x, y, f" {int(round(conf))}", color="red", fontsize=a.bootstrap_size, va="center")
            boot_count += 1

    ax.set_title(f"Tree (support > {a.threshold}); Viral_read_* tips in red")
    plt.tight_layout()
    plt.savefig(out_png, bbox_inches="tight")
    print(f"Saved: {out_png}")
    print(f"Viral_read_* labels colored red: {viral_count}")
    print(f"Bootstrap nodes highlighted: {boot_count}")

    if not a.no_show:
        plt.show()

if __name__ == "__main__":
    main()