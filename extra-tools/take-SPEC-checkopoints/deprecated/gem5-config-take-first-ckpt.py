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
    "--ckpt_path",
    type=str,
    required=False,
    default="/nfs/home/ce/felixfdec/ckpts_SPEC_intento_mio/RISCV/felix_SPEC_base",
    help="The directory to store the checkpoint.",
)

#parser.add_argument(
#    "--script",
#    type=str,
#    required=False,
#    default="base.sh",
#    help="Launch script",
#)
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

#ckpt_name = "ckpt-" + args.script.split(".")[0]

#ckpt_path = Path(args.ckpt_path, ckpt_name)
ckpt_path = Path(args.ckpt_path)

print(ckpt_path)

def handle_workend():
    print("Dump stats at the end of the ROI!")
    m5.stats.dump()
    yield False


def handle_workbegin():
    print("Done booting Linux")
    print("Resetting stats at the start of ROI!")
    m5.stats.reset()
    simulator.save_checkpoint(ckpt_path) # It didn't save the ckpt in this directory and instead chose m5out/
    print("Done taking checkpoint")
    yield True


def exit_event_handler():
    print("M5 Exit event")
    yield True


board.set_kernel_disk_workload(
    bootloader=obtain_resource(resource_id="riscv-bootloader-opensbi-1.3.1"),
    #kernel=obtain_resource(resource_id="riscv-linux-6.5.5-kernel"), # Let's try a compatible kernel 
    kernel=obtain_resource(resource_id="riscv-linux-6.8.12-kernel"),
    disk_image=DiskImageResource("/nfs/home/ce/felixfdec/riscv-ubuntu-spec.img", root_partition="1"),
#    readfile = args.script, # Since this script only takes checkpoints after boot, no need to pass a script here
#    checkpoint=Path("/nfs/shared/ce/gem5/ckpts/RISCV/SPEC-base") # For the same reason, no ckpt needed here
)

simulator = Simulator(
    board=board,
#    readfile=args.script,
    on_exit_event={
        ExitEvent.WORKBEGIN: handle_workbegin(),
        ExitEvent.WORKEND: handle_workend(),
        ExitEvent.EXIT: exit_event_handler(),
    }

)



simulator.run()
