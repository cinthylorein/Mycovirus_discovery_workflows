# Virus discovery workflow

This repository provides virus-discovery workflows configured for the powerPlant and Nesi HPC systems (Slurm). They accept your sequencing data and can be used to mine SRA datasets for mycoviruses. 

The workflow creates a standardized project folder structure and a set of scripts to speed up analysis. 



--------------------
### Table of Contents
- [Virus discovery workflow](#Virus-discovery-workflow)
    - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Pipeline](#pipeline)
  - [Acknowledgments](#acknowledgments)
  - [How to cite this repo?](#how-to-cite-this-repo)

--------------------

## Installation

1. Clone the repository: git clone https://github.com/cinthylorein/Virus_discovery_workflows.git

2. Change into the scripts directory: cd Virus_discovery_workflows/scripts

(If you downloaded and unpacked a ZIP from GitHub you may get a directory named Virus_discovery_workflows-main; adapt the path accordingly, e.g. cd Virus_discovery_workflows-main/scripts.)

3. Make all scripts executable and open setup.sh for editing: chmod +x ./* nano setup.sh

4. Edit the setup.sh file: update the root, project and email variables to match your environment.

5. Run the setup script: ./setup.sh

Notes about the scripts

Each general task has two files: a .sh shell wrapper and a .slurm job script. The .sh file passes parameters and environment variables to the .slurm script. In normal use you usually only edit the .sh wrapper; the .slurm file typically does not need changes.
The scripts are designed to run on batches: they expect an input file listing sample filenames (one per line) to process multiple samples in a single run.

--------------------

## Pipeline
The standard pipeline follows these steps:

![Pipeline](images/Pipeline_schematic_VirusDiscoveryWorkflow.png)

1. Create an accession file, plain text with the names of your libaries, one per line. These can either be SRA run ids or Non-SRA libaries (!see section Non-SRA libaries). This will be used as the main input for the scripts.
2. Download SRA e.g, `_pipeline_download_sra.sh` Note all the scripts will be renamed to reflect your project name. This can be skipped if you have generated the sequencing data yourself 
3. Check the that the raw reads have downloaded by looking in `/scratch/^your_root_project^/^your_project^/raw_reads` . You can use the `check_sra_downloads.sh` script to do this! Re-download any that are missing (make a new file with the accessions) 
4. Run read trimming, assembly and calculate contig abundance e.g, `pipeline_trim_assembly_abundance.sh`. Trimming is currently setup for TruSeq3 PE and SE illumania libs and will also trim nextera (PE only). Check that all contigs are non-zero in size in `/project/^your_root_project^/^your_project^/contigs/final_contigs/`. It is advised to check trimming quality on atleast a subset of samples using the included fastqc scripts. Furthermore check the size of the trimmed read files to ensure that an excessive number of reads isn't being removed. 
5. Run blastxRdRp and blastxRVDB (these can be run simultaneously). Run Fastqc script to check quality and presence of adapters.
6. Run blastnr and blastnt (these can be run simultaneously). Given an accession file this command will combine the blastcontigs from RdRp and RVDB and use it as input for nr and nt. As such you will notice there is only a single job ran for each instead of an array `pipeline_blastnr.sh` `pipeline_blastnt.sh`. Output is named after the -f file.
7.  Run the readcount script `pipeline_readcount.sh`
8.  Generate a summary table (Anaconda is needed - see below). The summary table script will create several files inside `/project/^your_root_project^/^your_project^/blast_results/summary_table_creation`. The csv files are the summary tables - if another format or summary would suit you best let me know and we can sit down and develop it. You can specify accessions if you only want to run the summary table on a subset of runs -f as normal. IMPORTANT check both the logs files generated in the logs folder `summary_table_creation_TODAY_stderr.txt` and `summary_table_creation_TODAY_stout.txt` as this will let you know if any of the inputs were missing etc. 

The large files e.g., raw and trimmed reads and abundance files are stored in `/scratch/` while the smaller files tend to be in /project/

Note: the pipeline requires server-installed reference databases (NR, NT, RVDB, RdRp-Scan), software modules, and taxonomy files (NCBI taxdb, taxize, RVDB tax); these are not downloaded automatically and must be available on the server.

1. Create an accession file: Make a plain-text file listing one library identifier per line. Each line may be an SRA run ID or a non-SRA library (see the “Non-SRA libraries” section). This accession file is the main input for the scripts.

2. (Optional) Download SRA data: Use the download script (for example, pipeline_download_sra.sh). Note: the scripts will be renamed to include your project name during setup. Skip this step if you already have the sequencing data.

3. Verify raw read downloads: Confirm the raw reads are present in /scratch/<root_project>/<project>/raw_reads. Use the provided check_sra_downloads.sh script to check for missing files and re-download any missing accessions (create a new accession file for re-downloads).

4. Trim reads, assemble, and calculate contig abundance: Run the trimming, assembly and abundance script (for example, pipeline_trim_assembly_abundance.sh). Current trim settings target TruSeq3 paired-end (PE) and single-end (SE) Illumina libraries. After assembly, check that contigs in /project/<root_project>/<project>/contigs/final_contigs/ are non-empty. It is recommended to run FastQC on a subset of samples (scripts included) to inspect trimming quality and to verify that an excessive number of reads are not being removed.

5. Run BLASTx searches against RdRp and RVDB: Execute the BLASTx jobs for RdRp and for RVDB; these can be run in parallel. Also run FastQC to check overall quality and adapter presence.

6. Run BLAST (nr and nt): Run the pipeline_blastnr.sh and pipeline_blastnt.sh scripts. Given an accession file, the pipeline combines contigs identified from RdRp and RVDB and uses them as input for the nr and nt searches. Because of this, each of these is launched as a single job (not an array) and outputs are named after the -f file.

7. Run read counting: Use pipeline_readcount.sh to count reads mapped to contigs.

8. Generate summary tables: Run the summary table script to produce output files in /project/<root_project>/<project>/blast_results/summary_table_creation. The CSV files in that folder are the summary tables. You can limit the summary to a subset of runs by supplying an accession file with -f. Always check the log files in the logs folder (summary_table_creation_TODAY_stderr.txt and summary_table_creation_TODAY_stdout.txt) to ensure all inputs were present and to identify any errors.

Note:

The pipeline depends on server-installed reference databases (NR, NT, RVDB, RdRp-Scan), software modules, and taxonomy files (NCBI taxdb, taxize, RVDB tax). These resources are not downloaded automatically and must be present on the server.
--------------------

## Acknowledgments
I'd like to acknowledge of the Holmes Lab for their contributions to the development of the USYD Artemis workflow which inspires this one.

--------------------

## How to cite this repo?
If this repo was somehow useful a citation would be greatly appeciated! Available at: https://github.com/cinthylorein/Virus_discovery_workflows.
