""" Example use: 
~/gem5/build/RISCV/gem5.opt \
--outdir=/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/improv-output \
/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/config-files/launch_fs_from_ckpt.py \
--spec_number 507 \
--config BigO3 \
--bp TAGE_SC_L \
--mem_size 4
"""
# To enable debug flags, add the following gem5 option:
# --debug-flags=LTage,TageSCL

import argparse
from pathlib import Path
import sys
import os

from gem5.resources.resource import *
from gem5.simulate.exit_event import ExitEvent
from gem5.simulate.simulator import Simulator

from gem5.components.boards.riscv_board import RiscvBoard

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from SPEC_cmds import *

parser = argparse.ArgumentParser(
    description="gem5 full system simulation configuration"
)

spec_choices = [ 502, 503, 505, 507, 508, 510, 511, 519, 520, 521, 523, 
                 526, 527, 531, 541, 544, 548, 549, 554, 557 ]
parser.add_argument(
    "--spec_number",
    choices=spec_choices,
    type=int,
    required=True,
    help=f"SPEC17 app identification's tag: {list(spec_choices)}"
)

config_choices = ["MediumSonicBOOM", "SmallO3", "BigO3", "BaseCPU", "CVA6"]
parser.add_argument(
    "--config",
    choices=config_choices,
    help=f"configuration to use of the following: {list(config_choices)}",
    type=str,
    required=True,
)

bp_choices = ["TAGE_SC_L", "TAGE_SC", "TAGE_L", "LocalBP", "BiModeBP", "AlwaysFalseBP", "AlwaysTrueBP", "RandomBP"]
parser.add_argument(
    "--bp",
    choices=bp_choices,
    help=f"bp to use of the following: {list(bp_choices)}",
    type=str,
    required=True,
)

parser.add_argument(
    "--mem_size",
    choices=[4],
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

parser.add_argument(
    "--extra_params",
    type=str,
    default=None,
    help="String representation of a dictionary with extra parameters to override in the processor configuration (e.g. '{\"fetchWidth\": 2}' to override fetchWidth to 2)",
)

args = parser.parse_args()
mem_size_str = f"{args.mem_size}GiB"

if args.extra_params:
    if args.config != "BaseCPU":
        print("At the moment, extra params are to be passed only to the the BaseCPU")
        exit(1)
    try:
        extra_params = eval(args.extra_params)
        if not isinstance(extra_params, dict):
            print("ERROR: --extra_params must be a string representation of a dictionary")
            exit(1)
    except Exception as e:
        print(f"ERROR: Failed to parse --extra_params: {e}")
        exit(1)
else:
    extra_params = None

match (args.bp):
    case "TAGE_SC_L":
        from sys_config_factory.factories import tage_sc_l_factory
        bp_factory = tage_sc_l_factory
    case "TAGE_SC":
        from sys_config_factory.factories import tage_sc_factory
        bp_factory = tage_sc_factory
    case "TAGE_L":
        from sys_config_factory.factories import tage_l_factory
        bp_factory = tage_l_factory
    case "LocalBP":
        from sys_config_factory.factories import localbp_factory
        bp_factory = localbp_factory
    case "BiModeBP":
        from sys_config_factory.factories import bimodebp_factory
        bp_factory = bimodebp_factory
    case "AlwaysFalseBP":
        from sys_config_factory.factories import falsebp_factory
        bp_factory = falsebp_factory
    case "AlwaysTrueBP":
        from sys_config_factory.factories import truebp_factory
        bp_factory = truebp_factory
    case "RandomBP":
        from sys_config_factory.factories import randombp_factory
        bp_factory = randombp_factory

match (args.config):
    case "MediumSonicBOOM":
        from sys_config_factory.factories import medium_sonicboom_factory
        sys_config = medium_sonicboom_factory(mem_size_str, bp_factory)
    case "SmallO3":
        from sys_config_factory.factories import small_O3_factory
        sys_config = small_O3_factory(mem_size_str, bp_factory)
    case "BigO3":
        from sys_config_factory.factories import big_O3_factory
        sys_config = big_O3_factory(mem_size_str, bp_factory)
    case "BaseCPU":
        from sys_config_factory.factories import base_cpu_factory
        sys_config = base_cpu_factory(mem_size_str, bp_factory, extra=extra_params)
    case "CVA6":
        from sys_config_factory.factories import cva6_factory
        sys_config = cva6_factory(mem_size_str, bp_factory)

processor=sys_config["processor"]
processor.cores[0].core.mmu.pmp.pmp_entries = 0

# Board
board = RiscvBoard(
    clk_freq=sys_config["frequency"],
    processor=processor,
    memory=sys_config["memory_hierarchy"],
    cache_hierarchy=sys_config["cache_hierarchy"]
)

# Checkpoint
ckpt_path_str = fs_ckpt_base_dir + fs_spec_ckpt_dirs[args.spec_number]
ckpt_path = Path(ckpt_path_str)
if not ckpt_path.exists():
    print(f"ERROR: Checkpoint path does not exist: {ckpt_path}")
    exit(1)
print(f"Restoring from checkpoint path: {ckpt_path}")

# Event handlers
if (args.spec_number == 520 or args.spec_number == 531 or args.spec_number == 557):
    total_works = 10
elif (args.spec_number == 526 ):
    total_works = 240
else:
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
    kernel=obtain_resource(resource_id="riscv-linux-6.8.12-kernel"),
    disk_image=DiskImageResource(local_path=disk_image_path, root_partition="1"),
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
print("================== Starting my Simulation ==================")
print(f"Starting simulation from checkpoint: {ckpt_path}")
print(f"Configuration: {args.config}")
print(f"Running for maximum {args.num_ticks} ticks or {total_works} workend events")

sim.run(args.num_ticks)

print(f"\nSimulation finished:")
print(f"  Final tick: {sim.get_current_tick()}")
print(f"  Exit cause: {sim.get_last_exit_event_cause()}")
