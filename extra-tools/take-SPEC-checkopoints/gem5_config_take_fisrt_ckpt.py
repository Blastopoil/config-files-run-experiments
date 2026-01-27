# Copyright (c) 2022-2025 The Regents of the University of California
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met: redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer;
# redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution;
# neither the name of the copyright holders nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

"""
This gem5 configuation script creates a simple board to run the first
million ticks of the "riscv-hello" binary simulation and saves a checkpoint.
This configuration serves as an example of taking a checkpoint.

This setup is close to the simplest setup possible using the gem5
library. It does not contain any kind of caching, IO, or any non-essential
components.

Usage
-----

```
scons build/ALL/gem5.opt
./build/ALL/gem5.opt \
    configs/example/gem5_library/checkpoints/riscv-hello-save-checkpoint.py
```
"""

import argparse

from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.isas import ISA
from gem5.components.boards.riscv_board import RiscvBoard
from gem5.components.cachehierarchies.classic.private_l1_shared_l2_cache_hierarchy import (
    PrivateL1SharedL2CacheHierarchy,
)
from gem5.components.memory import DualChannelDDR4_2400
from gem5.isas import ISA

from gem5.resources.resource import *
from gem5.simulate.exit_event import ExitEvent

from gem5.resources.resource import obtain_resource
from gem5.simulate.simulator import Simulator
from gem5.utils.override import overrides
from gem5.utils.requires import requires

from gem5.simulate.exit_handler import CheckpointExitHandler

parser = argparse.ArgumentParser()

parser.add_argument(
    "--ckpt_path",
    type=str,
    required=False,
    default="/nfs/home/ce/felixfdec/ckpts_SPEC_intento_mio/RISCV/felix_SPEC_base2",
    help="The directory to store the checkpoint.",
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

board.set_kernel_disk_workload(
    bootloader=obtain_resource(resource_id="riscv-bootloader-opensbi-1.3.1"),
    #kernel=obtain_resource(resource_id="riscv-linux-6.5.5-kernel"), # Let's try a compatible kernel 
    kernel=obtain_resource(resource_id="riscv-linux-6.8.12-kernel"),
    disk_image=DiskImageResource("/nfs/home/ce/felixfdec/riscv-ubuntu-spec.img", root_partition="1"),
#    readfile = args.script, # Since this script only takes checkpoints after boot, no need to pass a script here
#    checkpoint=Path("/nfs/shared/ce/gem5/ckpts/RISCV/SPEC-base") # For the same reason, no ckpt needed here
)

class MiM5CheckpointHandler(CheckpointExitHandler):
    """
    Heredamos de CheckpointExitHandler (hypercall_num=7).
    Ya sabe cómo tomar un checkpoint básico.
    """

    @overrides(CheckpointExitHandler)
    def _process(self, simulator: "Simulator") -> None:
        # Podemos añadir lógica extra antes del checkpoint
        print(f"Ejecutando lógica personalizada antes del checkpoint...")
        
        # Llamamos al comportamiento original de la clase padre
        super()._process(simulator)
        
        print(f"Checkpoint guardado en el tick: {simulator.get_current_tick()}")

    @overrides(CheckpointExitHandler)
    def _exit_simulation(self) -> bool:
        # La clase base devuelve False por defecto
        # Aquí puedes forzar True si quieres que la simulación termine.
        return False

# Instanciamos el handler
handler_instance = MiM5CheckpointHandler(payload={})

# Creamos el simulador mapeando el evento CHECKPOINT al handler
simulator = Simulator(
    board=board
)

simulator.run()
