import m5

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
import argparse
from pathlib import Path
import os

parser = argparse.ArgumentParser()

parser.add_argument(
    "--taken_ckpt_path",
    type=str,
    required=True,
    help="/nfs/home/ce/felixfdec/ckpts_SPEC_intento_mio/RISCV/felix_SPEC_base plus something else"
)
args = parser.parse_args()

processor = SimpleProcessor(
            cpu_type=CPUTypes.ATOMIC,
            isa=ISA.RISCV,
            num_cores=1,
        )
memory = DualChannelDDR4_2400(size="4GiB")
cache_hierarchy = PrivateL1SharedL2CacheHierarchy(
            l1d_size="64KiB", l1i_size="64KiB", l2_size="1MiB"
        )

board = RiscvBoard(clk_freq="1.4GHz",
                   processor=processor,
                   memory=memory,
                   cache_hierarchy=cache_hierarchy)

taken_ckpt_path = Path(args.taken_ckpt_path)

if not taken_ckpt_path.exists():
    print(f"ERROR: Checkpoint path does not exist: {taken_ckpt_path}")
    exit(1)
else:
    print(f"The path does exist")

print("The taken checkpoint path:")
print(taken_ckpt_path)

# Event handlers
jeje = 1
def handle_workend():
    num_works = 0
    while True:
        num_works += 1
        print(f"Workend event #{num_works}")
        if num_works < jeje:
            yield False
        else:
            print(f"Reached {jeje} workend events, exiting...")
            yield True

def handle_workbegin():
    print("WARNING: Unexpected WORKBEGIN event (should already be past ROI start)")
    yield False

def exit_event_handler():
    print("Exit event: Application execution finished")
    yield True

board.set_kernel_disk_workload(
    bootloader=obtain_resource(resource_id="riscv-bootloader-opensbi-1.3.1"),
    #kernel=obtain_resource(resource_id="riscv-linux-6.5.5-kernel"), # Let's try a compatible kernel 
    kernel=obtain_resource(resource_id="riscv-linux-6.8.12-kernel"),
    disk_image=DiskImageResource("/nfs/home/ce/felixfdec/riscv-ubuntu-spec.img", root_partition="1"),
    checkpoint=taken_ckpt_path
)

simulator = Simulator(
    board=board,
    on_exit_event={
        ExitEvent.WORKBEGIN: handle_workbegin(),
        ExitEvent.WORKEND: handle_workend(),
        ExitEvent.EXIT: exit_event_handler(),
    }
)



simulator.run()
