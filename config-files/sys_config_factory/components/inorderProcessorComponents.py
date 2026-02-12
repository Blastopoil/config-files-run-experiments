from typing import List
from m5.objects import (
    RiscvMinorCPU
)
from gem5.components.processors.base_cpu_core import BaseCPUCore
from gem5.components.processors.base_cpu_processor import BaseCPUProcessor
from gem5.isas import ISA

import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))

from queueComponents import CVA6S_FUPool

class RiscvMinorCore(RiscvMinorCPU):
    def __init__(
        self,
        width,
        fetch_buffer_size,
        decode_buffer_size,
        scoreboard_entries,
        lq_entries,
        sq_entries
    ):
        super().__init__()

        self.fetch1FetchLimit = width
        self.decodeInputWidth = width
        self.executeInputWidth = width
        self.executeIssueLimit = width
        self.executeCommitLimit = width

        self.fetch2InputBufferSize = fetch_buffer_size
        self.decodeInputBufferSize = decode_buffer_size
        self.executeInputBufferSize = scoreboard_entries

        self.executeLSQRequestsQueueSize = lq_entries
        self.executeLSQStoreBufferSize = sq_entries
        self.executeLSQMaxStoreBufferStoresPerCycle = 1

        # FU Pool
        ### OJO: ME APARECEN MAS WARNS DE OPS NO SOPORTADAS USANDO ESTE POOL QUE COMENTANDO ESTA LINEA
        #self.executeFuncUnits = CVA6S_FUPool()


# -------------------------------------------------------
# Wrapper estándar compatible con gem5.components
# -------------------------------------------------------
class RiscvMinorStdCore(BaseCPUCore):
    def __init__(
        self,
        width,
        fetch_buffer_size,
        decode_buffer_size,
        scoreboard_entries,
        lq_entries,
        sq_entries
    ):
        core = RiscvMinorCore(
            width,
            fetch_buffer_size,
            decode_buffer_size,
            scoreboard_entries,
            lq_entries,
            sq_entries
        )
        super().__init__(core, ISA.RISCV)


# -------------------------------------------------------
# Procesador completo (varios cores Minor)
# -------------------------------------------------------
class RiscvMinorProcessor(BaseCPUProcessor):
    def __init__(
        self,
        numCores,
        width,
        fetch_buffer_size,
        decode_buffer_size,
        scoreboard_entries,
        lq_entries,
        sq_entries
    ):
        cores: List[BaseCPUCore] = [
            RiscvMinorStdCore(
                width,
                fetch_buffer_size,
                decode_buffer_size,
                scoreboard_entries,
                lq_entries,
                sq_entries
            )
            for _ in range(numCores)
        ]
        super().__init__(cores)