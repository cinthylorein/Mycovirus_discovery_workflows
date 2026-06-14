#!/usr/bin/env Rscript
#
# plot_pident_by_sample.R
#
# Plot % identity (y) vs RNA sample (x), colored by taxonomic family.
# Input: summary/combined CSV produced by Summary_table.R
#
# Publication-tuned version:
# - larger text sizes
# - larger points
# - caption with safe margins
#

suppressPackageStartupMessages({
  required <- c("optparse", "readr", "dplyr", "ggplot2", "forcats", "stringr", "scales", "viridis")
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
  library(viridis)
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
  make_option(c("--filter-min-readlen"), type = "integer", default = NA,
              help = "Filter reads/hits with query/read length >= value. Default: no filtering", metavar = "integer"),
  make_option(c("--filter-min-alnlen"), type = "integer", default = NA,
              help = "Filter hits with alignment length >= value. Default: no filtering", metavar = "integer"),
  make_option(c("--filter-min-pident"), type = "double", default = NA,
              help = "Filter hits with pident >= value. Default: no filtering", metavar = "double"),
  make_option(c("--filter-max-evalue"), type = "double", default = NA,
              help = "Filter hits with evalue <= value. Default: no filtering", metavar = "double"),
  make_option(c("--filter-min-bitscore"), type = "double", default = NA,
              help = "Filter hits with bitscore >= value. Default: no filtering", metavar = "double"),

  make_option(c("--write-filtered"), type = "character", default = NA,
              help = "Write filtered dataset to this CSV path (optional)", metavar = "character"),

  make_option(c("--max-families"), type = "integer", default = 20,
              help = "Keep top N families and group the rest into 'Other' [default: %default]", metavar = "integer"),

  make_option(c("--width"), type = "double", default = 10,
              help = "Base plot width in inches [default: %default]", metavar = "double"),
  make_option(c("--height"), type = "double", default = 6,
              help = "Base plot height in inches [default: %default]", metavar = "double"),
  make_option(c("--dpi"), type = "integer", default = 300,
              help = "DPI for raster formats [default: %default]", metavar = "integer"),
  make_option(c("--rotate-x"), type = "integer", default = 45,
              help = "Rotation of x-axis labels in degrees [default: %default]", metavar = "integer"),
  make_option(c("--alpha"), type = "double", default = 0.6,
              help = "Alpha/transparency for points [default: %default]", metavar = "double")
)

opt <- parse_args(OptionParser(option_list = option_list))
if (is.null(opt$input)) stop("ERROR: --input is required")

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
max_families <- opt$`max-families`

w <- opt$width
h <- opt$height
dpi <- opt$dpi
rotate_x <- opt$`rotate-x`
alpha_pt <- opt$alpha

if (!file.exists(input)) stop("Input file does not exist: ", input)
df <- readr::read_csv(input, show_col_types = FALSE)

find_col <- function(df_cols, desired) {
  if (desired %in% df_cols) return(desired)
  low <- tolower(df_cols); dlow <- tolower(desired)
  idx <- which(low == dlow); if (length(idx) == 1) return(df_cols[idx])

  if (dlow %in% c("pident","percentidentity","percent_id","identity")) {
    for (c in c("pident","perc_identity","percent_identity","identity","pct_identity")) {
      i <- which(low == tolower(c)); if (length(i) == 1) return(df_cols[i])
    }
  }
  if (dlow == "coverage") {
    for (c in c("coverage","qcov","qcovs","qcovhsp","query_coverage","qcovus")) {
      i <- which(low == tolower(c)); if (length(i) == 1) return(df_cols[i])
    }
  }
  if (dlow %in% c("evalue","e-value")) {
    for (c in c("evalue","e-value","e_val","expect")) {
      i <- which(low == tolower(c)); if (length(i) == 1) return(df_cols[i])
    }
  }
  if (dlow %in% c("bitscore","bit_score")) {
    for (c in c("bitscore","bit_score","bit-score")) {
      i <- which(low == tolower(c)); if (length(i) == 1) return(df_cols[i])
    }
  }
  if (dlow %in% c("length","alnlen","alignment_length")) {
    for (c in c("length","alnlen","alignment_length","align_len","hsp_length")) {
      i <- which(low == tolower(c)); if (length(i) == 1) return(df_cols[i])
    }
  }
  if (dlow %in% c("qlen","query_length","readlen","read_length")) {
    for (c in c("qlen","query_length","q_len","readlen","read_length","querylen")) {
      i <- which(low == tolower(c)); if (length(i) == 1) return(df_cols[i])
    }
  }
  NA_character_
}

cols <- colnames(df)
sample_col <- find_col(cols, sample_col_candidate)
pident_col <- find_col(cols, pident_col_candidate)
family_col <- find_col(cols, family_col_candidate)

if (is.na(sample_col)) stop("Could not find sample column.")
if (is.na(pident_col)) stop("Could not find pident column.")
if (is.na(family_col)) { df$Family_for_plot <- "Unknown"; family_col <- "Family_for_plot" }

cov_col <- find_col(cols, "coverage")
evalue_col <- find_col(cols, "evalue")
bitscore_col <- find_col(cols, "bitscore")
alnlen_col <- find_col(cols, "length")
readlen_col <- find_col(cols, "qlen")

df <- df %>%
  mutate(
    !!sample_col := as.character(.data[[sample_col]]),
    !!pident_col := as.numeric(.data[[pident_col]]),
    !!family_col := as.character(.data[[family_col]])
  )

if (!is.na(cov_col)) df[[cov_col]] <- as.numeric(df[[cov_col]])
if (!is.na(evalue_col)) df[[evalue_col]] <- as.numeric(df[[evalue_col]])
if (!is.na(bitscore_col)) df[[bitscore_col]] <- as.numeric(df[[bitscore_col]])
if (!is.na(alnlen_col)) df[[alnlen_col]] <- as.numeric(df[[alnlen_col]])
if (!is.na(readlen_col)) df[[readlen_col]] <- as.numeric(df[[readlen_col]])

if (!is.na(min_cov) && !is.na(cov_col)) df <- df %>% filter(.data[[cov_col]] >= min_cov)
if (!is.na(min_readlen) && !is.na(readlen_col)) df <- df %>% filter(.data[[readlen_col]] >= min_readlen)
if (!is.na(min_alnlen) && !is.na(alnlen_col)) df <- df %>% filter(.data[[alnlen_col]] >= min_alnlen)
if (!is.na(min_pident)) df <- df %>% filter(.data[[pident_col]] >= min_pident)
if (!is.na(max_evalue) && !is.na(evalue_col)) df <- df %>% filter(.data[[evalue_col]] <= max_evalue)
if (!is.na(min_bitscore) && !is.na(bitscore_col)) df <- df %>% filter(.data[[bitscore_col]] >= min_bitscore)

df[[family_col]][is.na(df[[family_col]]) | df[[family_col]] == ""] <- "Unknown"
if (!is.na(max_families) && max_families > 0) {
  top_fams <- df %>% count(.data[[family_col]], sort = TRUE) %>% slice_head(n = max_families) %>% pull(.data[[family_col]])
  df[[family_col]] <- ifelse(df[[family_col]] %in% top_fams, df[[family_col]], "Other")
}
if (!is.na(write_filtered) && nzchar(write_filtered)) readr::write_csv(df, write_filtered)

df[[sample_col]] <- factor(df[[sample_col]], levels = df %>% distinct(.data[[sample_col]]) %>% pull(1))
df[[family_col]] <- factor(df[[family_col]], levels = df %>% count(.data[[family_col]], sort = TRUE) %>% pull(.data[[family_col]]))

n_fams <- n_distinct(df[[family_col]])
auto_width <- ifelse(n_fams > 20, max(w, 16), ifelse(n_fams > 15, max(w, 14), ifelse(n_fams > 10, max(w, 12), w)))
auto_height <- ifelse(n_fams > 20, max(h, 9), ifelse(n_fams > 15, max(h, 8), ifelse(n_fams > 10, max(h, 7), h)))
legend_ncol <- ifelse(n_fams > 20, 4, ifelse(n_fams > 15, 3, ifelse(n_fams > 10, 2, 1)))

p <- ggplot(df, aes(x = .data[[sample_col]], y = .data[[pident_col]], color = .data[[family_col]]))
if (plot_type == "box") {
  p <- p + geom_boxplot(outlier.shape = NA, alpha = 0.2) + geom_jitter(width = 0.2, size = 1.6, alpha = alpha_pt)
} else if (plot_type == "violin") {
  p <- p + geom_violin(trim = TRUE, alpha = 0.3) + geom_jitter(width = 0.2, size = 1.6, alpha = alpha_pt)
} else if (plot_type == "boxjitter") {
  p <- p + geom_boxplot(outlier.shape = NA, alpha = 0.2) + geom_jitter(width = 0.15, size = 1.8, alpha = alpha_pt)
} else {
  p <- p + geom_jitter(width = 0.2, size = 2.0, alpha = alpha_pt)
}

caption_txt <- paste(
  paste0("Legend shows the top ", max_families, " viral families"),
  "ranked by hit count in the plotted dataset.",
  "Families outside the top set were grouped",
  "as 'Other'; no extra family-level filtering applied.",
  sep = "\n"
)

pub_theme <- theme_bw(base_size = 14) +
  theme(
    plot.title = element_text(size = 18, face = "bold"),
    plot.subtitle = element_text(size = 13),
    axis.title = element_text(size = 15),
    axis.text = element_text(size = 12),
    axis.text.x = element_text(angle = rotate_x, hjust = 1, size = 11),
    legend.title = element_text(size = 14, face = "bold"),
    legend.text = element_text(size = 12),
    plot.caption = element_text(size = 11, hjust = 0, lineheight = 1.1),
    plot.margin = margin(t = 12, r = 12, b = 50, l = 12),
    panel.grid.major.x = element_blank()
  )

p <- p +
  pub_theme +
  guides(color = guide_legend(ncol = legend_ncol, byrow = TRUE)) +
  labs(
    x = "Sample",
    y = "% Identity (pident)",
    color = family_col,
    title = "% identity (pident) by sample",
    caption = caption_txt
  ) +
  scale_y_continuous(limits = c(0, 100), oob = scales::squish)

if (n_fams <= 12) p <- p + scale_color_brewer(palette = "Set1") else p <- p + scale_color_viridis_d(option = "turbo")
ggsave(filename = output, plot = p, width = auto_width, height = auto_height, dpi = dpi)
message("Plot saved to: ", output)