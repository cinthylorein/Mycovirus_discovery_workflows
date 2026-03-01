#!/usr/bin/env Rscript
#
# plot_pident_by_sample.R
#
# Plot % pident (y) vs RNA sample (x), colored by taxonomic family.
# Input: summary/combined CSV produced by Pipeline_A_scripts/Summary_table.R
#
# Adds filtering by: coverage, read length, alignment length, pident, evalue, bitscore.
#

suppressPackageStartupMessages({
  required <- c("optparse", "readr", "dplyr", "ggplot2", "forcats", "stringr", "scales")
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
})

option_list <- list(
  make_option(c("--input"), type = "character", default = NULL,
              help = "Input CSV (summary table) (required)", metavar = "character"),
  make_option(c("--output"), type = "character", default = "pident_by_sample.png",
              help = "Output plot file (png/pdf/svg) [default: %default]", metavar = "character"),
  make_option(c("--plot-type"), type = "character", default = "jitter",
              help = "Plot type: jitter, box, violin, boxjitter [default: %default]", metavar = "character"),
  make_option(c("--sample-col"), type = "character", default = "sample",
              help = "Sample column name [default: %default]", metavar = "character"),
  make_option(c("--pident-col"), type = "character", default = "pident",
              help = "Percent identity column name [default: %default]", metavar = "character"),
  make_option(c("--family-col"), type = "character", default = "Family",
              help = "Family column name for coloring [default: %default]", metavar = "character"),

  # Existing
  make_option(c("--filter-min-coverage"), type = "double", default = NA,
              help = "Filter hits with coverage >= value (0-1). Default: no filtering", metavar = "double"),

  # NEW FILTERS
  make_option(c("--filter-min-readlen"), type = "integer", default = NA,
              help = "Filter reads/hits with query/read length >= value (bp). Default: no filtering", metavar = "integer"),
  make_option(c("--filter-min-alnlen"), type = "integer", default = NA,
              help = "Filter hits with alignment length >= value (bp/aa). Default: no filtering", metavar = "integer"),
  make_option(c("--filter-min-pident"), type = "double", default = NA,
              help = "Filter hits with pident >= value (0-100). Default: no filtering", metavar = "double"),
  make_option(c("--filter-max-evalue"), type = "double", default = NA,
              help = "Filter hits with evalue <= value. Default: no filtering", metavar = "double"),
  make_option(c("--filter-min-bitscore"), type = "double", default = NA,
              help = "Filter hits with bitscore >= value. Default: no filtering", metavar = "double"),

  # Output filtered table (optional)
  make_option(c("--write-filtered"), type = "character", default = NA,
              help = "Write filtered dataset to this CSV path (optional)", metavar = "character"),

  make_option(c("--width"), type = "double", default = 10,
              help = "Plot width in inches [default: %default]", metavar = "double"),
  make_option(c("--height"), type = "double", default = 6,
              help = "Plot height in inches [default: %default]", metavar = "character"),
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
sample_col_candidate <- opt$`sample-col`
pident_col_candidate <- opt$`pident-col`
family_col_candidate <- opt$`family-col`

min_cov <- opt$`filter-min-coverage`
min_readlen <- opt$`filter-min-readlen`
min_alnlen <- opt$`filter-min-alnlen`
min_pident <- opt$`filter-min-pident`
max_evalue <- opt$`filter-max-evalue`
min_bitscore <- opt$`filter-min-bitscore`
write_filtered <- opt$`write-filtered`

w <- opt$width
h <- as.double(opt$height)
dpi <- opt$dpi
rotate_x <- opt$`rotate-x`
alpha_pt <- opt$alpha

if (!file.exists(input)) stop("Input file does not exist: ", input)

message("Reading input: ", input)
df <- tryCatch({
  readr::read_csv(input, show_col_types = FALSE)
}, error = function(e) {
  stop("Failed to read input CSV: ", e$message)
})

# Helper to find column ignoring case and common variants
find_col <- function(df_cols, desired) {
  if (desired %in% df_cols) return(desired)
  low <- tolower(df_cols)
  dlow <- tolower(desired)
  idx <- which(low == dlow)
  if (length(idx) == 1) return(df_cols[idx])

  # Heuristics for common BLAST fields
  if (dlow %in% c("pident","percentidentity","percent_id","identity")) {
    candidates <- c("pident","perc_identity","percent_identity","identity","pct_identity")
    for (c in candidates) {
      idx3 <- which(low == tolower(c))
      if (length(idx3)==1) return(df_cols[idx3])
    }
  }
  if (dlow == "coverage") {
    candidates <- c("coverage","qcov","qcovs","qcovhsp","query_coverage","qcovus")
    for (c in candidates) {
      idx3 <- which(low == tolower(c))
      if (length(idx3)==1) return(df_cols[idx3])
    }
  }
  if (dlow %in% c("evalue","e-value")) {
    candidates <- c("evalue","e-value","e_val","expect")
    for (c in candidates) {
      idx3 <- which(low == tolower(c))
      if (length(idx3)==1) return(df_cols[idx3])
    }
  }
  if (dlow %in% c("bitscore","bit_score")) {
    candidates <- c("bitscore","bit_score","bit-score")
    for (c in candidates) {
      idx3 <- which(low == tolower(c))
      if (length(idx3)==1) return(df_cols[idx3])
    }
  }
  if (dlow %in% c("length","alnlen","alignment_length")) {
    candidates <- c("length","alnlen","alignment_length","align_len","hsp_length")
    for (c in candidates) {
      idx3 <- which(low == tolower(c))
      if (length(idx3)==1) return(df_cols[idx3])
    }
  }
  if (dlow %in% c("qlen","query_length","readlen","read_length")) {
    candidates <- c("qlen","query_length","q_len","readlen","read_length","querylen")
    for (c in candidates) {
      idx3 <- which(low == tolower(c))
      if (length(idx3)==1) return(df_cols[idx3])
    }
  }

  # fallback variants
  variants <- c(desired, tolower(desired), gsub("_","",tolower(desired)))
  idx2 <- which(low %in% tolower(variants))
  if (length(idx2) >= 1) return(df_cols[idx2[1]])

  return(NA_character_)
}

cols <- colnames(df)
sample_col <- find_col(cols, sample_col_candidate)
pident_col <- find_col(cols, pident_col_candidate)
family_col <- find_col(cols, family_col_candidate)

if (is.na(sample_col)) stop("Could not find sample column (tried '", sample_col_candidate, "'). Available columns: ", paste(cols, collapse = ", "))
if (is.na(pident_col)) stop("Could not find pident column (tried '", pident_col_candidate, "'). Available columns: ", paste(cols, collapse = ", "))
if (is.na(family_col)) {
  warning("Family column not found (tried '", family_col_candidate, "'). Coloring will use 'Unknown'.")
  df$Family_for_plot <- "Unknown"
  family_col <- "Family_for_plot"
}

# Identify optional columns for filtering
cov_col <- find_col(cols, "coverage")
evalue_col <- find_col(cols, "evalue")
bitscore_col <- find_col(cols, "bitscore")
alnlen_col <- find_col(cols, "length")
readlen_col <- find_col(cols, "qlen")

# Coerce required cols
df <- df %>%
  mutate(
    !!sample_col := as.character(.data[[sample_col]]),
    !!pident_col := as.numeric(.data[[pident_col]]),
    !!family_col := as.character(.data[[family_col]])
  )

# Coerce optional numeric cols when present
if (!is.na(cov_col)) df[[cov_col]] <- as.numeric(df[[cov_col]])
if (!is.na(evalue_col)) df[[evalue_col]] <- as.numeric(df[[evalue_col]])
if (!is.na(bitscore_col)) df[[bitscore_col]] <- as.numeric(df[[bitscore_col]])
if (!is.na(alnlen_col)) df[[alnlen_col]] <- as.numeric(df[[alnlen_col]])
if (!is.na(readlen_col)) df[[readlen_col]] <- as.numeric(df[[readlen_col]])

n_before <- nrow(df)

# Apply filters (only if option set AND column exists)
if (!is.na(min_cov)) {
  if (is.na(cov_col)) warning("coverage column not found; --filter-min-coverage ignored")
  else df <- df %>% filter(.data[[cov_col]] >= min_cov)
}
if (!is.na(min_readlen)) {
  if (is.na(readlen_col)) warning("read/query length column not found (qlen/read_length); --filter-min-readlen ignored")
  else df <- df %>% filter(.data[[readlen_col]] >= min_readlen)
}
if (!is.na(min_alnlen)) {
  if (is.na(alnlen_col)) warning("alignment length column not found; --filter-min-alnlen ignored")
  else df <- df %>% filter(.data[[alnlen_col]] >= min_alnlen)
}
if (!is.na(min_pident)) {
  df <- df %>% filter(.data[[pident_col]] >= min_pident)
}
if (!is.na(max_evalue)) {
  if (is.na(evalue_col)) warning("evalue column not found; --filter-max-evalue ignored")
  else df <- df %>% filter(.data[[evalue_col]] <= max_evalue)
}
if (!is.na(min_bitscore)) {
  if (is.na(bitscore_col)) warning("bitscore column not found; --filter-min-bitscore ignored")
  else df <- df %>% filter(.data[[bitscore_col]] >= min_bitscore)
}

message("Filtering summary:")
message("  Rows before: ", n_before)
message("  Rows after : ", nrow(df))

# Optional: write filtered table
if (!is.na(write_filtered) && nzchar(write_filtered)) {
  readr::write_csv(df, write_filtered)
  message("Filtered table written to: ", write_filtered)
}

# Replace NA/empty family with "Unknown"
df[[family_col]][is.na(df[[family_col]]) | df[[family_col]] == ""] <- "Unknown"

# Order samples by first appearance
sample_levels <- df %>% distinct(.data[[sample_col]]) %>% pull(1)
df[[sample_col]] <- factor(df[[sample_col]], levels = sample_levels)

# Build ggplot
p <- ggplot(df, aes_string(x = sample_col, y = pident_col, color = family_col))

if (plot_type == "jitter") {
  p <- p + geom_jitter(width = 0.2, size = 1.5, alpha = alpha_pt)
} else if (plot_type == "box") {
  p <- p + geom_boxplot(outlier.shape = NA, alpha = 0.2) +
    geom_jitter(width = 0.2, size = 1, alpha = alpha_pt)
} else if (plot_type == "violin") {
  p <- p + geom_violin(trim = TRUE, alpha = 0.3) +
    geom_jitter(width = 0.2, size = 1, alpha = alpha_pt)
} else if (plot_type == "boxjitter") {
  p <- p + geom_boxplot(outlier.shape = NA, alpha = 0.2) +
    geom_jitter(width = 0.15, size = 1.2, alpha = alpha_pt)
} else {
  warning("Unknown plot-type '", plot_type, "'; falling back to jitter.")
  p <- p + geom_jitter(width = 0.2, size = 1.5, alpha = alpha_pt)
}

# Subtitle with active filters for auditability
filters_txt <- c()
if (!is.na(min_readlen)) filters_txt <- c(filters_txt, paste0("readlen>=", min_readlen))
if (!is.na(min_alnlen))  filters_txt <- c(filters_txt, paste0("alnlen>=", min_alnlen))
if (!is.na(min_pident))  filters_txt <- c(filters_txt, paste0("pident>=", min_pident))
if (!is.na(max_evalue))  filters_txt <- c(filters_txt, paste0("evalue<=", format(max_evalue, scientific = TRUE)))
if (!is.na(min_cov))     filters_txt <- c(filters_txt, paste0("cov>=", min_cov))
if (!is.na(min_bitscore))filters_txt <- c(filters_txt, paste0("bitscore>=", min_bitscore))
subtitle_txt <- if (length(filters_txt) == 0) "No filters applied" else paste(filters_txt, collapse = "; ")

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
    color = family_col,
    title = "% identity (pident) by sample",
    subtitle = subtitle_txt
  ) +
  scale_y_continuous(limits = c(0, 100), oob = scales::squish)

# Color scale
n_fams <- n_distinct(df[[family_col]])
if (n_fams <= 12) {
  p <- p + scale_color_brewer(palette = "Set1")
} else {
  p <- p + scale_color_viridis_d(option = "turbo")
}

# Save
out_ext <- tolower(tools::file_ext(output))
if (out_ext %in% c("png","jpg","jpeg","tiff","bmp")) {
  ggsave(filename = output, plot = p, width = w, height = h, dpi = dpi)
} else if (out_ext %in% c("pdf","svg")) {
  ggsave(filename = output, plot = p, width = w, height = h, dpi = dpi)
} else {
  warning("Unknown output extension '", out_ext, "'. Saving as PNG to: ", output, ".")
  ggsave(filename = output, plot = p, width = w, height = h, dpi = dpi)
}

message("Plot saved to: ", output)
