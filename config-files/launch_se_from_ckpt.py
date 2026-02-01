""" Example use:
cd ~/SPEC/507.cactuBSSN_r/ (or any other folder of the SPEC app you are going to use)

~/gem5/build/RISCV/gem5.opt \
/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/config-files/launch_se_from_ckpt.py \
--spec_number 507 \
--config MediumSonicBOOM_TAGE_SC_L \
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
    description="gem5 system call emulation simulation configuration"
)

spec_choices = [ 500, 502, 503, 505, 507, 508, 510, 511, 519, 520, 521, 523, 
                 525, 526, 527, 531, 538, 541, 544, 548, 549, 554, 557 ]

parser.add_argument(
    "--spec_number",
    choices=spec_choices,
    type=int,
    required=True,
    help=f"SPEC17 app identification's tag: {list(spec_choices)}"
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
ckpt_path_str = ckpt_base_dir + spec_ckpt_dirs[args.spec_number]
ckpt_path = Path(ckpt_path_str)
if not ckpt_path.exists():
    print(f"ERROR: Checkpoint path does not exist: {ckpt_path}")
    exit(1)
print(f"Restoring from checkpoint path: {ckpt_path}")

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

# SPEC application configuration

spec_app_dir = spec_base_dir + spec_app_dirs[args.spec_number]
binary_path = spec_app_dir + spec_app_binaries[args.spec_number]

input_file = None
if spec_app_input_files.get(args.spec_number) is not None:
    input_file = FileResource(local_path = Path(spec_app_input_files[args.spec_number]).as_posix())
    print(f"Using input file: {input_file.get_local_path()}")

output_file = None
if spec_app_output_files.get(args.spec_number) is not None:
    output_file = Path(spec_app_output_files[args.spec_number])
    print(f"Using output file: {output_file.as_posix()}")

arguments = []
if spec_app_arguments.get(args.spec_number) is not None:
    arguments = spec_app_arguments[args.spec_number]
    print(f"Using arguments: {arguments}")

# System Call Emulation
board.set_se_binary_workload(
    binary=BinaryResource(local_path=Path(binary_path).as_posix()),
    arguments=arguments,
    stdin_file=input_file,
    stdout_file=output_file,
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
