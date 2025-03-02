# Create plot of co-occurence and mutual exclusivity
#
# JA Shapiro for ALSF - CCDL
#
# 2019-2020
#
# Option descriptions
#
# --infile The input file  with a summaries of gene-gene mutation co-occurence,
#    minimally including gene1, gene2, and cooccur_score columns.
#
# --outfile The output plot location. Specify type of file with the extension
#   (.png or .pdf, most likely).
#
# --plotsize The number of rows and columns in the expected plot, for scaling.
#   Larger numbers will create smaller boxes for the heatmap tiles.
#
# --write_zenodo_csv: Whether to write out figure data used in the manuscript 
#   targeted for Zenodo upload 

#
# Command line example:
#
# Rscript analyses/interaction-plots/03-plot_interactions.R \
#   --infile analyses/interaction-plots/results/cooccur.tsv \
#   --outfile analyses/interaction-plots/results/cooccur.png

#### Initial Set Up


# Load libraries:
library(optparse)
library(magrittr)
library(ggplot2)
library(patchwork)


# define options
option_list <- list(
  make_option(
    opt_str = "--infile",
    type = "character",
    help = "File path where cooccurence summary table is located",
    metavar = "character"
  ),
  make_option(
    opt_str = "--outfile",
    type = "character",
    help = "File path where output plot will be located. Extension specifies format of plot",
    metavar = "character"
  ),
  make_option(
    opt_str = "--plotsize",
    default = "50",
    type = "numeric",
    help = "Relative size of plots; number of rows and columns to be plotted",
    metavar = "character"
  ),
  make_option(
    opt_str = "--disease_table",
    type = "character",
    default = NA,
    help = "File path where gene X disease table is located (optional)",
    metavar = "character"
  ),
  make_option(
    opt_str = "--disease_plot",
    type = "character",
    default = NA,
    help = "File path where gene X disease plot should be placed (required if --disease_table specified)",
    metavar = "character"
  ),
  make_option(
    opt_str = "--combined_plot",
    type = "character",
    default = NA,
    help = "File path where gene X disease plot should be placed (required if --disease_table specified)",
    metavar = "character"
  ),
  make_option(
    opt_str = "--write_zenodo_csv",
    action = "store_true",
    default = FALSE,
    help = "When this flag is used, output tabular data associated with manuscript figures targeted for Zenodo upload to file."
  )
)

# Parse options
opts <- parse_args(OptionParser(option_list = option_list))

if (!is.na(opts$disease_table)){
  if (is.na(opts$disease_plot) | is.na(opts$combined_plot)){
    stop("If disease_table is specified, disease_plot and/or combined plot must also be specified")
  }
}

cooccur_file <- opts$infile
plot_file <- opts$outfile

# get root directory
root_dir <- rprojroot::find_root(rprojroot::has_dir(".git"))

cooccur_df <-
  readr::read_tsv(cooccur_file, col_types = readr::cols()) %>%
  dplyr::mutate(
    mut1 = mut11 + mut10,
    mut2 = mut11 + mut01,
    label1 = paste0(gene1, " (", mut1, ")"),
    label2 = paste0(gene2, " (", mut2, ")")
  )

labels <- unique(c(cooccur_df$label1, cooccur_df$label2))

# check the order of the labels to be decreasing by mut count
label_counts <- as.numeric(stringr::str_extract(labels, "\\b\\d+\\b"))
labels <- labels[order(label_counts, decreasing = TRUE)]
# order genes the same way, in case we want to use those
genes <- stringr::str_extract(labels, "^.+?\\b")
genes <- genes[order(label_counts, decreasing = TRUE)]

cooccur_df <- cooccur_df %>%
  dplyr::mutate(
    gene1 = factor(gene1, levels = genes),
    gene2 = factor(gene2, levels = genes),
    label1 = factor(label1, levels = labels),
    label2 = factor(label2, levels = labels)
  )


# Get color palettes

palette_dir <- file.path(root_dir, "figures", "palettes")
divergent_palette <- readr::read_tsv(file.path(palette_dir, "divergent_color_palette.tsv"),
                                     col_types = readr::cols())
divergent_colors <- divergent_palette %>%
  dplyr::filter(color_names != "na_color") %>%
  dplyr::pull(hex_codes)
na_color <- divergent_palette %>%
  dplyr::filter(color_names == "na_color") %>%
  dplyr::pull(hex_codes)

histologies_color_key_df <- readr::read_tsv(file.path(palette_dir,
                                                      "broad_histology_cancer_group_palette.tsv"),
                                            col_types = readr::cols()) %>%
  # add a border column
  dplyr::mutate(border = "#666666") %>%
  # colors for headings (NA because these will be blank)
  tibble::add_row(cancer_group_display = "High-grade gliomas",
                  cancer_group_hex = NA,
                  border = NA ) %>%
  tibble::add_row(cancer_group_display = "Low-grade gliomas",
                  cancer_group_hex = NA,
                  border = NA) %>%
  tibble::add_row(cancer_group_display = "Embryonal tumors",
                  cancer_group_hex = NA,
                  border = NA) %>%
  tibble::add_row(cancer_group_display = "blank",
                  cancer_group_hex = NA,
                  border = NA)

# create scales for consistent sizing
# The scales will need to have opts$plotsize elements,
# so after getting the unique list, we concatenate on extra elements.
# for convenience, these are just numbers 1:n
# where n is the number of extra labels needed for the scale
xscale <- cooccur_df$label1 %>%
  as.character() %>%
  unique() %>%
  c(1:(opts$plotsize - length(.)))
yscale <- cooccur_df$label2 %>%
  as.character() %>%
  unique() %>%
  # the concatenated labels need to be at the front of the Y scale,
  # since this will be at the bottom in the plot.
  c(1:(opts$plotsize - length(.)), .)

### make plot
cooccur_plot <- ggplot(
  cooccur_df,
  aes(x = label1, y = label2, fill = cooccur_score)
) +
  geom_tile(width = 0.7, height = 0.7) +
  scale_x_discrete(
    position = "top",
    limits = xscale,
    breaks = unique(cooccur_df$label1)
  ) + # blank unused sections.
  scale_y_discrete(
    limits = yscale,
    breaks = unique(cooccur_df$label2)
  ) +
  scale_fill_gradientn(
    colors = divergent_colors,
    na.value = na_color,
    limits = c(-10, 10),
    oob = scales::squish,
  ) +
  labs(
    x = "",
    y = "",
    fill = "Co-occurence\nscore"
  ) +
  theme_classic() +
  theme(
    aspect.ratio = 1,
    axis.text.x = element_text(
      angle = -90,
      hjust = 1,
      size = 6
    ),
    axis.text.y = element_text(size = 6),
    axis.line = element_blank(),
    axis.ticks = element_blank(),
    legend.justification = c(1, 0),
    legend.position = c(0.9, 0.1),
    legend.key.size = unit(2, "char")
  )

ggsave(cooccur_plot, filename = plot_file)

# if we don't have a disease table, quit
if (is.na(opts$disease_table)) {
 quit()
}
# otherwise make a gene by disease stacked bar chart

disease_file <- opts$disease_table

# read in diseases by gene file
disease_df <- readr::read_tsv(disease_file, col_types = readr::cols()) %>%
  dplyr::mutate(gene = factor(gene, levels = genes)) %>%
  # add plot header rows
  tibble::add_row(gene = "TP53", mutant_samples = 0.00001, disease = "High-grade gliomas") %>%
  tibble::add_row(gene = "TP53", mutant_samples = 0.00001, disease = "Low-grade gliomas") %>%
  tibble::add_row(gene = "TP53", mutant_samples = 0.00001, disease = "Embryonal tumors") %>%
  tibble::add_row(gene = "TP53", mutant_samples = 0.00001, disease = "blank")


# What are the top 10 mutated cancer display groups?
# display_diseases <- disease_df %>%
#   # remove other from top 10 possibilities
#   dplyr::filter(disease != "Other") %>%
#   dplyr::select(disease, mutant_samples) %>%
#   dplyr::arrange(desc(mutant_samples)) %>%
#   dplyr::select(disease) %>%
#   unique() %>%
#   head(10) %>% # top 10 diseases with highest mutated samples
#   dplyr::pull(disease)

# Print
# print(display_diseases)

 # We want to set the order to have "other" HGG or LGG come last within the groups

 display_diseases <- c("High-grade gliomas",
                       "Diffuse midline glioma",
                       "Other high-grade glioma",
                       "Low-grade gliomas",
                       "Pilocytic astrocytoma",
                       "Ganglioglioma",
                       "Pleomorphic xanthoastrocytoma",
                       "Other low-grade glioma",
                       "Embryonal tumors",
                       "Medulloblastoma",
                       "Atypical Teratoid Rhabdoid Tumor",
                       "Other embryonal tumor",
                       "blank",
                       "Ependymoma",
                       "Craniopharyngioma",
                       "Meningioma",
                       "Other")

# Add display values with bold for headers and `atop` to add spacing
 display_disease_lab <- c(expression(bold("High-grade gliomas")),
                       "Diffuse midline glioma",
                       "Other high-grade glioma",
                       expression(atop(" ", bold("Low-grade gliomas"))),
                       "Pilocytic astrocytoma",
                       "Ganglioglioma",
                       "Pleomorphic xanthoastrocytoma",
                       "Other low-grade glioma",
                       expression(atop(" ", bold("Embryonal tumors"))),
                       "Medulloblastoma",
                       "Atypical Teratoid Rhabdoid Tumor",
                       "Other embryonal tumor",
                       " ",
                       "Ependymoma",
                       "Craniopharyngioma",
                       "Meningioma",
                       "Other")


disease_df_fct <- disease_df %>%
  dplyr::filter(!is.na(disease)) %>%
  dplyr::mutate(disease_factor =
           forcats::fct_other(disease, keep = display_diseases) %>%
           forcats::fct_relevel(display_diseases)
  ) %>%
  # If you are to outline the stacked bars in anyway, all Other samples need to
  # be summarized
  dplyr::group_by(gene, disease_factor) %>%
  dplyr::summarize(mutant_samples = sum(mutant_samples)) %>%
  dplyr::ungroup()

histologies_color_key <- histologies_color_key_df$cancer_group_hex
names(histologies_color_key) <- histologies_color_key_df$cancer_group_display

# set up border colors
histologies_border_key <- histologies_color_key_df$border
names(histologies_border_key) <- histologies_color_key_df$cancer_group_display

# get scale to match cooccurence plot
# Extra scale units for the case where there are fewer genes than opts$plotsize
xscale2 <- levels(disease_df_fct$gene) %>%
  c(rep("", opts$plotsize - length(.)))

disease_plot <- ggplot(
  disease_df_fct,
  aes(x = gene,
      y = mutant_samples,
      fill = disease_factor,
      color = disease_factor)) +
  geom_col(width = 0.7,
           size = 0.15) +
  labs(
    x = "",
    y = "Tumors with mutations",
    fill = "Cancer Group",
    color = "Cancer Group"
  ) +
  scale_fill_manual(values = histologies_color_key, labels = display_disease_lab) +
  scale_color_manual(values = histologies_border_key, labels = display_disease_lab) +
  scale_x_discrete(
    limits = xscale2,
    breaks = disease_df$gene
  ) +
  scale_y_continuous(expand = c(0, 0.5, 0.1, 0)) +
  theme_classic() +
  theme(
    axis.text.y = element_text(size = rel(1.3)),
    axis.title.y = element_text(size = rel(1.225)),
    axis.text.x = element_text(
      angle = 90,
      hjust = 1,
      vjust = 0.5
    ),
    legend.position = c(1,1),
    legend.justification = c(1,1),
    legend.key.size = unit(1, "char"),
    legend.text = element_text(size = rel(1))
  )


if (!is.na(opts$disease_plot)){
  ggsave(opts$disease_plot, disease_plot)
}

# only proceed if we want a combined plot
if (is.na(opts$combined_plot)){
  quit()
}


# Modify cooccur plot to drop counts and X axis

# labels for y axis will be gene names, with extra spaces (at bottom) blank
ylabels  <- cooccur_df$gene2%>%
  as.character() %>%
  unique() %>%
  c(rep("", opts$plotsize - length(.)), .)

cooccur_plot2 <- cooccur_plot +
  scale_x_discrete(
    limits = xscale,
    breaks = c()
  ) +
  scale_y_discrete(
    limits = yscale,
    labels = ylabels
  ) +
  theme(
    axis.text.y = element_text(size = 9),
    legend.text = element_text(size = 12),
    legend.title = element_text(size = 14),
    plot.margin = unit(c(-3.5,0,0,0), "char") # negative top margin to move plots together
  )

# Move labels and themes for disease plot
disease_plot2 <- disease_plot +
  theme(
    axis.text.x = element_text(
      size = 9,
      angle = -90,
      hjust = 1,
      vjust = 0.5
    ),
    axis.text.y = element_text(size = 12),
    axis.title.y = element_text(
      size = 14,
      vjust = -10 # keep the label close when combined
    ),
    legend.text = element_text(size = 12),
    legend.title = element_text(size = 14),
    legend.position = c(0.98, 0.98)
  )

# Combine plots with <patchwork>
# Layout of the two plots will be one over the other (1 column),
# with the upper plot 3/4 the height of the lower plot
combined_plot <- disease_plot2 + cooccur_plot2 +
  plot_layout(ncol = 1, heights = c(3, 4)) 

ggsave(combined_plot,
       filename = opts$combined_plot,
       width = 8,
       height = 14)


# Export `cooccur_df`- CSV file with data for figure 3A in manuscript, if specified
if (opts$write_zenodo_csv) {
  readr::write_csv(
    cooccur_df,
    file.path(root_dir,
              "analyses",
              "interaction-plots",
              "results",
              "figure-3a-data.csv")
  )
}


