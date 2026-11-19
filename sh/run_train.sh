#!/usr/bin/bash -l
#SBATCH --job-name=SEMIBIN2_TRAIN
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --partition=zen3
#SBATCH --cpus-per-task=1
#SBATCH --mem=99G
#SBATCH --time=5-00:00:00
#SBATCH --mail-type=NONE #---ALL
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

# Trains one phase (mean or std) of the UncertainGen model.
# Writes to ${TRAIN_DIR}:
#   loss_<phase>.tsv                               per-epoch loss
#   checkpoint_<phase>_current_epoch_<E>.pt        every SAVE_EVERY epochs
#   model_final_<phase>_epochs_<EPOCH_NUM>.pt

# Exit on first error and if any variables are unset
set -eu

SEMIBIN2=$1
DATA_FILE=$2
DATASPLIT_FILE=$3
TRAIN_DIR=$4
PROCESSES_NUM=$5
EPOCH_NUM=$6
SAVE_EVERY=$7
PHASE=$8          # "mean" or "std"
EMB_DIM=$9
N_LAYERS=${10}
HIDDEN_DIM=${11}
CHECKPOINT_FILE=${12:-""}   # required for PHASE=std (the trained mean model)

CMD="${SEMIBIN2} train_self --data ${DATA_FILE} --data-split ${DATASPLIT_FILE}"
CMD="${CMD} --threads ${PROCESSES_NUM} --engine cpu --epochs ${EPOCH_NUM} --output ${TRAIN_DIR}"
CMD="${CMD} --save_every ${SAVE_EVERY}"

if [ "${PHASE}" == "mean" ]; then
   CMD="${CMD} --mean_only 1 --std_only 0"
   CMD="${CMD} --emb_dim ${EMB_DIM} --n_layers ${N_LAYERS} --hidden_dim ${HIDDEN_DIM}"
elif [ "${PHASE}" == "std" ]; then
   # Architecture is read from the checkpoint
   CMD="${CMD} --mean_only 0 --std_only 1 --checkpoint_path ${CHECKPOINT_FILE}"
else
   echo "Unknown PHASE: ${PHASE} (expected mean or std)" >&2
   exit 1
fi

echo "${CMD}"
$CMD
