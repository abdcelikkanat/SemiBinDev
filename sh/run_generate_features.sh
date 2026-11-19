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
CONTIG_FILE=$2
BAM_FILE=$3
OUTPUT_DIR=$4
MINLEN=$5
PROCESSES_NUM=$6

# 1) Generate the input features
CMD="${SEMIBIN2} generate_sequence_features_single -i ${CONTIG_FILE} -b ${BAM_FILE} -o ${OUTPUT_DIR} -m ${MINLEN} -p ${PROCESSES_NUM}"
$CMD

