#!/usr/bin/bash -l
#SBATCH --job-name=SEMIBIN4UNCERTAINGEN
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --partition=gpu-a10 #zen3
#SBATCH --cpus-per-task=1
#SBATCH --mem=25G
#SBATCH --time=1-00:00:00
#SBATCH --mail-type=NONE #---ALL
#SBATCH --mail-user=abce@cs.aau.dk
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

# Exit on first error and if any variables are unset
set -eu

# Define global variables
BASE_DIR=/home/cs.aau.dk/zs74qz/workspace/semibin4uncertain
CONDA_ENV_DIR=/home/cs.aau.dk/zs74qz/.conda/envs/semibin4uncertain
PYTHON_PATH=${CONDA_ENV_DIR}/bin/python
SEMIBIN2=${CONDA_ENV_DIR}/bin/SemiBin2
CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
DATA_DIR=/projects/dark_science/cs/samples
PROCESSES_NUM=16
MINLEN=3000
EPOCH_NUM=15 # Default 15
VERSION="v1.0.3"
SUFFIX=""

# Define Samples
SAMPLES=( "sediment_MFD04716" "sediment_MFD00905" "sediment_MFD05674" "sediment_MFD10007" "sediment_MFD09779" "soil_MFD00392" "soil_MFD06742" "soil_MFD06229" )
#( "wwtp_NL-09" "wwtp_IN-06" "wwtp_US1-124" )
#SAMPLES=("PaPr00000116MP" "RASK00000027MP" "RASK00000062MP" "ASYM00000009MP" "ASYM00000026MP" "wwtp_NL-09" "wwtp_IL-01" "wwtp_US2-26" "wwtp_IN-06" "wwtp_US1-124" )
#SAMPLES=( "wwtp_NL-09" "wwtp_IL-01" "wwtp_US2-26" "wwtp_IN-06" "wwtp_US1-124" )
#( "PaPr00000216MP" "RASK00000027MP" )  #( "wwtp_US2-26" ) #( "RASK00000027MP" ) #( "PaPr00000216MP" ) #( "PaPr00000116MP" ) #( "ASYM00000026MP" ) #( "ZymoFecal" )
SAMPLES_NUM=${#SAMPLES[@]}

# Activate the conda and install the current SemiBin2 version
conda activate ${CONDA_ENV_DIR}
#${CONDA_ENV_DIR}/bin/pip install ${BASE_DIR}
#${CONDA_ENV_DIR}/bin/pip uninstall -y torch
#${CONDA_ENV_DIR}/bin/pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Run
for (( i=0; i<$SAMPLES_NUM; i++ )); do

   # Define the sample name
   SAMPLE_NAME="${SAMPLES[$i]}"
   echo "Starting pipeline for: ${SAMPLE_NAME}"

   # Define the variables
   CONTIG_FILE=${DATA_DIR}/${SAMPLE_NAME}/contigs.fasta
   BAM_FILE=${DATA_DIR}/${SAMPLE_NAME}/1-NP.bam
   MEAN_OUTPUT_DIR=${BASE_DIR}/sh/outputs_${VERSION}/${SAMPLE_NAME}_mean${SUFFIX}
   VAR_OUTPUT_DIR=${BASE_DIR}/sh/outputs_${VERSION}/${SAMPLE_NAME}_var${SUFFIX}
   MEAN_MODEL_FILE=${MEAN_OUTPUT_DIR}/train/model_final_mean_only_epochs_${EPOCH_NUM}.pt
   VAR_MODEL_FILE=${VAR_OUTPUT_DIR}/train/model_final_std_only_epochs_${EPOCH_NUM}.pt

   # First, create the folder if doesn't exists
   mkdir -p ${BASE_DIR}/sh/outputs_${VERSION}

   JOB1_ID=$(sbatch --parsable --job-name="GENERATE_FEATURES_${SAMPLE_NAME}" run_generate_features.sh "${SEMIBIN2}" "${CONTIG_FILE}" "${BAM_FILE}" "${MEAN_OUTPUT_DIR}" "${MINLEN}" "${PROCESSES_NUM}")
   #echo "  -> Step 1 submitted: $JOB1_ID"

   JOB2_ID=$(sbatch --parsable --dependency=afterok:${JOB1_ID} --job-name="MEAN_ONLY_${SAMPLE_NAME}" run_mean_only.sh "${SEMIBIN2}" "${CHECKM2}" "${CONTIG_FILE}" "${MEAN_MODEL_FILE}" "${MEAN_OUTPUT_DIR}" "${PROCESSES_NUM}" "${EPOCH_NUM}")
   #JOB2_ID=$(sbatch --parsable --job-name="MEAN_ONLY_${SAMPLE_NAME}" run_mean_only.sh "${SEMIBIN2}" "${CHECKM2}" "${CONTIG_FILE}" "${MEAN_MODEL_FILE}" "${MEAN_OUTPUT_DIR}" "${PROCESSES_NUM}" "${EPOCH_NUM}")
   echo "  -> Step 2 submitted: $JOB2_ID"

   JOB3_ID=$(sbatch --parsable --dependency=afterok:${JOB2_ID} --job-name="VAR_ONLY_${SAMPLE_NAME}" run_var_only.sh "${SEMIBIN2}" "${CHECKM2}" "${CONTIG_FILE}" "${VAR_MODEL_FILE}" "${MEAN_MODEL_FILE}" "${MEAN_OUTPUT_DIR}" "${VAR_OUTPUT_DIR}" "${PROCESSES_NUM}" "${EPOCH_NUM}")
   echo "  -> Step 3 submitted: $JOB3_ID"
   #sbatch --parsable --job-name="VAR_ONLY_${SAMPLE_NAME}" run_var_only.sh "${SEMIBIN2}" "${CHECKM2}" "${CONTIG_FILE}" "${VAR_MODEL_FILE}" "${MEAN_MODEL_FILE}" "${MEAN_OUTPUT_DIR}" "${VAR_OUTPUT_DIR}" "${PROCESSES_NUM}" "${EPOCH_NUM}"



done

