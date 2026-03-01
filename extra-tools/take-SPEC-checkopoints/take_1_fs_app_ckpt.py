""" Example Use:

~/gem5/build/RISCV/gem5.opt \
--outdir=/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/improv-output \
~/gem5/config-files-run-experiments/extra-tools/take-SPEC-checkopoints/take_1_app_ckpt.py \
--app 502.gcc_r \
--script '#!/bin/bash

echo "Running gcc"

cd /home/ubuntu/SPEC
./run_spec.sh 502

echo -e "\n\n ****** Done ******* \n\n"

m5 exit
'


"""

import m5
import os
import argparse

from gem5.resources.resource import *
from gem5.simulate.exit_event import ExitEvent
from gem5.simulate.simulator import Simulator

from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.isas import ISA
from gem5.components.boards.riscv_board import RiscvBoard
from gem5.components.cachehierarchies.classic.private_l1_shared_l2_cache_hierarchy import (
    PrivateL1SharedL2CacheHierarchy,
)
from gem5.components.memory import DualChannelDDR4_2400

parser = argparse.ArgumentParser()

parser.add_argument(
    "--new_ckpt_dir",
    type=str,
    default="/nfs/home/ce/felixfdec/ckpts_fs_v25_1",
    help="Directorio donde se guardará el checkpoint",
)
parser.add_argument(
    "--app",
    type=str,
)
parser.add_argument(
    "--script",
    type=str,
    default="",
    help="Script a ejecutar con readfile",
)

args = parser.parse_args()

# Directorio de checkpoint origen
CHECKPOINT_GOLDEN = "/nfs/shared/ce/gem5/ckpts/RISCV/v25.1/full_system/cpt_golden_2"

processor = SimpleProcessor(
            cpu_type=CPUTypes.ATOMIC,
            isa=ISA.RISCV,
            num_cores=1,
        )
processor.cores[0].core.mmu.pmp.pmp_entries = 0
memory = DualChannelDDR4_2400(size="4GiB")
cache_hierarchy = PrivateL1SharedL2CacheHierarchy(
            l1d_size="64KiB", l1i_size="64KiB", l2_size="1MiB"
        )

board = RiscvBoard(clk_freq="1.4GHz",
                   processor=processor,
                   memory=memory,
                   cache_hierarchy=cache_hierarchy)

golden_path = Path(CHECKPOINT_GOLDEN)
app_new_ckpt_path = os.path.join(args.new_ckpt_dir, "SPEC17", f"ckpt-{args.app}")

print("The taken checkpoint path:")
print(app_new_ckpt_path)
if os.path.exists(app_new_ckpt_path):
    import shutil
    shutil.rmtree(app_new_ckpt_path)
os.makedirs(app_new_ckpt_path, exist_ok=True)

def handle_workend():
    print("Error: Found WORKEND event before WORKBEGIN, should not happen!")
    yield True


def handle_workbegin():
    print("Taking checkpoint…")
    print("Resetting stats before taking checkpoint!")
    m5.stats.reset()
    sim.save_checkpoint(app_new_ckpt_path)
    print("Done taking checkpoint")
    yield True


def exit_event_handler():
    print("Exit event: Script finished (or readfile failed)")
    yield True  # Terminar después del segundo exit


board.set_kernel_disk_workload(
    bootloader=obtain_resource(resource_id="riscv-bootloader-opensbi-1.3.1"),
    kernel=obtain_resource(resource_id="riscv-linux-6.8.12-kernel"),
    disk_image=DiskImageResource("/nfs/home/ce/felixfdec/riscv-ubuntu-spec.img", root_partition="1"),
    readfile_contents=args.script,
    checkpoint=golden_path,
)

sim = Simulator(
    board=board,
    on_exit_event={
        ExitEvent.WORKBEGIN: handle_workbegin(),
        ExitEvent.WORKEND: handle_workend(),
        ExitEvent.EXIT: exit_event_handler(),
    },
)

sim.run()