#!/usr/bin/bash -l
# Submits the UncertainGen hyper-parameter sweep (run this on the login node: bash run_sweep.sh).
#
# For every sample:
#   features (once per sample, skipped if data.csv already exists)
#   for every (EMB_DIM, N_LAYERS):
#       mean training  -> array job: bin (l2) + CheckM2 for every saved epoch
#       std  training  -> array job: bin (mahalanobis) + CheckM2 for every saved epoch
#
# Output layout:
#   outputs_${VERSION}/<sample>/features/{data.csv,data_split.csv}
#   outputs_${VERSION}/<sample>/d<EMB>_L<LAYERS>_h<HIDDEN>/mean/train/{loss_mean_only.tsv,checkpoint_*.pt,...}
#   outputs_${VERSION}/<sample>/d<EMB>_L<LAYERS>_h<HIDDEN>/mean/epoch_<E>/{bins,checkm2}
#   outputs_${VERSION}/<sample>/d<EMB>_L<LAYERS>_h<HIDDEN>/var/train/{loss_std_only.tsv,...}
#   outputs_${VERSION}/<sample>/d<EMB>_L<LAYERS>_h<HIDDEN>/var/epoch_<E>/{bins,checkm2}
# Collect the results with: python get_sweep_scores.py outputs_${VERSION}

# Exit on first error and if any variables are unset
set -eu

# Define global variables
BASE_DIR=/home/cs.aau.dk/zs74qz/workspace/semibin4uncertain
CONDA_ENV_DIR=/home/cs.aau.dk/zs74qz/.conda/envs/semibin4uncertain
SEMIBIN2=${CONDA_ENV_DIR}/bin/SemiBin2
CHECKM2=/home/cs.aau.dk/zs74qz/.conda/envs/checkm2_v1.1.0/bin/checkm2
DATA_DIR=/projects/dark_science/cs/samples
PROCESSES_NUM=16
MINLEN=3000
VERSION="v9experiment"

# Training / checkpointing
EPOCH_NUM=50          # must be a multiple of SAVE_EVERY
SAVE_EVERY=5
MEAN_CKPT_EPOCH=${EPOCH_NUM}   # which mean checkpoint the std phase starts from
RUN_VAR=1                      # 0 = only run the mean phase

# Sweep grid
EMB_DIMS=( 64 100 256 )
N_LAYERS_LIST=( 1 2 3 )
HIDDEN_DIM=512

# Define Samples
SAMPLES=( "sediment_MFD04716" "sediment_MFD00905" "sediment_MFD05674" "sediment_MFD10007" "sediment_MFD09779" "soil_MFD00392" "soil_MFD06742" "soil_MFD06229" )

if (( EPOCH_NUM % SAVE_EVERY != 0 )); then
   echo "EPOCH_NUM (${EPOCH_NUM}) must be a multiple of SAVE_EVERY (${SAVE_EVERY})" >&2
   exit 1
fi
EPOCH_ARRAY="${SAVE_EVERY}-${EPOCH_NUM}:${SAVE_EVERY}"   # e.g. 5-15:5 -> epochs 5,10,15

OUT_ROOT=${BASE_DIR}/sh/outputs_${VERSION}
mkdir -p ${OUT_ROOT}
SUBMITTED_LOG=${OUT_ROOT}/submitted_jobs.tsv
echo -e "# $(date)\tsample\tconfig\tstep\tjob_id" >> ${SUBMITTED_LOG}

for SAMPLE_NAME in "${SAMPLES[@]}"; do

   echo "Starting pipeline for: ${SAMPLE_NAME}"
   CONTIG_FILE=${DATA_DIR}/${SAMPLE_NAME}/contigs.fasta
   BAM_FILE=${DATA_DIR}/${SAMPLE_NAME}/1-NP.bam
   FEATURE_DIR=${OUT_ROOT}/${SAMPLE_NAME}/features
   DATA_FILE=${FEATURE_DIR}/data.csv
   DATASPLIT_FILE=${FEATURE_DIR}/data_split.csv
   mkdir -p ${FEATURE_DIR}

   # 1) Features (shared by all configs of this sample)
   FEAT_DEP=""
   if [ -f "${DATA_FILE}" ] && [ -f "${DATASPLIT_FILE}" ]; then
      echo "  -> features exist, skipping"
   else
      FEAT_ID=$(sbatch --parsable --job-name="FEAT_${SAMPLE_NAME}" \
         run_generate_features.sh "${SEMIBIN2}" "${CONTIG_FILE}" "${BAM_FILE}" "${FEATURE_DIR}" "${MINLEN}" "${PROCESSES_NUM}")
      FEAT_DEP="--dependency=afterok:${FEAT_ID}"
      echo -e "\t${SAMPLE_NAME}\t-\tfeatures\t${FEAT_ID}" >> ${SUBMITTED_LOG}
      echo "  -> features: ${FEAT_ID}"
   fi

   for EMB_DIM in "${EMB_DIMS[@]}"; do
      for N_LAYERS in "${N_LAYERS_LIST[@]}"; do

         CONFIG="d${EMB_DIM}_L${N_LAYERS}_h${HIDDEN_DIM}"
         TAG="${SAMPLE_NAME}_${CONFIG}"
         MEAN_DIR=${OUT_ROOT}/${SAMPLE_NAME}/${CONFIG}/mean
         VAR_DIR=${OUT_ROOT}/${SAMPLE_NAME}/${CONFIG}/var
         mkdir -p ${MEAN_DIR} ${VAR_DIR}

         # 2) Mean phase: train, then bin + CheckM2 every saved epoch (in parallel)
         MEAN_ID=$(sbatch --parsable ${FEAT_DEP} --job-name="MEAN_${TAG}" \
            run_train.sh "${SEMIBIN2}" "${DATA_FILE}" "${DATASPLIT_FILE}" "${MEAN_DIR}/train" \
            "${PROCESSES_NUM}" "${EPOCH_NUM}" "${SAVE_EVERY}" mean "${EMB_DIM}" "${N_LAYERS}" "${HIDDEN_DIM}")
         MEAN_BIN_ID=$(sbatch --parsable --dependency=afterok:${MEAN_ID} --array=${EPOCH_ARRAY} --job-name="MEANBIN_${TAG}" \
            run_bin_checkm2.sh "${SEMIBIN2}" "${CHECKM2}" "${CONTIG_FILE}" "${DATA_FILE}" "${MEAN_DIR}/train" \
            "${MEAN_DIR}" mean l2 "${PROCESSES_NUM}")
         echo -e "\t${SAMPLE_NAME}\t${CONFIG}\tmean_train\t${MEAN_ID}" >> ${SUBMITTED_LOG}
         echo -e "\t${SAMPLE_NAME}\t${CONFIG}\tmean_bin\t${MEAN_BIN_ID}" >> ${SUBMITTED_LOG}
         echo "  -> ${CONFIG}: mean train ${MEAN_ID}, mean bin ${MEAN_BIN_ID}"

         # 3) Std phase: starts from the mean checkpoint at MEAN_CKPT_EPOCH
         if [ "${RUN_VAR}" == "1" ]; then
            MEAN_CKPT=${MEAN_DIR}/train/checkpoint_mean_only_current_epoch_${MEAN_CKPT_EPOCH}.pt
            VAR_ID=$(sbatch --parsable --dependency=afterok:${MEAN_ID} --job-name="VAR_${TAG}" \
               run_train.sh "${SEMIBIN2}" "${DATA_FILE}" "${DATASPLIT_FILE}" "${VAR_DIR}/train" \
               "${PROCESSES_NUM}" "${EPOCH_NUM}" "${SAVE_EVERY}" std "${EMB_DIM}" "${N_LAYERS}" "${HIDDEN_DIM}" "${MEAN_CKPT}")
            VAR_BIN_ID=$(sbatch --parsable --dependency=afterok:${VAR_ID} --array=${EPOCH_ARRAY} --job-name="VARBIN_${TAG}" \
               run_bin_checkm2.sh "${SEMIBIN2}" "${CHECKM2}" "${CONTIG_FILE}" "${DATA_FILE}" "${VAR_DIR}/train" \
               "${VAR_DIR}" std mahalanobis "${PROCESSES_NUM}")
            echo -e "\t${SAMPLE_NAME}\t${CONFIG}\tvar_train\t${VAR_ID}" >> ${SUBMITTED_LOG}
            echo -e "\t${SAMPLE_NAME}\t${CONFIG}\tvar_bin\t${VAR_BIN_ID}" >> ${SUBMITTED_LOG}
            echo "  -> ${CONFIG}: var train ${VAR_ID}, var bin ${VAR_BIN_ID}"
         fi

      done
   done
done
