#!/usr/bin/env Rscript
#
# plot_pident_by_sample.R
#
# Plot % pident (y) vs RNA sample (x), colored by taxonomic family.
# Input: summary/combined CSV produced by Pipeline_A_scripts/Summary_table.R
#
# Usage examples:
# Rscript Pipeline_A_scripts/plot_pident_by_sample.R --input combined_blast_combined.csv --output pident_by_sample.png
# Rscript Pipeline_A_scripts/plot_pident_by_sample.R --input combined_blast_uniqueIDs.csv --output pident_by_sample.pdf --plot-type boxjitter --filter-min-coverage 0.1
#
# Options:
# --input            Path to input CSV (required)
# --output           Path to output plot file (png/pdf/svg). Default: pident_by_sample.png
# --plot-type        one of: "jitter" (default), "box", "violin", "boxjitter"
# --sample-col       name of sample column (default: "sample")
# --pident-col       name of percent identity column (default: "pident")
# --family-col       name of family column for coloring (default: "Family")
# --filter-min-coverage   optionally filter hits with coverage >= value (0-1). Default: NA (no filter)
# --width            width in inches (default 10)
# --height           height in inches (default 6)
# --dpi              dpi for raster outputs (default 300)
# --rotate-x         rotate x labels degrees (default 45)
# --alpha            point alpha for jitter (default 0.6)
#
# The script attempts to be tolerant of common column name variants (different cases).
#

suppressPackageStartupMessages({
  required <- c("optparse", "readr", "dplyr", "ggplot2", "forcats", "stringr")
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
  make_option(c("--filter-min-coverage"), type = "double", default = NA,
              help = "Filter hits with coverage >= value (0-1). Default: no filtering", metavar = "double"),
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
sample_col_candidate <- opt$`sample-col`
pident_col_candidate <- opt$`pident-col`
family_col_candidate <- opt$`family-col`
min_cov <- opt$`filter-min-coverage`
w <- opt$width
h <- opt$height
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
  # try exact
  if (desired %in% df_cols) return(desired)
  # try lower-case match
  low <- tolower(df_cols)
  dlow <- tolower(desired)
  idx <- which(low == dlow)
  if (length(idx) == 1) return(df_cols[idx])
  # try some common variants (pident -> pid, identity; Family -> family, tax_family)
  variants <- c(desired,
                paste0(tolower(desired)),
                gsub("_", "", tolower(desired)))
  idx2 <- which(low %in% tolower(variants))
  if (length(idx2) >= 1) return(df_cols[idx2[1]])
  # more heuristics for pident
  if (dlow %in% c("pident","percentidentity","percent_id","identity")) {
    candidates <- c("pident","percent_identity","identity","perc_identity")
    for (c in candidates) {
      idx3 <- which(low == tolower(c))
      if (length(idx3)==1) return(df_cols[idx3])
    }
  }
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

# coerce columns
df <- df %>%
  mutate(
    !!sample_col := as.character(.data[[sample_col]]),
    !!pident_col := as.numeric(.data[[pident_col]]),
    !!family_col := as.character(.data[[family_col]])
  )

# Optionally filter by coverage
if (!is.na(min_cov)) {
  cov_col <- find_col(cols, "coverage")
  if (is.na(cov_col)) {
    warning("coverage column not found; --filter-min-coverage ignored")
  } else {
    df <- df %>% filter(as.numeric(.data[[cov_col]]) >= min_cov)
    message("Filtered rows with coverage >= ", min_cov, "; remaining rows: ", nrow(df))
  }
}

# Replace NA family with "Unknown"
df[[family_col]][is.na(df[[family_col]]) | df[[family_col]] == ""] <- "Unknown"

# Order samples by name or by median pident (optional). We'll order by sample name as factor by first appearance
sample_levels <- df %>% distinct(.data[[sample_col]]) %>% pull(1)
df[[sample_col]] <- factor(df[[sample_col]], levels = sample_levels)

# Build ggplot
p <- ggplot(df, aes_string(x = sample_col, y = pident_col, color = family_col))

# Choose geometry
if (plot_type == "jitter") {
  p <- p + geom_jitter(width = 0.2, size = 1.5, alpha = alpha_pt)
} else if (plot_type == "box") {
  p <- p + geom_boxplot(outlier.shape = NA, alpha = 0.2) + geom_jitter(width = 0.2, size = 1, alpha = alpha_pt)
} else if (plot_type == "violin") {
  p <- p + geom_violin(trim = TRUE, alpha = 0.3) + geom_jitter(width = 0.2, size = 1, alpha = alpha_pt)
} else if (plot_type == "boxjitter") {
  p <- p + geom_boxplot(outlier.shape = NA, alpha = 0.2) + geom_jitter(width = 0.15, size = 1.2, alpha = alpha_pt)
} else {
  warning("Unknown plot-type '", plot_type, "'; falling back to jitter.")
  p <- p + geom_jitter(width = 0.2, size = 1.5, alpha = alpha_pt)
}

p <- p +
  theme_bw() +
  theme(
    axis.text.x = element_text(angle = rotate_x, hjust = ifelse(rotate_x == 90, 1, 1)),
    panel.grid.major.x = element_blank(),
    legend.position = "right"
  ) +
  labs(
    x = "Sample",
    y = "% Identity (pident)",
    color = family_col,
    title = paste0("% identity (pident) by sample"),
    subtitle = paste0("Colored by ", family_col)
  ) +
  scale_y_continuous(limits = c(0, 100), oob = scales::squish)

# If too many families, use a discrete color scale that can handle many values
n_fams <- n_distinct(df[[family_col]])
if (n_fams <= 12) {
  p <- p + scale_color_brewer(palette = "Set1")
} else {
  p <- p + scale_color_viridis_d(option = "turbo")
}

# Save output depending on extension
out_ext <- tolower(tools::file_ext(output))
if (out_ext %in% c("png","jpg","jpeg","tiff","bmp")) {
  ggsave(filename = output, plot = p, width = w, height = h, dpi = dpi)
} else if (out_ext %in% c("pdf","svg")) {
  ggsave(filename = output, plot = p, width = w, height = h, dpi = dpi)
} else {
  # default to png
  warning("Unknown output extension '", out_ext, "'. Saving as PNG to: ", output, ".")
  ggsave(filename = output, plot = p, width = w, height = h, dpi = dpi)
}

message("Plot saved to: ", output)