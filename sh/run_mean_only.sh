#!/usr/bin/bash -l
#SBATCH --job-name=SEMIBIN2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --partition=zen3
#SBATCH --cpus-per-task=1
#SBATCH --mem=99G
#SBATCH --time=5-00:00:00
#SBATCH --mail-type=NONE #---ALL
#SBATCH --mail-user=abce@cs.aau.dk
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

# Exit on first error and if any variables are unset
set -eu

SEMIBIN2=$1
CHECKM2=$2
CONTIG_FILE=$3
MODEL_FILE=$4
OUTPUT_DIR=$5
PROCESSES_NUM=$6
EPOCH_NUM=$7

INPUT_DATA_FILE=${OUTPUT_DIR}/data.csv
INPUT_DATASPLIT_FILE=${OUTPUT_DIR}/data_split.csv
METRIC="l2"

# I.  Train the model
CMD="${SEMIBIN2} train_self --data ${INPUT_DATA_FILE} --data-split ${INPUT_DATASPLIT_FILE}"
CMD="${CMD} --threads ${PROCESSES_NUM} --engine cpu --epochs ${EPOCH_NUM} --output ${OUTPUT_DIR}/train"
CMD="${CMD} --mean_only 1 --std_only 0"
$CMD

# II.  Binning
CMD="${SEMIBIN2} bin_long --input-fasta ${CONTIG_FILE} --data ${INPUT_DATA_FILE} --model ${MODEL_FILE}"
CMD="${CMD} -p ${PROCESSES_NUM} --output ${OUTPUT_DIR}/bins --metric ${METRIC}"
$CMD

# III. Run CheckM2
conda activate checkm2_v1.1.0
CMD="${CHECKM2} predict -i ${OUTPUT_DIR}/bins/output_bins/* -o ${OUTPUT_DIR}/checkm2 -x .fa -t ${PROCESSES_NUM} --force"
$CMD


