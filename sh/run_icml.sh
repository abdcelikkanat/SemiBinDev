#!/usr/bin/bash -l
#SBATCH --job-name=RUN
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --partition=high-mem
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
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
pip install ${BASE_DIR} > /dev/null

${SNAKEMAKE} -s ${BASE_DIR}/sh/Snakefile_icml \
    --use-conda --conda-prefix ~/.conda/envs/ --jobs 100 --latency-wait 120 \
    --cluster "sbatch \
    --job-name={rule} \
    --output=${BASE_DIR}/sh/logs/{rule}_%j.out \
    --nodes 1 \
    --partition={resources.nodetype} \
    --mem={resources.mem} \
    --cpus-per-task={resources.threads} \
    --time=2-00:00:00 \
    --mail-type=FAIL \
    --mail-user=abce@cs.aau.dk"

