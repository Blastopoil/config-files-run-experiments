#!/bin/bash
#SBATCH --partition=ce_200
#SBATCH --nodelist=ce209
#SBATCH --job-name=mcf_MediumSonicBOOM
#SBATCH --output=/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/1-output-jobs/SPEC17/mcf/slurm-%j.out

echo "============================================"
echo "Running SPEC17 - mcf - MediumSonicBOOM"
echo "============================================"

/nfs/home/ce/felixfdec/gem5v25_0/build/RISCV/gem5.opt \
    -re --outdir=/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/1-output-jobs/SPEC17/mcf \
    /nfs/home/ce/felixfdec/gem5/config-files-run-experiments/config-files/launch_fs_from_ckpt.py \
    --config MediumSonicBOOM \
    --disk_image  /nfs/home/ce/felixfdec/riscv-ubuntu-gem5-appsSmall.img \
    --mem_size 4 \
    --ckpt_path /nfs/shared/ce/gem5/ckpts/RISCV/1core/4GB/SPEC17/ckpt-mcf \
    --num_ticks 100000000000

exit_code=$?


if [ $exit_code -eq 0 ]; then
    echo "Successfully completed simulation for SPEC17/mcf/MediumSonicBOOM"
else
    echo "Failed to complete simulation for SPEC17/mcf/MediumSonicBOOM (exit code: $exit_code)"
fi

exit $exit_code