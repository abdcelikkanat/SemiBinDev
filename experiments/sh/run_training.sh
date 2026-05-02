#!/usr/bin/bash -l
#SBATCH --job-name=RUN
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --partition=high-mem
#SBATCH --cpus-per-task=1
#SBATCH --mem=96G
#SBATCH --time=1-00:00:00
#SBATCH --mail-type=NONE #---ALL
#SBATCH --mail-user=abce@cs.aau.dk
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

# Exit on first error and if any variables are unset
set -eu

# Define global variables
BASE_DIR=/home/cs.aau.dk/zs74qz/workspace/SemiBinICLR
CONDA_ENV_DIR=~/.conda/envs
SEMIBIN2_ENV_NAME=semibiniclr

# Load the required modules
SNAKEMAKE=/home/cs.aau.dk/zs74qz/.conda/envs/snakemake/bin/snakemake

# Reinstall the Semibin2
conda activate ${CONDA_ENV_DIR}/semibiniclr
pip install ${BASE_DIR}

SEMIBIN2="/home/cs.aau.dk/zs74qz/.conda/envs/semibiniclr/bin/SemiBin2"
CONTAINER="/home/cs.aau.dk/zs74qz/workspace/MethylBinProject/bio_tools_sandbox"

DATA_PATH=/projects/dark_science/methylation_binning/article/outputs/nanomotif_v1.1.0/fecal_deep/SemiBin2/bins/data.csv
DATA_SPLIT_PATH=/projects/dark_science/methylation_binning/article/outputs/nanomotif_v1.1.0/fecal_deep/SemiBin2/bins/data_split.csv


# Define the samples
SAMPLES=( fecal_deep ) #( WW-IL-01 )

for SAMPLE_NAME in ${SAMPLES[@]}
do
# Define the output path
SAMPLE_FASTA_FILE="/projects/dark_science/methylation_binning/development/data/datasets/${SAMPLE_NAME}/myloasm/eukfilt_assembly.fasta"
SAMPLE_OUTPUT_FOLDER="/home/cs.aau.dk/zs74qz/workspace/SemiBinICLR/outputs/${SAMPLE_NAME}"

# Train the model
CMD="${SEMIBIN2} train_self"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --data-split ${DATA_SPLIT_PATH}"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}"
#${CMD}

# Binning on the last model
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/model.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/bins"
CMD="${CMD} -p 16"
#${CMD}

# Run CheckM2 tool for the last model
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/bins/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/checkm2"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 16"
CMD="${CMD} --force"
#${CMD}

###############################################################
########         Standard = Deviation Operations      #########
###############################################################

# Train the model for standard deviations
CMD="${SEMIBIN2} train_self"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --data-split ${DATA_SPLIT_PATH}"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds"
CMD="${CMD} --checkpoint ${SAMPLE_OUTPUT_FOLDER}/model.pt"
CMD="${CMD} --include_std 1"
#${CMD}

# Binning the standard deviation model
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/stds/model.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds/bins_classic_metric"
CMD="${CMD} -p 16"
#${CMD}

# Run CheckM2 tool for the last model
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/stds/bins_classic_metric/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/stds/checkm2"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 16"
CMD="${CMD} --force"
#${CMD}

EPOCH=5
# Binning for a specific epoch
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/stds/checkpoint=${EPOCH}.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds/bins_classic_metric_epoch_${EPOCH}"
CMD="${CMD} -p 16"
#${CMD}

# Run CheckM2 tool for a specific epoch
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/stds/bins_classic_metric_epoch_${EPOCH}/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/stds/checkm2_epoch_${EPOCH}"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 16"
CMD="${CMD} --force"
#${CMD}


###############################################################
########         Standard = Deviation Operations      #########
###############################################################

# Binning the standard deviation model
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/stds/model.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds/bins_estimated_metric"
CMD="${CMD} -p 16"
CMD="${CMD} --include_std 1"
#${CMD}

# Run CheckM2 tool for the last model
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/stds/bins_estimated_metric/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/stds/checkm2_estimated_metric"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 16"
CMD="${CMD} --force"
#${CMD}

EPOCH=5
# Binning for a specific epoch
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/stds/checkpoint=${EPOCH}.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds/bins_estimated_metric_epoch_${EPOCH}"
CMD="${CMD} -p 16"
CMD="${CMD} --include_std 1"
#${CMD}

# Run CheckM2 tool for a specific epoch
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/stds/bins_estimated_metric_epoch_${EPOCH}/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/stds/checkm2_estimated_epoch_${EPOCH}"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 16"
CMD="${CMD} --force"
#${CMD}


###############################################################
########         Standard = Deviation Operations      #########
###############################################################

# Train the model for standard deviations
CMD="${SEMIBIN2} train_self"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --data-split ${DATA_SPLIT_PATH}"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds_only"
CMD="${CMD} --checkpoint ${SAMPLE_OUTPUT_FOLDER}/model.pt"
CMD="${CMD} --include_std 1"
#${CMD}

# Binning the standard deviation model
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/stds_only/model.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds_only/bins_estimated_metric"
CMD="${CMD} -p 16"
#${CMD}

# Run CheckM2 tool for the last model
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/stds_only/bins_estimated_metric/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/stds_only/checkm2"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 16"
CMD="${CMD} --force"
#${CMD}

EPOCH=5
# Binning for a specific epoch
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/stds_only/checkpoint=${EPOCH}.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds_only/bins_estimated_metric_epoch_${EPOCH}"
CMD="${CMD} -p 16"
#${CMD}

# Run CheckM2 tool for a specific epoch
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/stds_only/bins_estimated_metric_epoch_${EPOCH}/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/stds_only/checkm2_epoch_${EPOCH}"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 16"
CMD="${CMD} --force"
#${CMD}


###############################################################
########         Binning with Standard deviations      #########
###############################################################

echo "Binning"
# Binning the standard deviation model
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/stds_only/model.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds_only/bins_evaluation_includes_stds"
CMD="${CMD} -p 64"
CMD="${CMD} --include_std 1"
#${CMD}

# Run CheckM2 tool for a specific epoch
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/stds_only/bins_evaluation_includes_stds/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/stds_only/checkm2_includes_stds"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 64"
CMD="${CMD} --force"
#${CMD}

###################################################################
#####
###################################################################

EPOCH=5
# Binning for a specific epoch
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/stds_only/checkpoint=${EPOCH}.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds_only/bins_evaluation_includes_stds_epoch_${EPOCH}"
CMD="${CMD} -p 64"
CMD="${CMD} --include_std 1"
#${CMD}

# Run CheckM2 tool for a specific epoch
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/stds_only/bins_evaluation_includes_stds_epoch_${EPOCH}/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/stds_only/checkm2_includes_stds_epoch_${EPOCH}"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 64"
CMD="${CMD} --force"
#${CMD}

###############################################################
########         Binning (Last chance)      #########
###############################################################

echo "Binning"
# Binning the standard deviation model
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/stds_only/model.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds_last_chance/bins"
CMD="${CMD} -p 64"
CMD="${CMD} --include_std 1"
#${CMD}

# Run CheckM2 tool for a specific epoch
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/stds_last_chance/bins/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/stds_last_chance/checkm2"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 64"
CMD="${CMD} --force"
#${CMD}

###################################################################

EPOCH=5
# Binning for a specific epoch
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/stds_only/checkpoint=${EPOCH}.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/stds_last_chance/bins_epoch_${EPOCH}"
CMD="${CMD} -p 64"
CMD="${CMD} --include_std 1"
#${CMD}

# Run CheckM2 tool for a specific epoch
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/stds_last_chance/bins_epoch_${EPOCH}/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/stds_last_chance/checkm2_epoch_${EPOCH}"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 64"
CMD="${CMD} --force"
#${CMD}


###############################################################
########         Standard = Deviation Operations      #########
###############################################################

# Train the model for standard deviations
CMD="${SEMIBIN2} train_self"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --data-split ${DATA_SPLIT_PATH}"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/fixed50"
CMD="${CMD} --checkpoint ${SAMPLE_OUTPUT_FOLDER}/model.pt"
CMD="${CMD} --epochs 50"
CMD="${CMD} --include_std 1"
#${CMD}

# Binning the standard deviation model
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/fixed50/model.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/fixed50/bins_include_std"
CMD="${CMD} -p 16"
CMD="${CMD} --include_std 1"
#${CMD}

# Run CheckM2 tool for the last model
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/fixed50/bins_include_std/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/fixed50/checkm2_include_std"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 16"
CMD="${CMD} --force"
#${CMD}

EPOCH=35
# Binning for a specific epoch
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/fixed50/checkpoint=${EPOCH}.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/fixed50/bins_include_std_epoch_${EPOCH}"
CMD="${CMD} -p 16"
CMD="${CMD} --include_std 1"
#${CMD}

# Run CheckM2 tool for a specific epoch
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/fixed50/bins_include_std_epoch_${EPOCH}/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/fixed50/checkm2_include_std_epoch_${EPOCH}"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 16"
CMD="${CMD} --force"
#${CMD}



###############################################################
########         Corrected Expectation      #########
###############################################################

# Train the model for standard deviations
CMD="${SEMIBIN2} train_self"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --data-split ${DATA_SPLIT_PATH}"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/corrected"
CMD="${CMD} --checkpoint ${SAMPLE_OUTPUT_FOLDER}/model.pt"
CMD="${CMD} --epochs 15"
CMD="${CMD} --include_std 1"
#${CMD}

# Binning the standard deviation model
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/corrected/model.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/corrected/bins_include_std"
CMD="${CMD} -p 16"
CMD="${CMD} --include_std 1"
${CMD}

# Run CheckM2 tool for the last model
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/corrected/bins_include_std/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/corrected/checkm2_include_std"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 16"
CMD="${CMD} --force"
${CMD}

EPOCH=5
# Binning for a specific epoch
CMD="apptainer exec --bind /projects:/projects ${CONTAINER}"
CMD="${CMD} ${SEMIBIN2} bin_long"
CMD="${CMD} --input-fasta ${SAMPLE_FASTA_FILE}"
CMD="${CMD} --data ${DATA_PATH}"
CMD="${CMD} --model ${SAMPLE_OUTPUT_FOLDER}/corrected/checkpoint=${EPOCH}.pt"
CMD="${CMD} --output ${SAMPLE_OUTPUT_FOLDER}/corrected/bins_include_std_epoch_${EPOCH}"
CMD="${CMD} -p 16"
CMD="${CMD} --include_std 1"
#${CMD}

# Run CheckM2 tool for a specific epoch
conda activate checkm2_v1.1.0
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
export CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CMD="checkm2 predict"
CMD="${CMD} -i ${SAMPLE_OUTPUT_FOLDER}/corrected/bins_include_std_epoch_${EPOCH}/output_bins/*"
CMD="${CMD} -o ${SAMPLE_OUTPUT_FOLDER}/corrected/checkm2_include_std_epoch_${EPOCH}"
CMD="${CMD} -x .fa"
CMD="${CMD} -t 16"
CMD="${CMD} --force"
#${CMD}


done




# SemiBin2 train_self --data ./outputs/fecal_deep/data.csv --data-split ./outputs/fecal_deep/data_split.csv --output ./outputs/test2 --checkpoint outputs/fecal_deep/model.pt --include_std 1



