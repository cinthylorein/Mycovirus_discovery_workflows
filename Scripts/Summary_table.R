#!/usr/bin/env Rscript

# Summary_table.R
# A runnable script to combine and annotate BLAST result CSVs (blastx / blastn)
# Usage examples:
# Rscript Pipeline_A_scripts_Summary_table.R --db /path/to/NCBI_AllVirus_DB.csv --inputs "sample1_blastx.csv,sample2_blastx.csv" --format blastx --outdir ./results
# Rscript Pipeline_A_scripts_Summary_table.R --db /path/to/NCBI_AllVirus_DB.csv --inputs "/data/*_blastx.csv" --format blastx --outdir ./results
#
# Arguments:
# --db       : path to the BLASTDB metadata CSV (required)
# --inputs   : comma-separated list of blast result files, or a glob pattern (required)
# --format   : "blastx" or "blastn" (default: blastx) — used to assign expected column names
# --outdir   : directory to write outputs (default: current working directory)
# --prefix   : prefix for output filenames (default: combined_blast)
#
# The script:
# - reads the DB csv and renames Accession -> Accession.Ver if needed
# - reads each blast file, assigns columns according to format, calculates coverage (length / qlen) if qlen available
# - left joins per-hit metadata from DB using Accession.Ver
# - combines all inputs into one dataframe, adds a sample column derived from the filename
# - writes combined and unique-ID CSVs

suppressPackageStartupMessages({
  required_pkgs <- c("optparse", "readr", "dplyr", "purrr", "stringr")
  for (pkg in required_pkgs) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      install.packages(pkg, repos = "https://cloud.r-project.org")
    }
  }
  library(optparse)
  library(readr)
  library(dplyr)
  library(purrr)
  library(stringr)
})

option_list <- list(
  make_option(c("--db"), type="character", default=NULL,
              help="Path to BLASTDB metadata CSV (required)", metavar="character"),
  make_option(c("--inputs"), type="character", default=NULL,
              help="Comma-separated list of blast result files, OR a single glob pattern (required). e.g. 's1.csv,s2.csv' or '/path/*_blastx.csv'", metavar="character"),
  make_option(c("--format"), type="character", default="blastx",
              help="blast result format: 'blastx' or 'blastn' (default: %default)", metavar="character"),
  make_option(c("--outdir"), type="character", default=".",
              help="Output directory (default: current directory)", metavar="character"),
  make_option(c("--prefix"), type="character", default="combined_blast",
              help="Prefix for output files (default: %default)", metavar="character")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Validate required args
if (is.null(opt$db) || is.null(opt$inputs)) {
  cat("ERROR: --db and --inputs are required arguments.\n\n")
  print_help(opt_parser)
  quit(status = 1)
}

db_path <- opt$db
inputs_arg <- opt$inputs
format <- tolower(opt$format)
outdir <- opt$outdir
prefix <- opt$prefix

if (!dir.exists(outdir)) dir.create(outdir, recursive = TRUE)

cat("Reading BLAST DB metadata from:", db_path, "\n")
if (!file.exists(db_path)) {
  stop("BLAST DB metadata file does not exist: ", db_path)
}

# Read BLAST database metadata CSV (attempt readr then base read.csv as fallback)
BLASTDB <- tryCatch(
  readr::read_csv(db_path, show_col_types = FALSE),
  error = function(e) read.csv(db_path, header = TRUE, stringsAsFactors = FALSE)
)

# Normalize accession column name
if ("Accession" %in% colnames(BLASTDB) && !("Accession.Ver" %in% colnames(BLASTDB))) {
  colnames(BLASTDB)[colnames(BLASTDB) == "Accession"] <- "Accession.Ver"
}

# Determine list of input files
# If the user provided a glob pattern (contains * ? or []), expand with Sys.glob.
expand_inputs <- function(in_arg) {
  # split comma separated
  parts <- strsplit(in_arg, ",")[[1]] %>% trimws()
  files <- c()
  for (p in parts) {
    if (grepl("[*?\\[\\]]", p)) {
      g <- Sys.glob(p)
      if (length(g) == 0) {
        warning("Glob pattern matched no files: ", p)
      }
      files <- c(files, g)
    } else {
      files <- c(files, p)
    }
  }
  # remove duplicates, non-existent files produce a warning but keep only existing
  files <- unique(files)
  files <- files[file.exists(files)]
  if (length(files) == 0) {
    stop("No input files found from --inputs: ", in_arg)
  }
  return(files)
}

input_files <- expand_inputs(inputs_arg)
cat("Found", length(input_files), "input file(s):\n")
for (f in input_files) cat(" -", f, "\n")

# Column name templates
blastn_cols <- c("qseqid","Accession.Ver","pident","staxid","ssciname","length","mismatch","gapopen","qstart","qend","sstart","send","evalue","bitscore","qlen")
# blastx often has fewer columns; this is a common selection
blastx_cols <- c("qseqid","Accession.Ver","pident","length","mismatch","gapopen","qstart","qend","sstart","send","evalue","bitscore","qlen")

# Function to read a single blast file and normalize columns
read_blast_file <- function(path, fmt = c("blastx","blastn")) {
  fmt <- match.arg(fmt)
  # Try reading with read_delim guessing whitespace/tab separated
  df <- tryCatch({
    readr::read_delim(path, delim = "\t", col_names = FALSE, show_col_types = FALSE)
  }, error = function(e) {
    # fallback to read_csv with commas
    tryCatch(readr::read_csv(path, col_names = FALSE, show_col_types = FALSE),
             error = function(e2) stop("Failed to read blast file: ", path))
  })
  # If the file already has header row that matches any known names, read again with header
  first_row <- as.character(unlist(df[1,]))
  known_names <- unique(c(blastn_cols, blastx_cols))
  # Heuristic: if first row contains known names entirely or largely, re-read with header
  hit_names <- sum(tolower(first_row) %in% tolower(known_names))
  if (hit_names >= 3) {
    # treat as header
    df <- tryCatch({
      readr::read_delim(path, delim = "\t", col_names = TRUE, show_col_types = FALSE)
    }, error = function(e) {
      tryCatch(readr::read_csv(path, col_names = TRUE, show_col_types = FALSE),
               error = function(e2) df) # keep previous
    })
  }
  # Assign column names if missing or generic V1..Vn
  if (fmt == "blastn") {
    expected <- blastn_cols
  } else {
    expected <- blastx_cols
  }
  # If the dataframe already has column names matching expected, keep them.
  existing_names <- colnames(df)
  if (!all(expected %in% existing_names)) {
    # If number of cols matches length of expected, assign them
    if (ncol(df) >= length(expected)) {
      colnames(df)[1:length(expected)] <- expected
    } else {
      # If fewer columns than expected, try to map common columns: qseqid, Accession.Ver, pident, length, evalue, bitscore, qlen
      short_map <- c("qseqid","Accession.Ver","pident","length","evalue","bitscore","qlen")
      n <- min(ncol(df), length(short_map))
      colnames(df)[1:n] <- short_map[1:n]
      # Warn the user
      warning("File ", path, " had ", ncol(df), " columns; assigned first ", n, " column names. You may need to check column mapping.")
    }
  }
  # Ensure Accession.Ver column exists (or maybe it's called saccver, sseqid). Try to coerce common names to Accession.Ver
  if (!"Accession.Ver" %in% colnames(df)) {
    if ("saccver" %in% tolower(colnames(df))) {
      colnames(df)[tolower(colnames(df)) == "saccver"] <- "Accession.Ver"
    } else if ("sseqid" %in% tolower(colnames(df))) {
      colnames(df)[tolower(colnames(df)) == "sseqid"] <- "Accession.Ver"
    } else if ("subject" %in% tolower(colnames(df))) {
      colnames(df)[tolower(colnames(df)) == "subject"] <- "Accession.Ver"
    }
  }
  # Convert to tibble
  df <- as_tibble(df)
  # compute coverage if qlen present
  if ("length" %in% colnames(df) && "qlen" %in% colnames(df)) {
    df <- df %>% mutate(coverage = as.numeric(length) / as.numeric(qlen))
  } else {
    df <- df %>% mutate(coverage = NA_real_)
  }
  return(df)
}

# Read and process each file, then left_join with BLASTDB
processed_list <- map(input_files, function(fpath) {
  cat("Processing:", fpath, " ...\n")
  df <- read_blast_file(fpath, fmt = format)
  # Add a sample column derived from filename (strip directory and common suffixes)
  sample_name <- basename(fpath) %>%
    str_replace_all("\\.csv$|\\.tsv$|\\.blast$|_blastx|_blastn|_merged", "") %>%
    str_replace_all("\\..*$", "")
  df <- df %>% mutate(source_file = fpath, sample = sample_name)
  # Ensure Accession.Ver is character (some reads may be numeric)
  if ("Accession.Ver" %in% colnames(df)) {
    df <- df %>% mutate(Accession.Ver = as.character(Accession.Ver))
  }
  # Join to BLASTDB by Accession.Ver (if present)
  if ("Accession.Ver" %in% colnames(df)) {
    df <- left_join(df, BLASTDB, by = "Accession.Ver")
  } else {
    warning("No Accession.Ver column in file: ", fpath, " — skipping DB join for this file.")
  }
  return(df)
})

combined_df <- bind_rows(processed_list)

# Write combined CSV
combined_path <- file.path(outdir, paste0(prefix, "_combined.csv"))
cat("Writing combined data to:", combined_path, "\n")
readr::write_csv(combined_df, combined_path)

# Write unique IDs file similar to previous script selection; attempt to pick existing columns
# Columns to attempt: pident, Accession (or Accession.Ver), qseqid, Organism_Name, Species, Genus, Family, length, sstart, send, coverage, evalue, source_df (or source_file or sample)
select_columns <- c("pident","Accession","Accession.Ver","qseqid","Organism_Name","Species","Genus","Family","length","sstart","send","coverage","evalue","source_df","source_file","sample")

available_cols <- intersect(select_columns, colnames(combined_df))
# prefer nicer column ordering: choose a preferred subset if available
preferred_order <- c("pident","Accession.Ver","qseqid","Organism_Name","Species","Genus","Family","length","sstart","send","coverage","evalue","sample","source_file")
available_preferred <- intersect(preferred_order, colnames(combined_df))
if (length(available_preferred) == 0) {
  # fallback: use all available columns
  unique_df <- combined_df %>% distinct(qseqid, .keep_all = TRUE)
} else {
  unique_df <- combined_df %>% distinct(qseqid, .keep_all = TRUE) %>% select(all_of(available_preferred))
}

unique_path <- file.path(outdir, paste0(prefix, "_uniqueIDs.csv"))
cat("Writing unique IDs to:", unique_path, "\n")
# The original script wrote without row names and without column names; we'll include column names.
readr::write_csv(unique_df, unique_path)

cat("Done. Outputs:\n")
cat(" -", format, combined_path, "\n")
cat(" -", format, unique_path, "\n")