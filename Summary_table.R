#!/usr/bin/env Rscript

# Summary_table.R
#
# Combine and annotate BLAST/DIAMOND result tables from multiple samples.
# Supports blastn, blastx, diamond tabular outputs.
# Adds:
# - coverage = length / qlen (when available)
# - top20_family flag
# - plot_caption field for downstream plotting

required_pkgs <- c("optparse", "readr", "dplyr", "purrr", "stringr", "tibble")

missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop(
    "Missing required R packages: ", paste(missing_pkgs, collapse = ", "), "\n",
    "Please install them before running the script."
  )
}

suppressPackageStartupMessages({
  library(optparse)
  library(readr)
  library(dplyr)
  library(purrr)
  library(stringr)
  library(tibble)
})

option_list <- list(
  make_option(c("--db"), type = "character", default = NULL,
              help = "Path to BLASTDB metadata CSV (required)", metavar = "character"),
  make_option(c("--inputs"), type = "character", default = NULL,
              help = "Comma-separated list of result files, OR a single glob pattern (required)", metavar = "character"),
  make_option(c("--format"), type = "character", default = "blastx",
              help = "Result format: blastx, blastn, or diamond [default: %default]", metavar = "character"),
  make_option(c("--outdir"), type = "character", default = ".",
              help = "Output directory [default: current directory]", metavar = "character"),
  make_option(c("--prefix"), type = "character", default = "combined_blast",
              help = "Prefix for output files [default: %default]", metavar = "character")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

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

valid_formats <- c("blastx", "blastn", "diamond")
if (!(format %in% valid_formats)) {
  stop("--format must be one of: ", paste(valid_formats, collapse = ", "))
}

if (!dir.exists(outdir)) {
  dir.create(outdir, recursive = TRUE)
}

cat("Reading metadata DB:", db_path, "\n")
if (!file.exists(db_path)) stop("Metadata DB does not exist: ", db_path)

BLASTDB <- tryCatch(
  readr::read_csv(db_path, show_col_types = FALSE),
  error = function(e) read.csv(db_path, header = TRUE, stringsAsFactors = FALSE)
) %>% as_tibble()

# Normalize accession column in DB
if ("Accession" %in% colnames(BLASTDB) && !("Accession.Ver" %in% colnames(BLASTDB))) {
  colnames(BLASTDB)[colnames(BLASTDB) == "Accession"] <- "Accession.Ver"
}
if ("Accession.Ver" %in% colnames(BLASTDB)) {
  BLASTDB <- BLASTDB %>% mutate(Accession.Ver = as.character(Accession.Ver))
} else {
  warning("Metadata DB has no Accession.Ver column. Metadata join will be skipped.")
}

expand_inputs <- function(in_arg) {
  parts <- strsplit(in_arg, ",")[[1]]
  parts <- trimws(parts)
  parts <- parts[nzchar(parts)]

  files <- c()
  for (p in parts) {
    if (grepl("[*?\\[\\]]", p)) {
      g <- Sys.glob(p)
      if (length(g) == 0) warning("Glob pattern matched no files: ", p)
      files <- c(files, g)
    } else {
      files <- c(files, p)
    }
  }

  files <- unique(files)
  files <- files[file.exists(files)]
  if (length(files) == 0) stop("No input files found from --inputs: ", in_arg)
  files
}

input_files <- expand_inputs(inputs_arg)
cat("Found", length(input_files), "input file(s)\n")
for (f in input_files) cat(" -", f, "\n")

# Expected layouts
blastn_cols_15 <- c(
  "qseqid", "Accession.Ver", "pident", "staxid", "ssciname", "length",
  "mismatch", "gapopen", "qstart", "qend", "sstart", "send",
  "evalue", "bitscore", "qlen"
)

# blastx mapped same as blastn for your pipeline
blastx_cols_15 <- c(
  "qseqid", "Accession.Ver", "pident", "staxid", "ssciname", "length",
  "mismatch", "gapopen", "qstart", "qend", "sstart", "send",
  "evalue", "bitscore", "qlen"
)

# DIAMOND outfmt 6 qseqid qlen sseqid stitle pident length evalue bitscore
diamond_cols_8 <- c(
  "qseqid", "qlen", "sseqid", "stitle", "pident", "length", "evalue", "bitscore"
)

strip_accession_version <- function(x) {
  x <- as.character(x)
  sub("\\.\\d+$", "", x)
}

assign_columns <- function(df, fmt, path) {
  n <- ncol(df)

  if (fmt %in% c("blastn", "blastx")) {
    expected <- if (fmt == "blastn") blastn_cols_15 else blastx_cols_15
    if (n >= length(expected)) {
      colnames(df)[seq_along(expected)] <- expected
      if (n > length(expected)) {
        extras <- seq(length(expected) + 1, n)
        colnames(df)[extras] <- paste0("X", extras)
        warning("File ", path, " has ", n, " columns; expected ", length(expected), " for ", fmt, ". Extra columns kept as X*.")
      }
    } else {
      warning("File ", path, " has only ", n, " columns; expected ", length(expected), " for ", fmt, ". Missing columns set to NA.")
      colnames(df) <- expected[seq_len(n)]
      for (k in (n + 1):length(expected)) df[[expected[k]]] <- NA
      df <- df[, expected, drop = FALSE]
    }
  } else if (fmt == "diamond") {
    expected <- diamond_cols_8
    if (n >= length(expected)) {
      colnames(df)[seq_along(expected)] <- expected
      if (n > length(expected)) {
        extras <- seq(length(expected) + 1, n)
        colnames(df)[extras] <- paste0("X", extras)
        warning("File ", path, " has ", n, " columns; expected ", length(expected), " for diamond. Extra columns kept as X*.")
      }
    } else {
      warning("File ", path, " has only ", n, " columns; expected ", length(expected), " for diamond. Missing columns set to NA.")
      colnames(df) <- expected[seq_len(n)]
      for (k in (n + 1):length(expected)) df[[expected[k]]] <- NA
      df <- df[, expected, drop = FALSE]
    }
  }

  as_tibble(df)
}

normalize_hit_columns <- function(df) {
  lower_names <- tolower(colnames(df))

  if (!("Accession.Ver" %in% colnames(df))) {
    if ("saccver" %in% lower_names) {
      colnames(df)[which(lower_names == "saccver")[1]] <- "Accession.Ver"
    } else if ("sacc" %in% lower_names) {
      colnames(df)[which(lower_names == "sacc")[1]] <- "Accession.Ver"
    } else if ("sseqid" %in% lower_names) {
      colnames(df)[which(lower_names == "sseqid")[1]] <- "Accession.Ver"
    } else if ("subject" %in% lower_names) {
      colnames(df)[which(lower_names == "subject")[1]] <- "Accession.Ver"
    }
  }

  num_cols <- intersect(
    c("pident", "length", "mismatch", "gapopen", "qstart", "qend",
      "sstart", "send", "evalue", "bitscore", "qlen", "staxid"),
    colnames(df)
  )
  for (cn in num_cols) df[[cn]] <- suppressWarnings(as.numeric(df[[cn]]))

  if ("Accession.Ver" %in% colnames(df)) df$Accession.Ver <- as.character(df$Accession.Ver)
  if ("sseqid" %in% colnames(df)) df$sseqid <- as.character(df$sseqid)

  # For diamond, promote sseqid to Accession.Ver when missing
  if (!("Accession.Ver" %in% colnames(df)) && "sseqid" %in% colnames(df)) {
    df$Accession.Ver <- df$sseqid
  }

  # accession base for fallback joining
  if ("Accession.Ver" %in% colnames(df)) {
    df <- df %>% mutate(Accession_base = strip_accession_version(Accession.Ver))
  } else {
    df <- df %>% mutate(Accession_base = NA_character_)
  }

  # coverage
  if ("length" %in% colnames(df) && "qlen" %in% colnames(df)) {
    df <- df %>% mutate(
      coverage = ifelse(!is.na(qlen) & qlen > 0, as.numeric(length) / as.numeric(qlen), NA_real_)
    )
  } else {
    df <- df %>% mutate(coverage = NA_real_)
  }

  df
}

read_result_file <- function(path, fmt = c("blastx", "blastn", "diamond")) {
  fmt <- match.arg(fmt)

  raw <- tryCatch(
    readr::read_delim(path, delim = "\t", col_names = FALSE, show_col_types = FALSE, progress = FALSE),
    error = function(e) {
      tryCatch(
        readr::read_csv(path, col_names = FALSE, show_col_types = FALSE, progress = FALSE),
        error = function(e2) stop("Failed to read file: ", path)
      )
    }
  )

  if (nrow(raw) == 0 && ncol(raw) == 0) {
    warning("File appears empty: ", path)
    return(tibble())
  }

  # detect possible header row
  first_row <- tryCatch(as.character(unlist(raw[1, ])), error = function(e) character(0))
  known <- tolower(unique(c(
    blastn_cols_15, blastx_cols_15, diamond_cols_8, "sacc", "saccver", "sseqid", "subject"
  )))
  header_hits <- sum(tolower(first_row) %in% known)

  if (header_hits >= 3) {
    raw <- tryCatch(
      readr::read_delim(path, delim = "\t", col_names = TRUE, show_col_types = FALSE, progress = FALSE),
      error = function(e) {
        tryCatch(
          readr::read_csv(path, col_names = TRUE, show_col_types = FALSE, progress = FALSE),
          error = function(e2) raw
        )
      }
    )
  }

  df <- as_tibble(raw)

  generic <- all(grepl("^X[0-9]+$", colnames(df)))
  if (generic || !("qseqid" %in% tolower(colnames(df)))) {
    df <- assign_columns(df, fmt, path)
  }

  df <- normalize_hit_columns(df)
  df
}

# Prepare DB fallback accession base
if ("Accession.Ver" %in% colnames(BLASTDB)) {
  BLASTDB <- BLASTDB %>%
    mutate(
      Accession.Ver = as.character(Accession.Ver),
      Accession_base = strip_accession_version(Accession.Ver)
    )
}

processed_list <- purrr::map(input_files, function(fpath) {
  cat("Processing:", fpath, "\n")
  df <- read_result_file(fpath, fmt = format)

  if (nrow(df) == 0) {
    warning("No rows found in: ", fpath)
    return(df)
  }

  sample_name <- basename(fpath) %>%
    str_replace("\\.csv$", "") %>%
    str_replace("\\.tsv$", "") %>%
    str_replace("_nt_blast$", "") %>%
    str_replace("_blastn_nt$", "") %>%
    str_replace("_nr_blastx$", "") %>%
    str_replace("_tx_blast$", "") %>%
    str_replace("_rdrp_diamond$", "") %>%
    str_replace("_rdrp_blast$", "") %>%
    str_replace("_blastx$", "") %>%
    str_replace("_blastn$", "") %>%
    str_replace("_merged$", "")

  df <- df %>%
    mutate(
      source_file = fpath,
      sample = sample_name,
      search_format = format
    )

  # metadata join
  if ("Accession.Ver" %in% colnames(df) && "Accession.Ver" %in% colnames(BLASTDB)) {
    joined <- df %>% left_join(BLASTDB, by = "Accession.Ver", suffix = c("", ".db"))

    # fallback rows (no organism after exact join)
    need_fallback <- if ("Organism_Name" %in% colnames(joined)) is.na(joined$Organism_Name) else rep(TRUE, nrow(joined))

    if (any(need_fallback) && "Accession_base" %in% colnames(df) && "Accession_base" %in% colnames(BLASTDB)) {
      db_fallback <- BLASTDB %>%
        filter(!is.na(Accession_base), Accession_base != "") %>%
        distinct(Accession_base, .keep_all = TRUE)

      fallback_part <- joined[need_fallback, , drop = FALSE] %>%
        mutate(.row_id_tmp = row_number())

      if (!("Accession_base" %in% colnames(fallback_part))) {
        if ("Accession.Ver" %in% colnames(fallback_part)) {
          fallback_part <- fallback_part %>%
            mutate(Accession_base = strip_accession_version(as.character(Accession.Ver)))
        }
      }

      if ("Accession_base" %in% colnames(fallback_part)) {
        fallback_join <- fallback_part %>%
          left_join(db_fallback, by = "Accession_base", suffix = c("", ".fb"))

        fb_cols <- grep("\\.fb$", colnames(fallback_join), value = TRUE)
        for (fb in fb_cols) {
          base <- sub("\\.fb$", "", fb)
          if (!(base %in% colnames(fallback_join))) fallback_join[[base]] <- NA
          idx <- is.na(fallback_join[[base]]) & !is.na(fallback_join[[fb]])
          fallback_join[[base]][idx] <- fallback_join[[fb]][idx]
        }

        fallback_join <- fallback_join %>% select(-any_of(fb_cols))
        joined_idx <- which(need_fallback)
        common_cols <- intersect(colnames(joined), colnames(fallback_join))
        joined[joined_idx, common_cols] <- fallback_join[, common_cols, drop = FALSE]
      }
    }

    df <- joined
  } else {
    warning("Accession.Ver missing in hits or metadata; skipping metadata join for: ", fpath)
  }

  cat("  rows:", nrow(df), "\n")
  cat("  columns:", paste(head(colnames(df), 20), collapse = ", "), if (ncol(df) > 20) "..." else "", "\n")
  df
})

combined_df <- bind_rows(processed_list)

# Add top-20 and caption
family_counts <- combined_df %>%
  filter(!is.na(Family), Family != "") %>%
  count(Family, sort = TRUE)

top20_families <- family_counts %>% slice_head(n = 20) %>% pull(Family)

caption_text <- paste(
  "Top 20 viral families were selected by descending hit count (number of records) in the combined dataset;",
  "no additional filtering thresholds were applied."
)

combined_df <- combined_df %>%
  mutate(
    top20_family = ifelse(!is.na(Family) & Family %in% top20_families, TRUE, FALSE),
    plot_caption = caption_text
  )

combined_path <- file.path(outdir, paste0(prefix, "_combined.csv"))
cat("Writing combined file:", combined_path, "\n")
readr::write_csv(combined_df, combined_path)

preferred_order <- c(
  "qseqid", "Accession.Ver", "pident", "length", "qlen", "coverage", "evalue", "bitscore",
  "sample", "search_format", "Organism_Name", "Species", "Genus", "Family",
  "top20_family", "plot_caption", "source_file"
)

if ("qseqid" %in% colnames(combined_df)) {
  unique_df <- combined_df %>% distinct(qseqid, .keep_all = TRUE)
} else {
  unique_df <- combined_df
}

available_preferred <- intersect(preferred_order, colnames(unique_df))
if (length(available_preferred) > 0) {
  unique_df <- unique_df %>% select(all_of(available_preferred), everything())
}

unique_path <- file.path(outdir, paste0(prefix, "_uniqueIDs.csv"))
cat("Writing unique IDs file:", unique_path, "\n")
readr::write_csv(unique_df, unique_path)

top20_path <- file.path(outdir, paste0(prefix, "_top20_families.csv"))
cat("Writing top-20 family summary:", top20_path, "\n")
readr::write_csv(
  family_counts %>% slice_head(n = 20) %>% mutate(rank = row_number()) %>% select(rank, everything()),
  top20_path
)

cat("Done.\n")
cat(" - Combined:", combined_path, "\n")
cat(" - Unique  :", unique_path, "\n")
cat(" - Top20   :", top20_path, "\n")