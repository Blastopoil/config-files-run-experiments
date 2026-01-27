#!/bin/bash

# ~/gem5v25_0/build/RISCV/gem5.opt --outdir=/nfs/home/ce/felixfdec/m5out_gem5v25_kernel_nuevo \
#  config-files-run-experiments/extra-tools/take-SPEC-checkopoints/gem5-config-take-first-ckpt.py

#~/gem5/build/RISCV/gem5.opt config-files-run-experiments/extra-tools/take-SPEC-checkopoints/gem5-config-restore-first-ckpt.py \
#--taken_ckpt_path m5out_first_ckpt_new_kernel_2/cpt.21346248438144

#~/gem5/build/RISCV/gem5.opt config-files-run-experiments/extra-tools/take-SPEC-checkopoints/gem5-config-restore-first-ckpt.py \
#--taken_ckpt_path m5out_first_ckpt_new_kernel/cpt.10300252296096

#~/gem5/build/RISCV/gem5.opt config-files-run-experiments/extra-tools/take-SPEC-checkopoints/gem5-config-restore-first-ckpt.py \
#--taken_ckpt_path m5out_gem5v25_kernel_nuevo/cpt.10272728379354

#~/gem5/build/RISCV/gem5.opt config-files-run-experiments/extra-tools/take-SPEC-checkopoints/gem5-config-restore-first-ckpt.py \
#--taken_ckpt_path m5out_gem5v25_kernel_nuevo/cpt.14304529470714

~/gem5v25_0/build/RISCV/gem5.opt config-files-run-experiments/extra-tools/take-SPEC-checkopoints/gem5-config-restore-first-ckpt.py \
--taken_ckpt_path m5out_gem5v25_kernel_nuevo/cpt.14304529470714
#Ha ido bien, pero queremos usar gem5/, no gem5v25_0/
