"""
~/Workspaces/gem5/build/RISCV/gem5.opt --debug-flags=O3PipeView,O3CPUAll --debug-file=trace.out \
--outdir=/home/blastopoil/Workspaces/gem5/config-files-run-experiments/improv-output \
/home/blastopoil/Workspaces/gem5/config-files-run-experiments/config-files/trial_2_execs_se.py \
--config BigO3 --bp LocalBP --mem_size 4
"""

import argparse
from pathlib import Path
import sys
import os

from m5.objects import *

from gem5.simulate.exit_event import ExitEvent
from gem5.simulate.simulator import Simulator
from gem5.components.boards.riscv_board import RiscvBoard

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from SPEC_cmds import *

parser = argparse.ArgumentParser(
    description="gem5 system call emulation SMT simulation configuration"
)

config_choices = ["MediumSonicBOOM", "SmallO3", "BigO3", "BaseCPU", "CVA6"]
parser.add_argument(
    "--config",
    choices=config_choices,
    help=f"configuration to use of the following: {list(config_choices)}",
    type=str,
    required=True,
)

bp_choices = ["TAGE_SC_L", "TAGE_SC", "TAGE_L", "LTAGE", "LocalBP", "BiModeBP", 
              "AlwaysFalseBP", "AlwaysTrueBP", "RandomBP", 
              "TAGE_SC_L_8", "TAGE_SC_8", "TAGE_L_8"]
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
    help="Memory size in GiB",
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
    help="String representation of a dictionary with extra parameters to override in the processor configuration",
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

# --- BP & CPU Factories ---
match (args.bp):
    case "TAGE_SC_L":
        from sys_config_factory.factories import tage_sc_l_factory
        bp_factory = tage_sc_l_factory
    case "LocalBP":
        from sys_config_factory.factories import localbp_factory
        bp_factory = localbp_factory
    # ... (Resto de tus cases para BP omitidos aquí por brevedad, pero asegúrate de mantenerlos en tu archivo real)
    # Por simplicidad en este bloque de código dejo solo uno, pero copia y pega tus 'match (args.bp)' completos.
    
match (args.config):
    case "BigO3":
        from sys_config_factory.factories import big_O3_factory
        sys_config = big_O3_factory(mem_size_str, bp_factory)
    # ... (Lo mismo para tus cases de CPU, mantén tu bloque match original completo)

processor = sys_config["processor"]
processor.cores[0].core.smtNumFetchingThreads = 2

# --- Creación de la Placa (Board) ---
board = RiscvBoard(
    clk_freq=sys_config["frequency"],
    processor=processor,
    memory=sys_config["memory_hierarchy"],
    cache_hierarchy=sys_config["cache_hierarchy"]
)
board.multi_thread = True

# --- Configuración Explícita de Procesos SPEC (502 y 548) ---
process1 = Process(pid=100)
process1.executable = "/home/blastopoil/Workspaces/SPEC/502.gcc_r_548.exchange2_r/cpugcc_r_base.gem5-riscv"
process1.cwd = "/home/blastopoil/Workspaces/SPEC/502.gcc_r_548.exchange2_r"
process1.cmd = [process1.executable, "-O3", "-fselective-scheduling", "-fselective-scheduling2", "-o", "ref32.opts..s"]
process1.input = "/home/blastopoil/Workspaces/SPEC/502.gcc_r_548.exchange2_r/ref32.c"

process2 = Process(pid=101)
process2.executable = "/home/blastopoil/Workspaces/SPEC/502.gcc_r_548.exchange2_r/exchange2_r_base.gem5-riscv"
process2.cwd = "/home/blastopoil/Workspaces/SPEC/502.gcc_r_548.exchange2_r"
process2.cmd = [process2.executable, "6"]

from gem5.resources.resource import BinaryResource

# --- Configuración Oficial del Board para SE ---
# Usamos el método oficial para que la placa inicialice la memoria, 
# asigne la variable _is_fs a False y prepare el entorno SE.
board.set_se_binary_workload(
    BinaryResource(local_path=process1.executable)
)

# --- Secuestro e Inyección Directa para SMT ---
# Extraemos el núcleo. La placa ya le asignó 'process1' por defecto, 
# pero nosotros lo vamos a sobreescribir con nuestra configuración SMT.
cpu = processor.cores[0].core 
cpu.numThreads = 2
cpu.smtNumFetchingThreads = 2

# Metemos ambos procesos (el board ni se entera, pero el hardware sí)
cpu.workload = [process1, process2]

# Vaciamos las listas de ISA y Decoder generadas por la placa
cpu.isa = []
cpu.decoder = []

# Forzamos la creación de los contextos SMT en el hardware
cpu.createThreads()

# --- Event Handlers ---
total_works = 99

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
    print("WARNING: Unexpected WORKBEGIN event")
    yield False

def exit_event_handler():
    print("Exit event: Application execution finished")
    yield True

# --- Simulación ---
sim = Simulator(
    board=board,
    on_exit_event={
        ExitEvent.WORKBEGIN: handle_workbegin(),
        ExitEvent.WORKEND: handle_workend(),
        ExitEvent.EXIT: exit_event_handler(),
    },
)

print("================== Starting my SMT Simulation ==================")
print(f"Configuration: {args.config}")
print(f"Running for maximum {args.num_ticks} ticks or {total_works} workend events")

sim.run(args.num_ticks)

print(f"\nSimulation finished:")
print(f"  Final tick: {sim.get_current_tick()}")
print(f"  Exit cause: {sim.get_last_exit_event_cause()}")