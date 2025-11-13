# 🧬 Mycovirus Discovery Pipeline (HPC + SLURM)

This workflow processes RNA-seq data to identify mycoviruses in *Phytophthora* samples using FastQC, Trimmomatic, Bowtie2, and SPAdes.

---

## 📂 Directory Structure

```bash
/workspace/hraczj/Phytophthora_VirusDiscovery_2022/
│
├── 000.raw/                    # Raw FASTQ data
├── 001.fastqc_raw/             # FastQC reports
├── 002.trimmomatic/            # Trimmed reads
├── 004.MapPhytophthora/        # Host-filtered reads
├── 005.spades/                 # De novo assembly output
├── 010.PhytophthoraHostIndex/  # Bowtie2 index
└── setup.sh                    # Directory creation + config
