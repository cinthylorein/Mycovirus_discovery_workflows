# Virus discovery workflow

This repo contains virus discovery workflows on powerPlant and Nesi HPC. It can be use with your own sequencing data but with a particular focus on SRA mining for Mycoviruses. 

The premise of the workflow is to quickly set up a folder structure and script set for a given project and to provide a repo that we can refer to in our methods section in manuscripts. 

NOTE: This pipeline relies on several databases (NR, NT, RVDB and RdRp-Scan), modules and taxonomy files (NCBI taxdb, taxize, RVDB tax) that are made available on the server. At this stage 


--------------------
### Table of Contents
- [Virus discovery workflow](#Virus-discovery-workflow)
    - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Pipeline](#pipeline)
  - [Other tips](#other-tips)
    - [Monitoring Job Status](#monitoring-job-status)
    - [Job Status Shortcut](#job-status-shortcut)
    - [Common Flags](#common-flags)
    - [Non-SRA Libraries](#non-sra-libraries)
    - [Fastqc](#fastqc)
    - [Storage](#storage)
  - [Troubleshooting](#troubleshooting)
  - [Installing Anaconda](#installing-anaconda)
  - [Acknowledgments](#acknowledgments)
  - [How to cite this repo?](#how-to-cite-this-repo)

--------------------

## Installation

1. Clone the repo `git clone https://github.com/cinthylorein/Virus_discovery_workflows.git`
4. Enter the scripts folder, edit setup.sh `cd Virus discovery workflow-main/scripts/; chmod +x ./*; nano setup.sh`
5. Change the `root`, `project` and `email` parameters. 
6. Run the setup script `./setup.sh`
7. `cd ../../` and remove the install files `rm Virus discovery workflow-main Virus discovery workflow-main.zip`

Installing Aspera (ascp) is also recommended:

Under the hood Kingfisher is used to try multiple SRA download methods. One of the fastest and most reliable is ENA using aspera. In most cases, aspera will need to be installed. To do this check out the following:

https://www.biostars.org/p/325010/
https://www.ibm.com/aspera/connect/ 

Each general task you want to run is associated with a .sh (shell) and .slurm script. The .sh script works as a wrapper, passing parameters and variables to the .slurm script. After setting up, you usually don't need to edit the .slurm script.

If you are unsure about what variables/files to use just call the help flag `-h` e.g., `_pipeline_download_sra.sh -h` 

The scripts are designed to process batches, so they require a list of filenames to run.

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

--------------------

## Other tips

### Monitoring Job Status

You can check the status of a job using `qstat -u USERNAME`. This will show you the status of the batch scripts. To check the status of individual subjobs within a batch, use `qstat -tx JOB_ID`.

### Job Status Shortcut
Replace hraczj with your unikey and run the following line to create an alias for `q`. This will display two panels: the top panel shows the last 100 jobs/subjobs, while the bottom panel provides a summary of batch jobs:

`alias q="qstat -Jtan1 -xu ^your_username^ | tail -n100; qstat -u ^your_username^"`
Enter q to check the job status. If you want to make this alias permanent, add it to your .bashrc file:

`nano ~/.bashrc`
Add the line: `alias q="qstat -Jtan1 -xu ^your_username^ | tail -n100; qstat -u ^your_username^"`

Then to load it: `source ~/.bashrc`

Add the commands to your path
`nano ~/.bashrc`
Add the line: 
`export PATH="/project/YOURROOT/YOURPROJECT/scripts/:$PATH"`

Make sure to change the variable names!

Then to load it: `source ~/.bashrc`

### Common Flags

Note: Flags can vary between scripts, If you are unsure about what variables/files to use just call the help flag `-h` e.g., `_pipeline_download_sra.sh -h`

However, the common flags are as follows:

`-f` used to specify a file that contains the SRA run accessions to be processed. This option is followed by a string containing the complete path to a file containing accessions one per line. I typically store these files in `/project/your_root/your_project/accession_lists/`. If this option is not provided, most of the scripts in the pipeline will fail or excetue other behaviours (e.g., see the -f in `trim_assembly_abundance.sh`), as such I always recommmend setting the -f where able so you can better keep track of the libraries you are running. NOTE: The max number of SRAs I would put in a accession file is 1000. If you have more than this create two files and run the download_script twice. The limit is enforced by Slurm. 

**Less common**
`-i` The input option. This option is followed by a string that represents the input file for the script. This is used most commonly in the custom blast scripts where you are interested in a single input rather than an array of files. 
`-d` The database option. This option should be followed by a string that represents the complete path to a database against which blast will be run.

**Rarely need to change**
The way the pipeline is set up the values for root and project that you entered in the setup script are used as the default project (-p flag) and root (-r flag) values in all scripts.
There may be cases where you want to run these functions in directories outside of the normal pipeline structure. The blast custom scripts, mafft alignment and iqtree scripts are designed with this inmind. Input is specified using -i, while the output is the current WD. With other functions it may just be easier to redownload the github .zip file and rerun the setup script as described above - creating the folder sctruture and scripts for the new project.

`-p` The project option. This option should be followed by a string that represents the project name i.e. what you entered as project in the original setup script. 
`-r` The root project option. This option should be followed by a string that represents the root project name. Use e.g., -r VELAB or the value you entered for root in the original setup script. 

You only need to specify -p or -r if you are going outside of the directory stucture in which the setup.sh was ran for. 

### Non-SRA Libraries

You can also use the script with non-SRA libraries by cleaning the original raw read names. For example, `hope_valley3_10_HWGFMDSX5_CCTGCAACCT-CTGACTCTAC`

E.g., hope_valley3_10_HWGFMDSX5_CCTGCAACCT-CTGACTCTAC_L002_R1.fastq.gz -> hpv3t10_1.fastq.gz
The main thing is that underscores are only used to seperate the ID (hpv3t10) and the read file direction (1) and that the "R" in R1/2 is remove. 

### Fastqc

If you would like to examine the qc of libraries before and after trimming you can use the `_fastqc.sh` script. This takes the standard accession_list file and will run fastqc on the raw reads and the two outputs from the trimmed reads, 1. the trimmed reads i.e. those that are kept and 2. the removed reads. Check `/project/your_root/your_project/fastqc/` for results. So ensure that you run this after the `_trim_assembly_abundance.sh`.

### Storage

I tend to delete the raw and trimmed read files after contigs are the trim_assembly_abundance script has completed as abundance and read count (make sure to run this!) information has been calculated at this stage. Once the summary table is created there are a couple large files in this directory including the concatentated abundance table. This can be remade so consider removing this if you are low on storage. 

--------------------

## Acknowledgments
I'd like to acknowledge of the Holmes Lab for their contributions to the development of th USYD Artemis workflow which inspires this one.

--------------------

## How to cite this repo?
If this repo was somehow useful a citation would be greatly appeciated! Available at: https://github.com/cinthylorein/Virus_discovery_workflows.
