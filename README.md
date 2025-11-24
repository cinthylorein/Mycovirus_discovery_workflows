# Virus discovery workflow

This repository provides virus-discovery workflows configured for the powerPlant and Nesi HPC systems (Slurm). They accept your sequencing data and can be used to mine SRA datasets for mycoviruses. 

The workflow creates a standardized project folder structure and a set of scripts to speed up analysis. 



--------------------
### Table of Contents
- [Virus discovery workflow](#Virus-discovery-workflow)
    - [Table of Contents](#table-of-contents)
      - [Installation](#installation)
      - [Workflow](#Workflow)
      - [Acknowledgments](#acknowledgments)
      - [How to cite this repo?](#how-to-cite-this-repo)

--------------------

## Installation

1. Clone the repository: git clone https://github.com/cinthylorein/Virus_discovery_workflows.git

2. Change into the scripts directory: cd Virus_discovery_workflows/scripts

(If you downloaded and unpacked a ZIP from GitHub you may get a directory named Virus_discovery_workflows-main; adapt the path accordingly, e.g. cd Virus_discovery_workflows-main/scripts.)

3.convert CRLF to Unix LF and then set the executable bit. From the repository root:

```bash
# Convert line endings for all top-level .sh files
sed -i 's/\r$//' *.sh

# On macOS (BSD sed) use:
# sed -i '' -e 's/\r$//' *.sh

# Alternative if you have dos2unix:
# dos2unix *.sh

# Then make scripts executable
chmod +x *.sh
```

4. Edit the setup.sh file: update the root, project and email variables to match your environment.

5. Run the setup script: ./setup.sh

Notes about the scripts

Each general task has two files: a .sh shell wrapper and a .slurm job script. The .sh file passes parameters and environment variables to the .slurm script. In normal use you usually only edit the .sh wrapper; the .slurm file typically does not need changes.
The scripts are designed to run on batches: they expect an input file listing sample filenames (one per line) to process multiple samples in a single run.

--------------------

## Workflow

This repository contains two virus‑discovery pipelines illustrated in the figure bellow. Use (A) when you know the host genome and want to remove host reads before virus discovery; use (B) when you do not remove host reads (environmental or unknown‑host samples) or when starting from SRA accessions.

![Pipeline overview](images/Pipeline_schematic_VirusDiscoveryWorkflow.png)

### Overview

- Pipeline A — host-aware (recommended when you have the host reference)
  - Purpose: remove host-derived reads first to reduce background, then assemble and search for viral contigs.
  - Typical use case: metatranscriptomes sequenced from a known host (e.g., *Botrytis cinerea*).
- Pipeline B — host-agnostic (recommended for environmental samples or when you want to retain host reads)
  - Purpose: assemble and search without prior host filtering (useful when host genome is unknown or you expect viruses integrated/associated with other organisms).

---

### Pipeline A (host-aware) — step-by-step

1. Set up directories and environment
   - Run the project setup script that creates the standard folder layout:
2. Quality control (FastQC)
   - Input: raw FASTQ files in `scratch/.../raw_reads`.
   - Quick QC to check library quality before trimming.

3. Trim reads and assemble transcripts
   - Trimming: Trimmomatic (or equivalent) to remove adapters and low-quality bases.
   - Assembly: trinity/megahit/rna assembler to build contigs from trimmed reads.

4. Build host index and remove host reads
   - Build a Bowtie2 index of the host transcriptome/genome.
   - Align reads to host and remove aligned reads (keeps likely non‑host reads for viral discovery).

5. Assemble viral contigs
   - Assemble the host‑filtered reads (SPAdes).
   - Result: candidate contigs enriched for non‑host sequences.

6. BLAST/annotation/search steps
   - Run BLASTx and against NR/NT as needed.
   - Typical scripts:
     - `_blastx.sh`, `_blastnt.sh`

---

### Pipeline B (host-agnostic) — step-by-step

1. Create an accession file: Make a plain-text file listing one library identifier per line. Each line may be an SRA run ID or a non-SRA library (see the “Non-SRA libraries” section). This accession file is the main input for the scripts.

2. Download SRA data: Use the download script (pipeline_download_sra.sh). Note: the scripts will be renamed to include your project name during setup. Skip this step if you already have the sequencing data.

3. Verify raw read downloads: Confirm the raw reads are present in /scratch/<root_project>/<project>/raw_reads. Use the provided check_sra_downloads.sh script to check for missing files and re-download any missing accessions (create a new accession file for re-downloads).

4. Trim reads, assemble, and calculate contig abundance: Run the trimming, assembly and abundance script (for example, pipeline_trim_assembly_abundance.sh). Current trim settings target TruSeq3 paired-end (PE) and single-end (SE) Illumina libraries. After assembly, check that contigs in /project/<root_project>/<project>/contigs/final_contigs/ are non-empty. It is recommended to run FastQC on a subset of samples (scripts included) to inspect trimming quality and to verify that an excessive number of reads are not being removed.

5. Run BLASTx searches against RdRp and RVDB: Execute the BLASTx jobs for RdRp and for RVDB; these can be run in parallel. Also run FastQC to check overall quality and adapter presence.

6. Run BLAST (nr and nt): Run the pipeline_blastnr.sh and pipeline_blastnt.sh scripts. Given an accession file, the pipeline combines contigs identified from RdRp and RVDB and uses them as input for the nr and nt searches. Because of this, each of these is launched as a single job (not an array) and outputs are named after the -f file.

7. Run read counting: Use pipeline_readcount.sh to count reads mapped to contigs.

8. Generate summary tables: Run the summary table script to produce output files in /project/<root_project>/<project>/blast_results/summary_table_creation. The CSV files in that folder are the summary tables. You can limit the summary to a subset of runs by supplying an accession file with -f. Always check the log files in the logs folder (summary_table_creation_TODAY_stderr.txt and summary_table_creation_TODAY_stdout.txt) to ensure all inputs were present and to identify any errors.

### Example: Summary table 

| contig_id | sample_id | contig_length | abundance_TPM | read_count | best_db | best_hit_accession | best_hit_description | percent_identity | align_length | evalue | bitscore | taxid | lineage | classification | notes |
|---|---:|---:|---:|---:|---|---|---|---:|---:|---:|---:|---:|---|---|---|
| contig_0001_sampleA | sampleA | 3258 | 1523.4 | 4821 | nr | YP_009724389.1 | RNA-dependent RNA polymerase [Hypothetical virus X] | 98.5 | 310 | 1e-120 | 460 | 12345 | Riboviria; Picornavirales; Caliciviridae; Norovirus | likely | RdRp hit high identity; RdRp-scan positive |
| contig_0002_sampleB | sampleB | 1412 | 210.1 | 873 | RVDB | RVDB_ABC12345 | Capsid protein [Uncharacterized virus Y] | 92.3 | 250 | 2e-60 | 320 | 67890 | Riboviria; Narnavirales; Narnaviridae; Mitovirus | likely | RVDB hit; taxid from RVDB mapping |
| contig_0005_sampleC | sampleC | 2187 | 320.9 | 1104 | RdRpScan | RdRp_000987654 | Conserved RdRp domain [novel virus fragment] | 89.9 | 400 | 3e-80 | 410 | 33445 | Riboviria; Unclassified_RdRp | likely | Detected by RdRp-scan; no close nr hit |


Note:
The pipeline depends on server-installed reference databases (NR, NT, RVDB, RdRp-Scan), software modules, and taxonomy files (NCBI taxdb, taxize, RVDB tax). These resources are not downloaded automatically and must be present on the server.

--------------------

## Acknowledgments
I'd like to acknowledge of the Holmes Lab for their contributions to the development of the USYD Artemis workflow which inspires this one.

--------------------

## How to cite this repo?
If this repo was somehow useful a citation would be greatly appeciated! Available at: https://github.com/cinthylorein/Virus_discovery_workflows.
