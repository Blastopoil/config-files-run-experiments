""" Example use:

To compile the binary:
riscv64-unknown-elf-gcc -static -nostdlib -o config-files/test_replicated config-files/test_replicated.s

~/Workspaces/gem5/build/RISCV/gem5.opt \
--outdir=/home/blastopoil/Workspaces/gem5/config-files-run-experiments/improv-output \
/home/blastopoil/Workspaces/gem5/config-files-run-experiments/config-files/launch_binary.py \
--application /home/blastopoil/Workspaces/gem5/config-files-run-experiments/config-files/test_replicated \
--config BigO3 \
--bp GshareMod
"""
# To enable debug flags, add the following gem5 option:
# --debug-flags=LTage,TageSCL --debug-file=trace.out
# --debug-flags=O3PipeView --debug-file=trace.out # For konata
# --debug-flags=O3PipeView,O3CPUAll --debug-file=trace.out # For konata with dependencies
# --debug-flags=GshareReplicatedBP

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
    description="gem5 custom binary simulation configuration"
)

parser.add_argument(
    "--application", 
    type=str, 
    required=True, 
    help="Full path to the binary to be run.")

config_choices = ["MediumSonicBOOM", "SmallO3", "BigO3", "BaseCPU", "CVA6", "MinisculeO3"]
parser.add_argument(
    "--config",
    choices=config_choices,
    help=f"configuration to use of the following: {list(config_choices)}",
    type=str,
    required=True,
)

bp_choices = ["TAGE_SC_L", "TAGE_SC", "TAGE_L", "LTAGE", "LocalBP", "BiModeBP", 
              "AlwaysFalseBP", "AlwaysTrueBP", "RandomBP", 
              "TAGE_SC_L_8", "TAGE_SC_8", "TAGE_L_8",
              "TAGE_SC_L_16", "TAGE_SC_L_32",
              "TAGE_SC_L_no_specul", "LocalBP_no_specul",
              "LongGshare", "Gshare", 
              "GshareMod", "LongGshareMod", "PartitionedGshareMod", "LongPartitionedGshareMod",
              "GshareInclusive", "LongGshareInclusive", "PartitionedGshareInclusive", "LongPartitionedGshareInclusive"]
parser.add_argument(
    "--bp",
    choices=bp_choices,
    help=f"bp to use of the following: {list(bp_choices)}",
    type=str,
    required=True,
)

parser.add_argument(
    "--extra_params",
    type=str,
    default=None,
    help="String representation of a dictionary with extra parameters to override in the processor configuration (e.g. '{\"fetchWidth\": 2}' to override fetchWidth to 2)",
)

parser.add_argument(
    "--btb_params",
    type=str,
    default=None,
    help="Size of the branch target buffer"
)

parser.add_argument(
    "--ras_params",
    type=str,
    default=None,
    help="Size of the return address stack"
)

args = parser.parse_args()
mem_size_str = "4GiB"

# Check that extra_params have been passed if and only if the config is BaseCPU or MinisculeO3 (the only ones currently supporting extra params)
if args.extra_params:
    if args.config != "BaseCPU" and args.config != "MinisculeO3":
        print("At the moment, extra params are to be passed only to the the BaseCPU and MinisculeO3")
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

# Check that extra_params have been passed if and only if the config is BaseCPU (the only one currently supporting custom BTB and RAS sizes)
if (args.btb_params or args.ras_params):
    if args.config != "BaseCPU":
        print("ERROR: --btb_params and --ras_params can only be used with the BaseCPU config")
    try:
        btb_params = eval(args.btb_params) if args.btb_params else None
        ras_params = eval(args.ras_params) if args.ras_params else None
        if btb_params and not isinstance(btb_params, dict):
            print("ERROR: --btb_params must be a string representation of a dictionary")
            exit(1)
        if ras_params and not isinstance(ras_params, dict):
            print("ERROR: --ras_params must be a string representation of a dictionary")
            exit(1)
    except Exception as e:
        print(f"ERROR: Failed to parse --btb_params or --ras_params: {e}")
        exit(1)

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
    case "LTAGE":
        from sys_config_factory.factories import l_tage_factory
        bp_factory = l_tage_factory
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
    case "TAGE_SC_L_8":
        from sys_config_factory.factories import tage_sc_l_8_factory
        bp_factory = tage_sc_l_8_factory
    case "TAGE_SC_8":
        from sys_config_factory.factories import tage_sc_8_factory
        bp_factory = tage_sc_8_factory
    case "TAGE_L_8":
        from sys_config_factory.factories import tage_l_8_factory
        bp_factory = tage_l_8_factory
    case "TAGE_SC_L_16":
        from sys_config_factory.factories import tage_sc_l_16_factory
        bp_factory = tage_sc_l_16_factory
    case "TAGE_SC_L_32":
        from sys_config_factory.factories import tage_sc_l_32_factory
        bp_factory = tage_sc_l_32_factory
    case "TAGE_SC_L_no_specul":
        from sys_config_factory.factories import tage_sc_l_no_speculation_factory
        bp_factory = tage_sc_l_no_speculation_factory
    case "LocalBP_no_specul":
        from sys_config_factory.factories import localbp_no_speculation_factory
        bp_factory = localbp_no_speculation_factory
    case "Gshare":
        from sys_config_factory.factories import gshare_factory
        bp_factory = gshare_factory
    case "LongGshare":
        from sys_config_factory.factories import long_gshare_factory
        bp_factory = long_gshare_factory
    case "GshareMod":
        from sys_config_factory.factories import gshare_mod_factory
        bp_factory = gshare_mod_factory
    case "LongGshareMod":
        from sys_config_factory.factories import long_gshare_mod_factory
        bp_factory = long_gshare_mod_factory
    case "PartitionedGshareMod":
        from sys_config_factory.factories import partitioned_gshare_mod_factory
        bp_factory = partitioned_gshare_mod_factory
    case "LongPartitionedGshareMod":
        from sys_config_factory.factories import long_partitioned_gshare_mod_factory
        bp_factory = long_partitioned_gshare_mod_factory
    case "GshareInclusive":
        from sys_config_factory.factories import gshare_inclusive_factory
        bp_factory = gshare_inclusive_factory
    case "LongGshareInclusive":
        from sys_config_factory.factories import long_gshare_inclusive_factory
        bp_factory = long_gshare_inclusive_factory
    case "PartitionedGshareInclusive":
        from sys_config_factory.factories import partitioned_gshare_inclusive_factory
        bp_factory = partitioned_gshare_inclusive_factory
    case "LongPartitionedGshareInclusive":
        from sys_config_factory.factories import long_partitioned_gshare_inclusive_factory
        bp_factory = long_partitioned_gshare_inclusive_factory

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
        if args.btb_params or args.btb_params:
            sys_config = base_cpu_factory(mem_size_str, bp_factory, extra=extra_params, btb_size=btb_params, ras_size=ras_params)
        else:
            sys_config = base_cpu_factory(mem_size_str, bp_factory, extra=extra_params)
    case "CVA6":
        from sys_config_factory.factories import cva6_factory
        sys_config = cva6_factory(mem_size_str, bp_factory)
    case "MinisculeO3":
        from sys_config_factory.factories import miniscule_O3_factory
        sys_config = miniscule_O3_factory(mem_size_str, bp_factory)

# Board
board = RiscvBoard(
    clk_freq=sys_config["frequency"],
    processor=sys_config["processor"],
    memory=sys_config["memory_hierarchy"],
    cache_hierarchy=sys_config["cache_hierarchy"]
)

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

# Application to be run
binary_path = Path(args.application)

# System Call Emulation
board.set_se_binary_workload(
    binary=BinaryResource(local_path=Path(binary_path).as_posix())
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
print(f"Starting simulation of binary: {binary_path}")
print(f"Configuration: {args.config}")
print(f"Branch Predictor: {args.bp}")

import time
start = time.perf_counter()

print(f"Running until exit event or {total_works} workend events")
sim.run()

end = time.perf_counter()

print("\n============================================================")
print(f"Simulation finished:")
print(f"  Wall-clock runtime: {end - start:.2f} s")
print(f"  Final tick: {sim.get_current_tick()}")
print(f"  Exit cause: {sim.get_last_exit_event_cause()}")
