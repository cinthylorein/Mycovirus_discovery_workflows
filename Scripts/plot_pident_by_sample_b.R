#!/usr/bin/env Rscript
#
# plot_pident_by_sample_b.R
#
# Plot % identity (pident) vs sample, colored by taxonomic family,
# with optional filtering on coverage, query/read length, alignment length,
# percent identity, and e-value. Selected families are highlighted from a text file.

suppressPackageStartupMessages({
  required <- c("optparse", "readr", "dplyr", "ggplot2", "stringr", "scales", "tools", "patchwork")
  for (p in required) {
    if (!requireNamespace(p, quietly = TRUE)) {
      install.packages(p, repos = "https://cloud.r-project.org")
    }
  }
  invisible(lapply(required, library, character.only = TRUE))
})

option_list <- list(
  make_option(c("--input"), type = "character", default = NULL,
              help = "Input table (CSV/TSV). Required.", metavar = "character"),
  make_option(c("--output"), type = "character", default = "pident_by_sample.png",
              help = "Output plot file (png/pdf/svg). [default: %default]", metavar = "character"),
  make_option(c("--highlight-families-file"), type = "character", default = NULL,
              help = "Text file with one family per line to highlight. Required.", metavar = "character"),
  make_option(c("--filter-min-coverage"), type = "double", default = NA,
              help = "Keep hits with coverage >= value. Default: no filter.", metavar = "double"),
  make_option(c("--filter-min-readlen"), type = "double", default = NA,
              help = "Keep hits with query/read length >= value. Uses qlen when available; otherwise falls back to length.", metavar = "double"),
  make_option(c("--filter-min-alnlen"), type = "double", default = NA,
              help = "Keep hits with alignment length >= value. Uses length column.", metavar = "double"),
  make_option(c("--filter-min-pident"), type = "double", default = NA,
              help = "Keep hits with pident >= value (0-100). Default: no filter.", metavar = "double"),
  make_option(c("--filter-max-evalue"), type = "double", default = NA,
              help = "Keep hits with evalue <= value. Default: no filter.", metavar = "double"),
  make_option(c("--write-filtered"), type = "character", default = NA,
              help = "Write filtered dataset to this path (TSV). Optional.", metavar = "character"),
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

if (is.null(opt$input)) stop("ERROR: --input is required")
if (is.null(opt$`highlight-families-file`)) stop("ERROR: --highlight-families-file is required")

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

message("Reading input: ", input)
ext <- tools::file_ext(input)

df <- tryCatch({
  if (ext %in% c("tsv", "tab", "txt")) {
    readr::read_tsv(input, na = c("", "NA"), show_col_types = FALSE)
  } else {
    readr::read_csv(input, na = c("", "NA"), show_col_types = FALSE)
  }
}, error = function(e) {
  stop("Failed to read input file: ", e$message)
})

message("Input rows: ", nrow(df))
message("Input columns: ", paste(colnames(df), collapse = ", "))

required_cols <- c("sample", "pident", "Family", "length", "evalue", "coverage")
missing_cols <- setdiff(required_cols, colnames(df))
if (length(missing_cols) > 0) {
  stop("Missing required columns in input: ", paste(missing_cols, collapse = ", "))
}

query_len_col <- if ("qlen" %in% colnames(df)) "qlen" else if ("length" %in% colnames(df)) "length" else NA_character_
aln_len_col <- if ("length" %in% colnames(df)) "length" else NA_character_

message("Using query/read length column: ", query_len_col)
message("Using alignment length column: ", aln_len_col)

df_filtered <- df %>%
  dplyr::filter(
    !is.na(sample),
    !is.na(pident),
    !is.na(Family),
    if (!is.na(min_cov)) coverage >= min_cov else TRUE,
    if (!is.na(min_readlen) && !is.na(query_len_col)) .data[[query_len_col]] >= min_readlen else TRUE,
    if (!is.na(min_alnlen)  && !is.na(aln_len_col))   .data[[aln_len_col]] >= min_alnlen else TRUE,
    if (!is.na(min_pident)) pident >= min_pident else TRUE,
    if (!is.na(max_evalue)) evalue <= max_evalue else TRUE
  )

message("Filtering summary:")
message("  Rows before: ", nrow(df))
message("  Rows after : ", nrow(df_filtered))

if (!is.na(write_filtered)) {
  readr::write_tsv(df_filtered, write_filtered)
  message("Filtered data written to: ", write_filtered)
}

if (nrow(df_filtered) == 0) {
  message("No rows remain after filtering; writing placeholder plot.")

  filters_txt <- c()
  if (!is.na(min_readlen)) filters_txt <- c(filters_txt, paste0("readlen>=", min_readlen))
  if (!is.na(min_alnlen))  filters_txt <- c(filters_txt, paste0("alnlen>=", min_alnlen))
  if (!is.na(min_pident))  filters_txt <- c(filters_txt, paste0("pident>=", min_pident))
  if (!is.na(max_evalue))  filters_txt <- c(filters_txt, paste0("evalue<=", format(max_evalue, scientific = TRUE)))
  if (!is.na(min_cov))     filters_txt <- c(filters_txt, paste0("cov>=", min_cov))

  subtitle_txt <- if (length(filters_txt) == 0) {
    "No filters applied"
  } else {
    paste(filters_txt, collapse = "; ")
  }

  caption_text <- paste(
  "Mycoviral diversity was characterized from metatranscriptome",
  "samples associated with soil communities.",
  "Displayed hits passed filters for read length, alignment length,",
  "percent identity, coverage, and e-value.",
  sep = "\n"
)

empty_plot <- ggplot() +
  annotate("text", x = 1, y = 1, label = "No hits passed the selected filters", size = 6) +
  xlim(0, 2) +
  ylim(0, 2) +
  theme_void() +
  labs(
    title = "Mycovirus Families Read Detection in Metatranscriptomes",
    subtitle = subtitle_txt,
    caption = caption_text
  ) +
  theme(
    plot.caption = element_text(hjust = 0, size = 9, lineheight = 1.05),
    plot.margin = margin(t = 10, r = 10, b = 45, l = 10)
  )

  ggsave(filename = output, plot = empty_plot, width = w, height = h, dpi = dpi)
  message("Placeholder plot saved to: ", output)
  quit(save = "no", status = 0)
}

message("Reading highlight families from: ", highlight_file)
highlight_families <- readLines(highlight_file, warn = FALSE) %>%
  trimws() %>%
  .[nzchar(.)] %>%
  tolower() %>%
  unique()

message("Number of highlight families requested: ", length(highlight_families))

df_filtered <- df_filtered %>%
  dplyr::mutate(
    Family = tolower(as.character(Family)),
    Highlight = ifelse(Family %in% highlight_families, "Highlight", "Other")
  )

message("Example families in filtered data:")
print(utils::head(sort(unique(df_filtered$Family)), 20))

highlighted_table <- df_filtered %>%
  dplyr::filter(Highlight == "Highlight") %>%
  dplyr::group_by(Family) %>%
  dplyr::summarise(Read_Count = dplyr::n(), .groups = "drop") %>%
  dplyr::arrange(desc(Read_Count)) %>%
  dplyr::mutate(Family = tools::toTitleCase(Family))

message("Number of highlighted families found in filtered data: ", nrow(highlighted_table))

if (nrow(highlighted_table) > 0) {
  table_plot <- ggplot(
    highlighted_table,
    aes(x = 0, y = reorder(Family, Read_Count), label = paste(Family, ":", Read_Count))
  ) +
    geom_text(hjust = 0, vjust = 0.7, size = 3) +
    coord_cartesian(clip = "off") +
    theme_void() +
    labs(title = "Highlighted Families\n(Read Counts)") +
    theme(plot.title = element_text(size = 8, face = "bold", hjust = 1))
} else {
  table_plot <- ggplot() +
    annotate("text", x = 1, y = 1, label = "No highlighted\nfamilies found", size = 4) +
    xlim(0, 2) +
    ylim(0, 2) +
    theme_void() +
    labs(title = "Highlighted Families\n(Read Counts)") +
    theme(plot.title = element_text(size = 8, face = "bold", hjust = 1))
}

color_palette <- c("Highlight" = "red", "Other" = "gray80")

filters_txt <- c()
if (!is.na(min_readlen)) filters_txt <- c(filters_txt, paste0("readlen>=", min_readlen))
if (!is.na(min_alnlen))  filters_txt <- c(filters_txt, paste0("alnlen>=", min_alnlen))
if (!is.na(min_pident))  filters_txt <- c(filters_txt, paste0("pident>=", min_pident))
if (!is.na(max_evalue))  filters_txt <- c(filters_txt, paste0("evalue<=", format(max_evalue, scientific = TRUE)))
if (!is.na(min_cov))     filters_txt <- c(filters_txt, paste0("cov>=", min_cov))

subtitle_txt <- if (length(filters_txt) == 0) "No filters applied" else paste(filters_txt, collapse = "; ")

description_text <- paste(
  "Mycoviral diversity was characterized from metatranscriptome samples",
  "associated with communities.",
  "Displayed hits passed the applied filters for read length, alignment length,",
  "percent identity, coverage, and e-value.",
  sep = "\n"
)

df_filtered <- df_filtered %>%
  dplyr::mutate(
    sample_short = stringr::str_match(as.character(sample), "^SRR([^_]+)_")[, 2],
    sample_short = dplyr::if_else(is.na(sample_short), as.character(sample), sample_short)
  )

main_plot <- ggplot(df_filtered, aes(x = sample_short, y = pident, color = Highlight)) +
  geom_jitter(alpha = alpha_pt, width = 0.2, height = 0) +
  scale_color_manual(values = color_palette) +
  theme_bw() +
  theme(
    axis.text.x = element_text(angle = rotate_x, hjust = 1),
    legend.position = "right"
  ) +
  labs(
    x = "Sample",
    y = "% Identity (pident)",
    title = "Mycovirus Families Read Detection in Metatranscriptomes",
    subtitle = subtitle_txt,
    color = "mycovirus family",
    caption = description_text
  ) +
  scale_y_continuous(limits = c(0, 100), oob = scales::squish)

combined <- main_plot + table_plot + patchwork::plot_layout(widths = c(2.7, 1.3))

ggsave(filename = output, plot = combined, width = w, height = h, dpi = dpi)
message("Plot saved to: ", output)