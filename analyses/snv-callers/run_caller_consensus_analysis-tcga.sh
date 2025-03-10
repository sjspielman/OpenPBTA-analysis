#!/bin/bash
# C. Savonen
# CCDL for ALSF 2019

# Purpose: Run an consensus analysis of SNV callers for TCGA data

# Set this so the whole loop stops if there is an error
set -e
set -o pipefail

# Set the working directory to the directory of this file
cd "$(dirname "${BASH_SOURCE[0]}")"

# Scratch folder to use for this module
scratch_dir=../../scratch/snv-callers
mkdir -p $scratch_dir

# Data directory
data_dir=../../data

# The sqlite database made from the callers will be called:
dbfile=${scratch_dir}/tcga_snv_db.sqlite

# Designate output file
consensus_file=results/consensus/tcga-snv-consensus-snv.maf.tsv

# BED and GTF file paths
cds_file=${scratch_dir}/gencode.v27.primary_assembly.annotation.bed

# Set a default for the VAF filter if none is specified
vaf_cutoff=${OPENPBTA_VAF_CUTOFF:-0}

# Unless told to run the plots, the default is to skip them
# To run plots, set OPENPBTA_PLOTS to 1 or more
run_plots_nb=${OPENPBTA_PLOTS:-0}

# If running for manuscript, overwrite any existing tables
run_for_manuscript=${OPENPBTA_MANUSCRIPT:-0}
if [[ "$run_for_manuscript" -eq "0" ]]
then
   overwrite_flag=""
   force_flag=""
else
   overwrite_flag="--overwrite"
   force_flag="-f"
fi

################################ Set Up Database ################################
python3 scripts/01-setup_db.py \
  --db-file $dbfile \
  --strelka-file ${data_dir}/pbta-tcga-snv-strelka2.vep.maf.gz \
  --mutect-file ${data_dir}/pbta-tcga-snv-mutect2.vep.maf.gz \
  --lancet-file ${data_dir}/pbta-tcga-snv-lancet.vep.maf.gz \
  --meta-file ${data_dir}/pbta-tcga-manifest.tsv ${overwrite_flag}

##################### Merge callers' files into total files ####################
Rscript scripts/02-merge_callers.R \
  --db_file $dbfile \
  --output_file $consensus_file \
  --vaf_filter $vaf_cutoff \
  --overwrite

########################## Add consensus to db ################################
python3 scripts/01-setup_db.py \
  --db-file $dbfile \
  --consensus-file $consensus_file ${overwrite_flag}

###################### Create intersection BED files ###########################
# Convert GTF to BED file for use in bedtools
# Here we are only extracting lines with as a CDS i.e. are coded in protein
gunzip -c ${data_dir}/gencode.v27.primary_assembly.annotation.gtf.gz \
  | awk '$3 ~ /CDS/' \
  | convert2bed --do-not-sort --input=gtf - \
  | sort -k 1,1 -k 2,2n \
  | bedtools merge  \
  > $cds_file

######################### Calculate consensus TMB ##############################
Rscript scripts/03-calculate_tmb.R \
  --db_file $dbfile \
  --output results/consensus \
  --metadata ${data_dir}/pbta-tcga-manifest.tsv \
  --coding_regions $cds_file \
  --overwrite \
  --tcga \
  --nonsynfilter_maf

########################## Compress consensus file #############################
gzip ${force_flag} $consensus_file

############################# Comparison Plots #################################
if [ "$run_plots_nb" -gt "0" ]
then
 Rscript -e "rmarkdown::render('compare_snv_callers_plots-tcga.Rmd', clean = TRUE)"
fi
