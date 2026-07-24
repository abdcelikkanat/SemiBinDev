#!/usr/bin/bash -l
#SBATCH --job-name=SEMIBIN2
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
SEMIBIN2=/home/cs.aau.dk/zs74qz/.conda/envs/semibin4uncertain/bin/SemiBin2
CHECKM2DB=/databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
DATA_DIR=/projects/dark_science/cs/samples
PROCESSES_NUM=16
MINLEN=3000
EPOCH_NUM=15 # Default 15

# Define Samples
#SAMPLES_KEY=( wwtp_NL-09 )
#SAMPLES_VALUE=( PAQ87691.dorado1.0.0.bm5.2.0_sup.sim.mod4mC_5mC_6mA )
#SAMPLES_KEY=( wwtp_NL-09  wwtp_IN-06 wwtp_US1-124 )
#SAMPLES_VALUE=( PAQ87691.dorado1.0.0.bm5.2.0_sup.sim.mod4mC_5mC_6mA PAQ95921.dorado1.0.0.bm5.2.0_sup.sim.mod4mC_5mC_6mA  PAQ87909.dorado1.0.0.bm5.2.0_sup.sim.mod4mC_5mC_6mA ) 
#SAMPLES_KEY=( ZymoFecal wwtp_NL-09 wwtp_IL-01 wwtp_US2-26 wwtp_IN-06 wwtp_US1-124  )
#SAMPLES_VALUE=( PAW77640.dorado1.0.0.bm5.2.0_sup.sim.mod4mC_5mC_6mA PAQ87691.dorado1.0.0.bm5.2.0_sup.sim.mod4mC_5mC_6mA PAQ87858.dorado1.0.0.bm5.2.0_sup.sim.mod4mC_5mC_6mA PAQ87710.dorado1.0.0.bm5.2.0_sup.sim.mod4mC_5mC_6mA PAQ95921.dorado1.0.0.bm5.2.0_sup.sim.mod4mC_5mC_6mA PAQ87909.dorado1.0.0.bm5.2.0_sup.sim.mod4mC_5mC_6mA )
#SAMPLES_KEY=( "RASK00000027MP" "RASK00000062MP" "ASYM00000026MP" )
#SAMPLES_VALUE=( "RASK00000027MP_R10.4.1_NBD24_5kHz_SUP_400bps" "RASK00000062MP_R10.4.1_NBD24_5kHz_SUP_400bps" "ASYM00000026MP_R10.4.1_NBD24_5kHz_SUP_400bps" )
#SAMPLES_KEY=( "PaPr00000116MP" "PaPr00000216MP" )
#SAMPLES_VALUE=( "PaPr00000116MP_R10.4.1_NBD24_5kHz_SUP_400bps" "PaPr00000216MP_R10.4.1_NBD24_5kHz_SUP_400bps" )
#SAMPLES_KEY=( "ZymoFecal" )
#SAMPLES_VALUE=( "PAW77640.dorado1.0.0.bm5.2.0_sup.sim.mod4mC_5mC_6mA" )
SAMPLES=( "ZymoFecal" )
SAMPLES_NUM=${#SAMPLES[@]}

# Load the required modules
SNAKEMAKE=/home/cs.aau.dk/zs74qz/.conda/envs/snakemake/bin/snakemake
# Activate the conda
conda activate ${CONDA_ENV_DIR}


# Run
for (( i=0; i<$SAMPLES_NUM; i++ )); do

   SAMPLE_NAME="${SAMPLES[$i]}"
   echo ${SAMPLE_NAME}

   CONTIG_FILE=${DATA_DIR}/${SAMPLE_NAME}/contigs.fasta
   BAM_FILE=${DATA_DIR}/${SAMPLE_NAME}/1-NP.bam

   OUTPUT_DIR=${BASE_DIR}/sh/outputs/${SAMPLE_NAME}

   # Generate the input features
   CMD="${SEMIBIN2} generate_sequence_features_single -i ${CONTIG_FILE} -b ${BAM_FILE} -o ${OUTPUT_DIR} -m ${MINLEN} -p ${PROCESSES_NUM}"
   #$CMD

   # Train the model
   INPUT_DATA_FILE=${OUTPUT_DIR}/data.csv
   INPUT_DATASPLIT_FILE=${OUTPUT_DIR}/data_split.csv

   CMD="${SEMIBIN2} train_self --data ${INPUT_DATA_FILE} --data-split ${INPUT_DATASPLIT_FILE}"
   CMD="${CMD} --threads ${PROCESSES_NUM} --engine cpu --epochs ${EPOCH_NUM} --output ${OUTPUT_DIR}/train"
   #         --include_std 0
   #$CMD

   # Binning
   MODEL_FILE=${OUTPUT_DIR}/train/model.pt

   CMD="${SEMIBIN2} bin_long --input-fasta ${CONTIG_FILE} --data ${INPUT_DATA_FILE} --model ${MODEL_FILE}"
   CMD="${CMD} -p ${PROCESSES_NUM} --output ${OUTPUT_DIR}/bins"
   #$CMD

   # Run CheckM2
   conda activate checkm2_v1.1.0
   CMD="${CHECKM2} predict -i ${OUTPUT_DIR}/bins/output_bins/* -o ${OUTPUT_DIR}/checkm2 -x .fa -t ${PROCESSES_NUM} --force"
   $CMD

done

