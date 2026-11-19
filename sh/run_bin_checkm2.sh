#!/usr/bin/bash -l
#SBATCH --job-name=SEMIBIN2_BIN
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --partition=zen3
#SBATCH --cpus-per-task=1
#SBATCH --mem=99G
#SBATCH --time=5-00:00:00
#SBATCH --mail-type=NONE #---ALL
#SBATCH --output=%x_%A_%a.out
#SBATCH --error=%x_%A_%a.err

# Bins with one checkpoint and runs CheckM2 on the bins.
# Meant to be submitted as a job array whose task id is the epoch, e.g. --array=5-15:5
# Writes to ${PHASE_DIR}/epoch_<E>/{bins,checkm2}

# Exit on first error and if any variables are unset
set -eu

SEMIBIN2=$1
CHECKM2=$2
CONTIG_FILE=$3
DATA_FILE=$4
TRAIN_DIR=$5
PHASE_DIR=$6
PHASE=$7          # "mean" or "std"
METRIC=$8         # "l2" for mean, "mahalanobis" for std
PROCESSES_NUM=$9
EPOCH=${10:-${SLURM_ARRAY_TASK_ID}}

MODEL_FILE=${TRAIN_DIR}/checkpoint_${PHASE}_only_current_epoch_${EPOCH}.pt
OUTPUT_DIR=${PHASE_DIR}/epoch_${EPOCH}

if [ ! -f "${MODEL_FILE}" ]; then
   echo "Missing checkpoint: ${MODEL_FILE}" >&2
   exit 1
fi

# I. Binning
CMD="${SEMIBIN2} bin_long --input-fasta ${CONTIG_FILE} --data ${DATA_FILE} --model ${MODEL_FILE}"
CMD="${CMD} -p ${PROCESSES_NUM} --output ${OUTPUT_DIR}/bins --metric ${METRIC}"
echo "${CMD}"
$CMD

# II. Run CheckM2
conda activate checkm2_v1.1.0
CMD="${CHECKM2} predict -i ${OUTPUT_DIR}/bins/output_bins/* -o ${OUTPUT_DIR}/checkm2 -x .fa -t ${PROCESSES_NUM} --force"
echo "${CMD}"
$CMD
