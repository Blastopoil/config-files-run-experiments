""" Example use: 
build/RISCV/gem5.opt \
-re --outdir=/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/1-output-jobs/Splash-4/RADIX \
/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/config-files/launch_fs_from_ckpt.py \
--config MediumSonicBOOM \
--disk_image /nfs/home/ce/felixfdec/riscv-ubuntu-gem5-appsSmall.img \
--mem_size 2 \
--ckpt_path /nfs/shared/ce/gem5/ckpts/RISCV/1core/2GB/Splash-4/ckpt-RADIX \
--num_ticks 100000000000
"""

import argparse
from pathlib import Path
import sys
import os

from gem5.resources.resource import *
from gem5.simulate.exit_event import ExitEvent
from gem5.simulate.simulator import Simulator

from gem5.components.boards.riscv_board import RiscvBoard

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

parser = argparse.ArgumentParser(
    description="gem5 full system simulation configuration"
)

parser.add_argument(
    "--ckpt_path",
    help="For example: /nfs/shared/ce/gem5/ckpts/RISCV/1core/2GB/Splash-4/ckpt-RADIX",
    type=str,
    required=True,
)

parser.add_argument(
    "--disk_image_path",
    type=str,
    default= "/nfs/home/ce/felixfdec/riscv-ubuntu-gem5-appsSmall.img",
    help="Full path to disk image",
)

config_choices = ["MediumSonicBOOM", "MediumSonicBOOM_TAGE_SC_L", "MediumSonicBOOM_TAGE_L", "MediumSonicBOOM_TAGE_SC"]
parser.add_argument(
    "--config",
    choices=config_choices,
    help=f"configuration to use of the following: {list(config_choices)}",
    type=str,
    required=True,
)

parser.add_argument(
    "--mem_size",
    choices=[2, 4],
    type=int,
    required=True,
    help="Memory size in GiB (must match checkpoint's path)",
)

parser.add_argument(
    "--num_ticks",
    type=int,
    default=10000000000,
    help="Maximum number of ticks to simulate",
)

args = parser.parse_args()
mem_size_str = f"{args.mem_size}GiB"

match (args.config):
    case "MediumSonicBOOM":
        from sys_config_factory.factories import medium_sonicboom_factory
        sys_config = medium_sonicboom_factory(mem_size_str)
    case "MediumSonicBOOM_TAGE_SC_L":
        from sys_config_factory.factories import medium_sonicboom_tage_sc_l_factory
        sys_config = medium_sonicboom_tage_sc_l_factory(mem_size_str)
    case "MediumSonicBOOM_TAGE_L":
        from sys_config_factory.factories import medium_sonicboom_tage_l_factory
        sys_config = medium_sonicboom_tage_l_factory(mem_size_str)
    case "MediumSonicBOOM_TAGE_SC":
        from sys_config_factory.factories import medium_sonicboom_tage_sc_factory
        sys_config = medium_sonicboom_tage_sc_factory(mem_size_str)

# Board
board = RiscvBoard(
    clk_freq=sys_config["frequency"],
    processor=sys_config["processor"],
    memory=sys_config["memory_hierarchy"],
    cache_hierarchy=sys_config["cache_hierarchy"]
)

# Checkpoint
ckpt_path = Path(args.ckpt_path)
if not ckpt_path.exists():
    print(f"ERROR: Checkpoint path does not exist: {ckpt_path}")
    exit(1)

# Event handlers
total_works = 1
def handle_workend():
    num_works = 0
    while True:
        num_works += 1
        print(f"Workend event #{num_works}")
        if num_works < total_works:
            yield False
        else:
            print(f"Reached {total_works} workend events, exiting...")
            yield True

def handle_workbegin():
    print("WARNING: Unexpected WORKBEGIN event (should already be past ROI start)")
    yield False

def exit_event_handler():
    print("Exit event: Application execution finished")
    yield True

# Full System
board.set_kernel_disk_workload(
    bootloader=obtain_resource(resource_id="riscv-bootloader-opensbi-1.3.1"),
    kernel=obtain_resource(resource_id="riscv-linux-6.5.5-kernel"),
    disk_image=DiskImageResource(
        args.disk_image_path,
        root_partition="1"
    ),
    checkpoint=ckpt_path,
)

# Simulator
# Create simulator
sim = Simulator(
    board=board,
    on_exit_event={
        ExitEvent.WORKBEGIN: handle_workbegin(),
        ExitEvent.WORKEND: handle_workend(),
        ExitEvent.EXIT: exit_event_handler(),
    },
)

# Run simulation
print(f"Starting simulation from checkpoint: {ckpt_path}")
print(f"Configuration: {args.config}")
print(f"Running for maximum {args.num_ticks} ticks or {total_works} workend events")

sim.run(args.num_ticks)

print(f"\nSimulation finished:")
print(f"  Final tick: {sim.get_current_tick()}")
print(f"  Exit cause: {sim.get_last_exit_event_cause()}")
