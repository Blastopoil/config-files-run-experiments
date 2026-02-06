""" Example use: 
cd ~/SPEC/507.cactuBSSN_r/ (or any other folder of the SPEC app you are going to use)

~/gem5/build/RISCV/gem5.opt \
/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/extra-tools/SPEC-se-checkpoints/take_spec_checkpoints.py \
--spec_number 507
"""

import argparse
from pathlib import Path
import sys
import os

import m5

from gem5.resources.resource import *
from gem5.simulate.exit_event import ExitEvent
from gem5.simulate.simulator import Simulator

from gem5.isas import ISA
from gem5.components.boards.riscv_board import RiscvBoard
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.components.cachehierarchies.classic.private_l1_shared_l2_cache_hierarchy import PrivateL1SharedL2CacheHierarchy
from gem5.components.memory import DualChannelDDR4_2400

sys.path.insert(0, "/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/config-files")

from SPEC_cmds import *

parser = argparse.ArgumentParser(
    description="gem5 full system simulation configuration"
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

args = parser.parse_args()

# Board
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

# Checkpoint
ckpt_path_str = ckpt_base_dir + spec_ckpt_dirs[args.spec_number]
ckpt_path = Path(ckpt_path_str)
if not ckpt_path.exists():
    print(f"ERROR: Checkpoint path does not exist: {ckpt_path}")
    exit(1)
print(f"Saving in checkpoint path: {ckpt_path}")

# Event handlers
def handle_workend():
    print("Dump stats at the end of the ROI!")
    m5.stats.dump()
    yield False


def handle_workbegin():
    print("Done booting Linux")
    print("Resetting stats at the start of ROI!")
    m5.stats.reset()
    sim.save_checkpoint(ckpt_path)
    print("Done taking checkpoint")
    yield True


def exit_event_handler():
    print("M5 Exit event")
    yield False

# SPEC application configuration

spec_app_dir = spec_base_dir + spec_app_dirs[args.spec_number]
binary_path = spec_app_dir + spec_app_binaries[args.spec_number]

input_file = None
if spec_app_input_files.get(args.spec_number) is not None:
    input_file = FileResource(local_path = Path(spec_app_dir + spec_app_input_files[args.spec_number]).as_posix())
    print(f"Using input file: {input_file.get_local_path()}")

output_file = None
if spec_app_output_files.get(args.spec_number) is not None:
    output_file = Path(spec_app_output_files[args.spec_number])
    print(f"Using output file: {output_file.as_posix()}")

arguments = []
if spec_app_arguments.get(args.spec_number) is not None:
#    for a in spec_app_arguments[args.spec_number]:
#        print(f"Using argument: {a}")
#        arguments.append(a)
    arguments = spec_app_arguments[args.spec_number]
    print(f"Using arguments: {arguments}")

# System Call Emulation
board.set_se_binary_workload(
    binary=BinaryResource(local_path=Path(binary_path).as_posix()),
    arguments=arguments,
    stdin_file=input_file,
    stdout_file=output_file,
#    checkpoint=ckpt_path,
)

# Create simulator
sim = Simulator(
    board=board,
    full_system=False,
    on_exit_event={
        ExitEvent.WORKBEGIN: handle_workbegin(),
        ExitEvent.WORKEND: handle_workend(),
        ExitEvent.EXIT: exit_event_handler(),
    },
)

# Run simulation
print("================== Starting my Simulation ==================")

sim.run()

print(f"\nSimulation finished:")
print(f"  Final tick: {sim.get_current_tick()}")
print(f"  Exit cause: {sim.get_last_exit_event_cause()}")
