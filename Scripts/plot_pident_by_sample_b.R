#!/usr/bin/env Rscript
#
# plot_pident_by_sample.R
#
# Plot % identity (pident) vs sample, colored by taxonomic family,
# with optional BLAST-quality filtering (coverage, read length, aln length, evalue, bitscore, pident).
#
# Usage example:
# Rscript plot_pident_by_sample.R \
#   --input combined_blast_combined.tsv \
#   --output pident_filtered.png \
#   --filter-min-readlen 200 --filter-min-coverage 0.5 --filter-min-pident 75 \
#   --filter-max-evalue 1e-5 --filter-min-alnlen 150 \
#   --highlight-families-file mycovirus_families.txt \
#   --write-filtered filtered_hits.tsv


# Load Required Libraries
suppressPackageStartupMessages({
  required <- c("optparse", "readr", "dplyr", "ggplot2", "stringr", "scales", "gridExtra", "tools", "patchwork")
  for (p in required) {
    if (!requireNamespace(p, quietly = TRUE)) {
      install.packages(p, repos = "https://cloud.r-project.org")
    }
  }
  lapply(required, library, character.only = TRUE)
})

# Define Command-line Arguments
option_list <- list(
  make_option(c("--input"), type = "character", default = NULL,
              help = "Input table (CSV/TSV). Required.", metavar = "character"),
  make_option(c("--output"), type = "character", default = "pident_by_sample.png",
              help = "Output plot file (png/pdf/svg). [default: %default]", metavar = "character"),
  make_option(c("--highlight-families-file"), type = "character", default = NULL,
              help = "Text file with one family per line to highlight. Required.", metavar = "character"),
  make_option(c("--filter-min-coverage"), type = "double", default = NA,
              help = "Keep hits with coverage >= value. Default: no filter.", metavar = "double"),
  make_option(c("--filter-min-readlen"), type = "integer", default = NA,
              help = "Keep hits with read/query length >= value (bp). Default: no filter.", metavar = "integer"),
  make_option(c("--filter-min-alnlen"), type = "integer", default = NA,
              help = "Keep hits with alignment length >= value (bp). Default: no filter.", metavar = "integer"),
  make_option(c("--filter-min-pident"), type = "double", default = NA,
              help = "Keep hits with pident >= value (0-100). Default: no filter.", metavar = "double"),
  make_option(c("--filter-max-evalue"), type = "double", default = NA,
              help = "Keep hits with evalue <= value. Default: no filter.", metavar = "double"),
  make_option(c("--write-filtered"), type = "character", default = NA,
              help = "Write filtered dataset to this path (CSV/TSV). Optional.", metavar = "character"),
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

# Parse Command-line Arguments
opt <- parse_args(OptionParser(option_list = option_list))
if (is.null(opt$input)) stop("ERROR: --input is required")
if (is.null(opt$`highlight-families-file`)) stop("ERROR: --highlight-families-file is required")

# Assign Arguments
input <- opt$input
output <- opt$output
highlight_file <- opt$`highlight-families-file`
min_cov <- opt$`filter-min-coverage`
min_readlen <- opt$`filter-min-readlen`
min_alnlen <- opt$`filter-min-alnlen`
min_pident <- opt$`filter-min-pident`
max_evalue <- opt$`filter-max-evalue`
write_filtered <- opt$`write-filtered`
w <- opt$width
h <- opt$height
dpi <- opt$dpi
rotate_x <- opt$`rotate-x`
alpha_pt <- opt$alpha

# Read Input File
ext <- tools::file_ext(input)
message("Reading input: ", input)
df <- tryCatch({
  if (ext %in% c("tsv", "tab", "txt")) {
    readr::read_tsv(input, na = c("", "NA"), show_col_types = FALSE)
  } else {
    readr::read_csv(input, na = c("", "NA"), show_col_types = FALSE)
  }
}, error = function(e) {
  stop("Failed to read input file: ", e$message)
})

# Apply Filters
df_filtered <- df %>%
  filter(
    !is.na(sample),
    !is.na(pident),
    if (!is.na(min_cov)) coverage >= min_cov else TRUE,
    if (!is.na(min_readlen)) length >= min_readlen else TRUE,
    if (!is.na(min_alnlen)) length >= min_alnlen else TRUE,
    if (!is.na(min_pident)) pident >= min_pident else TRUE,
    if (!is.na(max_evalue)) evalue <= max_evalue else TRUE
  )

# Write Filtered Data (Optional)
if (!is.na(write_filtered)) {
  readr::write_tsv(df_filtered, write_filtered)
  message("Filtered data written to: ", write_filtered)
}

# Read Highlight Families File
message("Reading highlight families from: ", highlight_file)
highlight_families <- readLines(highlight_file) %>%
  tolower() %>%
  unique()

# Set Highlight and Colors
df_filtered <- df_filtered %>%
  mutate(
    Family = tolower(Family),
    Highlight = ifelse(Family %in% highlight_families, "Highlight", "Other")
  )

# Summarized Table of Highlighted Families and Counts
highlighted_table <- df_filtered %>%
  filter(Highlight == "Highlight") %>%
  group_by(Family) %>%
  summarise(Read_Count = n()) %>%
  arrange(desc(Read_Count)) %>%
  mutate(Family = tools::toTitleCase(Family))  # Capitalize Family names

# Create the Table Plot with Counts
table_plot <- ggplot(highlighted_table, aes(x = 0, y = reorder(Family, Read_Count), label = paste(Family, ":", Read_Count))) +
  geom_text(hjust = 0, vjust = 0.7, size = 3) +  # Text representation of table
  coord_cartesian(clip = "off") +
  theme_void() +  # Remove all axes and grids
  labs(title = "Highlighted Families\n(Read Counts)") +
  theme(plot.title = element_text(size = 8, face = "bold", hjust = 1))

# Set Colors for Main Plot
color_palette <- c("Highlight" = "red", "Other" = "gray80")

# Subtitle with active filters for auditability
filters_txt <- c()
if (!is.na(min_readlen)) filters_txt <- c(filters_txt, paste0("readlen>=", min_readlen))
if (!is.na(min_alnlen))  filters_txt <- c(filters_txt, paste0("alnlen>=", min_alnlen))
if (!is.na(min_pident))  filters_txt <- c(filters_txt, paste0("pident>=", min_pident))
if (!is.na(max_evalue))  filters_txt <- c(filters_txt, paste0("evalue<=", format(max_evalue, scientific = TRUE)))
if (!is.na(min_cov))     filters_txt <- c(filters_txt, paste0("cov>=", min_cov))

subtitle_txt <- if (length(filters_txt) == 0) "No filters applied" else paste(filters_txt, collapse = "; ")

# Add Description as Plot Caption
description_text <- paste(
  "The SRA samples are derived from the study on Epichloë endophytes:",
  "'Epichloë seed transmission efficiency is influenced by plant defense response mechanisms'.",
  "It shows the presence of mycovirus family reads detected in Epichloë metatranscriptomes.",
  "Data suggests vertical transmission mechanisms interact with plant defenses,",
  "as described by Zhang et al. (2021).",
  sep = "\n"
)


# Create Main Plot
main_plot <- ggplot(df_filtered, aes(x = sample, y = pident, color = Highlight)) +
  geom_jitter(alpha = alpha_pt) +
  scale_color_manual(values = color_palette) +
  theme_bw() +
  theme(
    axis.text.x = element_text(angle = rotate_x, hjust = 1),
    legend.position = "right"
  ) +
  labs(
    x = "Sample",
    y = "% Identity (pident)",
    title = "Mycovirus Families Read Detection in Epichloë Metatranscriptomes",
    subtitle = subtitle_txt,
    color = "mycovirus family",
    caption = description_text  # Add description below the plot as a caption
  ) +
  scale_y_continuous(limits = c(0, 100), oob = scales::squish)

# Combine Table with Plot
combined <- main_plot + table_plot + plot_layout(widths = c(2.7, 1.3))

# Save the Combined Plot
ggsave(filename = output, plot = combined, width = w, height = h, dpi = dpi)
message("Plot saved to: ", output)