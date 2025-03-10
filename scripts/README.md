# General scripts

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Scripts required to prepare for a data release](#scripts-required-to-prepare-for-a-data-release)
  - [Analysis file generation](#analysis-file-generation)
  - [Molecular subtyping](#molecular-subtyping)
    - [Adding summary analyses to `run-for-subtyping.sh`](#adding-summary-analyses-to-run-for-subtypingsh)
- [Generating analysis files for the manuscript](#generating-analysis-files-for-the-manuscript)
- [Other scripts](#other-scripts)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Scripts required to prepare for a data release

The overall steps for preparing a data release are as follows:

1. Start a release (termed `release-vX-YYYYMMDD` below) that contains all of the PBTA data files (i.e., upstream files) included.
2. Run `scripts/generate-analysis-files-for-release.sh` using the PBTA data files in `release-vX-YYYYMMDD` and commit any changes to files tracked in the repository.
3. Add the analysis files in `scratch/analysis_files_for_release` to `release-vX-YYYYMMDD`.
4. Run `scripts/run-for-subtyping.sh` using the PBTA data files and analysis files in `release-vX-YYYYMMDD` and commit any changes to files tracked in the repository.
5. Add `pbta-histologies.tsv` to `release-vX-YYYYMMDD`.

For definitions of the kinds of files in data releases, please see [this documentation](https://github.com/AlexsLemonade/OpenPBTA-analysis/blob/master/doc/data-files-description.md#data-file-descriptions).

### Analysis file generation

Running the following **from this directory** will generate all analysis files that are included in data releases and compile them in `scratch/analysis_files_for_release` for convenience:

```sh
bash generate-analysis-files-for-release.sh
```

This script also generates a file that contains the MD5 checksums for the analysis files (`scratch/analysis_files_for_release/analysis_files_md5sum.txt`).

**Notes**

- Modules run via this script must have options to use the base (pre-subtyping) histologies file `pbta-histologies-base.tsv`; these options are used in `generate-analysis-files-for-release.sh`.
- :warning: This requires 100GB of disk space to run and it may require more than 32 GB of ram. To test locally, you can use the following:

```
RUN_LOCAL=1 bash generate-analysis-files-for-release.sh
```

### Molecular subtyping

Molecular subtyping as part of data release can be run with the following **from this directory**:

```sh
bash run-for-subtyping.sh
```

This will re-run subtyping for the following broad histologies:

 * [`molecular-subtyping-EWS`](https://github.com/AlexsLemonade/OpenPBTA-analysis/tree/master/analyses/molecular-subtyping-EWS)
 * [`molecular-subtyping-HGG`](https://github.com/AlexsLemonade/OpenPBTA-analysis/tree/master/analyses/molecular-subtyping-HGG)
 * [`molecular-subtyping-LGAT`](https://github.com/AlexsLemonade/OpenPBTA-analysis/tree/master/analyses/molecular-subtyping-LGAT)
 * [`molecular-subtyping-embryonal`](https://github.com/AlexsLemonade/OpenPBTA-analysis/tree/master/analyses/molecular-subtyping-embryonal)
 * [`molecular-subtyping-CRANIO`](https://github.com/AlexsLemonade/OpenPBTA-analysis/tree/master/analyses/molecular-subtyping-CRANIO)
 * [`molecular-subtyping-EPN`](https://github.com/AlexsLemonade/OpenPBTA-analysis/tree/master/analyses/molecular-subtyping-EPN)
 * [`molecular-subtyping-MB`](https://github.com/AlexsLemonade/OpenPBTA-analysis/tree/master/analyses/molecular-subtyping-MB)
 * [`molecular-subtyping-neurocytoma`](https://github.com/AlexsLemonade/OpenPBTA-analysis/tree/master/analyses/molecular-subtyping-neurocytoma)

It will also run any analysis steps used for subtyping that _do not generate files included in a release_ and `molecular-subtyping-pathology` & `molecular-subtyping-integrate` modules to generate the `compiled_molecular_subtypes_with_clinical_pathology_feedback.tsv` file containing the `molecular_subtype` column.


#### Adding summary analyses to `run-for-subtyping.sh`

For an analysis to be run for subyping, it must use `pbta-histologies-base.tsv` as input, and it should not depend on `molecular_subtype` or `integrated_diagnosis` columns for `molecular-subtyping-*` modules.

Please set `OPENPBTA_BASE_SUBTYPING=1` as a condition to run code with `pbta-histologies-base.tsv`.

Here is an example from the _TP53_ classifier module (assumes root of repo):

```
OPENPBTA_BASE_SUBTYPING=1 bash analyses/tp53_nf1_score/run_classifier.sh

```

## Generating analysis files for the manuscript

Once a new data release has been cut, analysis modules should be run with the new data release.
Specifically, non-deprecated analyses which appear in manuscript should be run, and as well as certain analyses that were run in `generate-analysis-files-for-release.sh` which export output files in `scratch/` that are needed for figure generation or require disease label information in the released histologies file.
Note that subtyping modules do not need to be re-run, since subtyping was performed to create the data release itself.
The script `run-manuscript-analyses.sh` can be used for this purpose as:

```
bash run-manuscript-analyses.sh
```

By default, this script will run all relevant analyses as described.
However, some of those analyses have significant memory requirements which are generally not available on local machines.
Therefore, to run only analyses that can be run locally, set `RUN_LOCAL=1`:

```
RUN_LOCAL=1 bash run-manuscript-analyses.sh
```


## Other scripts

* `download-ci-files.sh` allows you to download the CI files locally, e.g., for debugging.
See [these docs](https://github.com/AlexsLemonade/OpenPBTA-analysis#working-with-the-subset-files-used-in-ci-locally).
* `install_bioc.R` is used to install R packages on the project Docker image.
See [these docs](https://github.com/AlexsLemonade/OpenPBTA-analysis#docker-image).
* `check-python.sh` is used in CI to ensure all Python packages on the project Docker image match what is in the `requirements.txt` file in the root of the repository.
See [these docs](https://github.com/AlexsLemonade/OpenPBTA-analysis#docker-image).