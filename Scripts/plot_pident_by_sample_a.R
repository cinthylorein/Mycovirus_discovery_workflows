#!/usr/bin/env Rscript
#
# plot_pident_by_sample.R
#
# Plot % identity (pident) vs sample, colored by taxonomic family,
# with optional BLAST-quality filtering (coverage, read length, aln length, evalue, bitscore, pident).
#
# Expected columns (from your header):
# sample, Family, pident, evalue, bitscore, qlen, coverage, length
#
# Usage examples:
# Rscript Pipeline_A_scripts/plot_pident_by_sample.R --input combined_blast_combined.tsv --output pident_filtered.png \
#   --filter-min-readlen 200 --filter-min-coverage 0.5 --filter-min-pident 75 --filter-max-evalue 1e-5 --filter-min-alnlen 150 \
#   --write-filtered filtered_hits.tsv
#
# Notes:
# - 'qlen' is query/read length.
# - 'length' is BLAST alignment length (HSP length) in outfmt 6.
# - 'coverage' is assumed 0-1 (as in your previous script). If yours is 0-100, use --coverage-scale 100.
#

suppressPackageStartupMessages({
  required <- c("optparse", "readr", "dplyr", "ggplot2", "forcats", "stringr", "scales", "tools")
  for (p in required) {
    if (!requireNamespace(p, quietly = TRUE)) {
      install.packages(p, repos = "https://cloud.r-project.org")
    }
  }
  library(optparse)
  library(readr)
  library(dplyr)
  library(ggplot2)
  library(forcats)
  library(stringr)
  library(scales)
  library(tools)
})

option_list <- list(
  make_option(c("--input"), type = "character", default = NULL,
              help = "Input table (CSV/TSV). Required.", metavar = "character"),
  make_option(c("--output"), type = "character", default = "pident_by_sample.png",
              help = "Output plot file (png/pdf/svg). [default: %default]", metavar = "character"),

  make_option(c("--plot-type"), type = "character", default = "jitter",
              help = "Plot type: jitter, box, violin, boxjitter [default: %default]", metavar = "character"),

  make_option(c("--sample-col"), type = "character", default = "sample",
              help = "Sample column name [default: %default]", metavar = "character"),
  make_option(c("--pident-col"), type = "character", default = "pident",
              help = "Percent identity column name [default: %default]", metavar = "character"),
  make_option(c("--family-col"), type = "character", default = "Family",
              help = "Family column name for coloring [default: %default]", metavar = "character"),

  make_option(c("--coverage-col"), type = "character", default = "coverage",
              help = "Coverage column name (0-1 or 0-100) [default: %default]", metavar = "character"),
  make_option(c("--readlen-col"), type = "character", default = "qlen",
              help = "Read/query length column name [default: %default]", metavar = "character"),
  make_option(c("--alnlen-col"), type = "character", default = "length",
              help = "Alignment length column name (BLAST HSP length) [default: %default]", metavar = "character"),
  make_option(c("--evalue-col"), type = "character", default = "evalue",
              help = "E-value column name [default: %default]", metavar = "character"),
  make_option(c("--bitscore-col"), type = "character", default = "bitscore",
              help = "Bitscore column name [default: %default]", metavar = "character"),

  # Filters
  make_option(c("--filter-min-coverage"), type = "double", default = NA,
              help = "Keep hits with coverage >= value. If coverage is 0-100, set --coverage-scale 100. Default: no filter.",
              metavar = "double"),
  make_option(c("--filter-min-readlen"), type = "integer", default = NA,
              help = "Keep hits with read/query length >= value (bp). Default: no filter.", metavar = "integer"),
  make_option(c("--filter-min-alnlen"), type = "integer", default = NA,
              help = "Keep hits with alignment length >= value (bp/aa). Default: no filter.", metavar = "integer"),
  make_option(c("--filter-min-pident"), type = "double", default = NA,
              help = "Keep hits with pident >= value (0-100). Default: no filter.", metavar = "double"),
  make_option(c("--filter-max-evalue"), type = "double", default = NA,
              help = "Keep hits with evalue <= value. Default: no filter.", metavar = "double"),
  make_option(c("--filter-min-bitscore"), type = "double", default = NA,
              help = "Keep hits with bitscore >= value. Default: no filter.", metavar = "double"),

  make_option(c("--coverage-scale"), type = "double", default = 1,
              help = "If coverage is in percent (0-100), set this to 100 so we convert to 0-1. Default: %default",
              metavar = "double"),

  make_option(c("--write-filtered"), type = "character", default = NA,
              help = "Write filtered dataset to this path (CSV/TSV inferred from extension). Optional.", metavar = "character"),

  # Plot aesthetics
  make_option(c("--width"), type = "double", default = 10,
              help = "Plot width in inches [default: %default]", metavar = "double"),
  make_option(c("--height"), type = "double", default = 6,
              help = "Plot height in inches [default: %default]", metavar = "double"),
  make_option(c("--dpi"), type = "integer", default = 300,
              help = "DPI for raster formats [default: %default]", metavar = "integer"),
  make_option(c("--rotate-x"), type = "integer", default = 45,
              help = "Rotation of x-axis labels in degrees [default: %default]", metavar = "integer"),
  make_option(c("--alpha"), type = "double", default = 0.6,
              help = "Alpha/transparency for points [default: %default]", metavar = "double")
)

opt <- parse_args(OptionParser(option_list = option_list))

if (is.null(opt$input)) {
  cat("ERROR: --input is required\n\n")
  print_help(OptionParser(option_list = option_list))
  quit(status = 1)
}

input <- opt$input
output <- opt$output
plot_type <- tolower(opt$`plot-type`)

sample_col <- opt$`sample-col`
pident_col <- opt$`pident-col`
family_col <- opt$`family-col`

coverage_col <- opt$`coverage-col`
readlen_col <- opt$`readlen-col`
alnlen_col <- opt$`alnlen-col`
evalue_col <- opt$`evalue-col`
bitscore_col <- opt$`bitscore-col`

min_cov <- opt$`filter-min-coverage`
min_readlen <- opt$`filter-min-readlen`
min_alnlen <- opt$`filter-min-alnlen`
min_pident <- opt$`filter-min-pident`
max_evalue <- opt$`filter-max-evalue`
min_bitscore <- opt$`filter-min-bitscore`

cov_scale <- opt$`coverage-scale`

write_filtered <- opt$`write-filtered`

w <- opt$width
h <- opt$height
dpi <- opt$dpi
rotate_x <- opt$`rotate-x`
alpha_pt <- opt$alpha

if (!file.exists(input)) stop("Input file does not exist: ", input)

# ----- Read input (CSV/TSV autodetect by extension) -----
ext <- tolower(tools::file_ext(input))
message("Reading input: ", input)

df <- tryCatch({
  if (ext %in% c("tsv", "tab", "txt")) {
    readr::read_tsv(input, show_col_types = FALSE)
  } else {
    readr::read_csv(input, show_col_types = FALSE)
  }
}, error = function(e) {
  stop("Failed to read input file: ", e$message)
})

# ----- Validate required columns -----
required_cols <- c(sample_col, pident_col, family_col)
missing_required <- setdiff(required_cols, colnames(df))
if (length(missing_required) > 0) {
  stop(
    "Missing required columns: ", paste(missing_required, collapse = ", "),
    "\nAvailable columns: ", paste(colnames(df), collapse = ", ")
  )
}

# ----- Coerce columns -----
to_num <- function(x) suppressWarnings(as.numeric(x))

df[[pident_col]] <- to_num(df[[pident_col]])
df[[sample_col]] <- as.character(df[[sample_col]])
df[[family_col]] <- as.character(df[[family_col]])

if (coverage_col %in% colnames(df)) df[[coverage_col]] <- to_num(df[[coverage_col]])
if (readlen_col %in% colnames(df))  df[[readlen_col]]  <- to_num(df[[readlen_col]])
if (alnlen_col %in% colnames(df))   df[[alnlen_col]]   <- to_num(df[[alnlen_col]])
if (evalue_col %in% colnames(df))   df[[evalue_col]]   <- to_num(df[[evalue_col]])
if (bitscore_col %in% colnames(df)) df[[bitscore_col]] <- to_num(df[[bitscore_col]])

# Normalize coverage to 0-1 if needed
if (coverage_col %in% colnames(df) && !is.na(cov_scale) && cov_scale != 1) {
  df[[coverage_col]] <- df[[coverage_col]] / cov_scale
}

n_before <- nrow(df)

# ----- Apply filters -----
df_f <- df %>%
  filter(
    !is.na(.data[[sample_col]]), .data[[sample_col]] != "",
    !is.na(.data[[pident_col]])
  )

# Family: keep unknowns but label them, to avoid dropping all if Family has NAs
df_f[[family_col]][is.na(df_f[[family_col]]) | df_f[[family_col]] == ""] <- "Unknown"

if (!is.na(min_cov)) {
  if (!(coverage_col %in% colnames(df_f))) {
    warning("coverage column '", coverage_col, "' not found; --filter-min-coverage ignored")
  } else {
    df_f <- df_f %>% filter(!is.na(.data[[coverage_col]]) & .data[[coverage_col]] >= min_cov)
  }
}

if (!is.na(min_readlen)) {
  if (!(readlen_col %in% colnames(df_f))) {
    warning("read length column '", readlen_col, "' not found; --filter-min-readlen ignored")
  } else {
    df_f <- df_f %>% filter(!is.na(.data[[readlen_col]]) & .data[[readlen_col]] >= min_readlen)
  }
}

if (!is.na(min_alnlen)) {
  if (!(alnlen_col %in% colnames(df_f))) {
    warning("alignment length column '", alnlen_col, "' not found; --filter-min-alnlen ignored")
  } else {
    df_f <- df_f %>% filter(!is.na(.data[[alnlen_col]]) & .data[[alnlen_col]] >= min_alnlen)
  }
}

if (!is.na(min_pident)) {
  df_f <- df_f %>% filter(.data[[pident_col]] >= min_pident)
}

if (!is.na(max_evalue)) {
  if (!(evalue_col %in% colnames(df_f))) {
    warning("evalue column '", evalue_col, "' not found; --filter-max-evalue ignored")
  } else {
    df_f <- df_f %>% filter(!is.na(.data[[evalue_col]]) & .data[[evalue_col]] <= max_evalue)
  }
}

if (!is.na(min_bitscore)) {
  if (!(bitscore_col %in% colnames(df_f))) {
    warning("bitscore column '", bitscore_col, "' not found; --filter-min-bitscore ignored")
  } else {
    df_f <- df_f %>% filter(!is.na(.data[[bitscore_col]]) & .data[[bitscore_col]] >= min_bitscore)
  }
}

message("Filtering summary:")
message("  Rows before: ", n_before)
message("  Rows after : ", nrow(df_f))

if (nrow(df_f) == 0) {
  stop("No rows left after filtering. Loosen thresholds and rerun.")
}

# ----- Optionally write filtered dataset -----
if (!is.na(write_filtered) && nzchar(write_filtered)) {
  wext <- tolower(tools::file_ext(write_filtered))
  if (wext %in% c("tsv", "tab", "txt")) {
    readr::write_tsv(df_f, write_filtered)
  } else {
    readr::write_csv(df_f, write_filtered)
  }
  message("Filtered dataset written to: ", write_filtered)
}

# ----- Order samples (first appearance) -----
sample_levels <- df_f %>% distinct(.data[[sample_col]]) %>% pull(1)
df_f[[sample_col]] <- factor(df_f[[sample_col]], levels = sample_levels)

# ----- Build plot -----
p <- ggplot(df_f, aes_string(x = sample_col, y = pident_col, color = family_col))

if (plot_type == "jitter") {
  p <- p + geom_jitter(width = 0.2, size = 1.4, alpha = alpha_pt)
} else if (plot_type == "box") {
  p <- p + geom_boxplot(outlier.shape = NA, alpha = 0.2) +
    geom_jitter(width = 0.2, size = 1.0, alpha = alpha_pt)
} else if (plot_type == "violin") {
  p <- p + geom_violin(trim = TRUE, alpha = 0.3) +
    geom_jitter(width = 0.2, size = 1.0, alpha = alpha_pt)
} else if (plot_type == "boxjitter") {
  p <- p + geom_boxplot(outlier.shape = NA, alpha = 0.2) +
    geom_jitter(width = 0.15, size = 1.2, alpha = alpha_pt)
} else {
  warning("Unknown plot-type '", plot_type, "'. Falling back to jitter.")
  p <- p + geom_jitter(width = 0.2, size = 1.4, alpha = alpha_pt)
}

# Subtitle with active filters (audit trail)
filters_txt <- c()
if (!is.na(min_readlen))  filters_txt <- c(filters_txt, paste0(readlen_col, "≥", min_readlen))
if (!is.na(min_alnlen))   filters_txt <- c(filters_txt, paste0(alnlen_col, "≥", min_alnlen))
if (!is.na(min_pident))   filters_txt <- c(filters_txt, paste0(pident_col, "≥", min_pident))
if (!is.na(max_evalue))   filters_txt <- c(filters_txt, paste0(evalue_col, "≤", format(max_evalue, scientific = TRUE)))
if (!is.na(min_cov))      filters_txt <- c(filters_txt, paste0(coverage_col, "≥", min_cov))
if (!is.na(min_bitscore)) filters_txt <- c(filters_txt, paste0(bitscore_col, "≥", min_bitscore))
subtitle_txt <- if (length(filters_txt) == 0) "No filters applied" else paste("Filters:", paste(filters_txt, collapse = "; "))

p <- p +
  theme_bw() +
  theme(
    axis.text.x = element_text(angle = rotate_x, hjust = 1),
    panel.grid.major.x = element_blank(),
    legend.position = "right"
  ) +
  labs(
    x = "Sample",
    y = "% Identity (pident)",
    color = "Family",
    title = "% identity (pident) by sample",
    subtitle = subtitle_txt
  ) +
  scale_y_continuous(limits = c(0, 100), oob = scales::squish)

# Color scale choice
n_fams <- dplyr::n_distinct(df_f[[family_col]])
if (n_fams <= 12) {
  p <- p + scale_color_brewer(palette = "Set1")
} else {
  p <- p + scale_color_viridis_d(option = "turbo")
}

# ----- Save plot -----
out_ext <- tolower(tools::file_ext(output))
if (out_ext %in% c("png","jpg","jpeg","tiff","bmp")) {
  ggsave(filename = output, plot = p, width = w, height = h, dpi = dpi)
} else if (out_ext %in% c("pdf","svg")) {
  ggsave(filename = output, plot = p, width = w, height = h)
} else {
  warning("Unknown output extension '", out_ext, "'. Saving as PNG to: ", output, ".")
  ggsave(filename = output, plot = p, width = w, height = h, dpi = dpi)
}

message("Plot saved to: ", output)
