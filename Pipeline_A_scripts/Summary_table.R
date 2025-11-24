install.packages("tidyverse")
install.packages("tidyr")
install.packages("purrr")
install.packages("data.table")
install.packages("ggplot2")
install.packages("DataExplorer")
install.packages("summarytools")
install.packages("ggrepel")
install.packages("readr")

library(tidyverse)
library(dplyr)
library(tidyr)
library(purrr)
library(magrittr)
library(data.table)
library(ggplot2)
library(DataExplorer)
library(summarytools)
library(ggrepel)
library(readr)


# call NCBI NR and NT database metadata 

BLASTDB <- read.csv("//storage.powerplant.pfr.co.nz/workspace/hrakmc/DBs/NCBI_AllVirus_DB_2AUG2022_sequences.csv", sep = ",", head = TRUE)

colnames(BLASTDB)[colnames(BLASTDB) == "Accession"] <- "Accession.Ver"


##r nt data input

# Pool 1
RNAR1_Blastnt <- read.csv("//storage.powerplant.pfr.co.nz/workspace/hraczj/Phytophthora_VirusDiscovery_2022/008.blastn/RNAR1_nt_blast.csv", sep="", head = FALSE) 

colnames(RNAR1_Blastnt) <- c("qseqid",	"Accession.Ver", "pident",	"staxid",	"ssciname",	"length",	"mismatch",	"gapopen",	"qstart",	"qend",	"sstart",	"send",	"evalue",	"bitscore",	"qlen") 

RNAR1_Blastnt %>%
  dplyr::mutate(coverage = length/qlen) %>%
  left_join(BLASTDB, by = c("Accession.Ver")) -> RNAR1_Blastnt


## r nucleotide combine csv outputs
#Trying to merge of the dataframes together

# Get the names of all 19 dataframes (assuming they follow a pattern or are selected manually)
nt_df_names <- c("Merge_HTSRUBUS2025_Pool1_blastn_saccver_May2025", "Merge_HTSRUBUS2025_Pool2_blastn_saccver_May2025", "Merge_HTSRUBUS2025_Pool3_blastn_saccver_May2025")

# Combine them with a new column indicating the source
combined_nt_HTSRUBUS2025_May2025_df <- map_dfr(nt_df_names, ~ {
  df <- get(.x)         # get the dataframe by name
  df$source_df <- .x    # add a column with the name
  df                   # return modified df
})


# Write the combined data to a new CSV file
write.csv(combined_nt_HTSRUBUS2025_May2025_df, "/powerplant/workspace/hrakmc/RStudio/HTS_Rubus_May2025/combined_data_nt_Rubus_May2025.csv")


combined_nt_HTSRUBUS2025_May2025_df %>%
  distinct(qseqid,.keep_all=TRUE) %>%
  dplyr::select(c("pident","Accession","qseqid", "Organism_Name","Species", "Genus","Family", "length","sstart", "send", "coverage", "evalue","source_df")) %>%
  write.csv("/powerplant/workspace/hrakmc/RStudio/HTS_Rubus_May2025/uniqueIDs_combined_data_nt_Rubus_May2025.csv", sep = "", quote=FALSE, row.names=FALSE, col.names=FALSE)



