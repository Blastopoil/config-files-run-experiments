from m5.objects import (
    RiscvO3CPU,
)
from gem5.isas import ISA
from gem5.components.processors.base_cpu_core import BaseCPUCore
from gem5.components.processors.base_cpu_processor import BaseCPUProcessor

#PROCESSOR
# The core with the functionalities that interest us
class RiscvO3Core(RiscvO3CPU):
    def __init__(self, proc_config=None):
        """
        RiscvO3Core that accepts an optional proc_config dict (like those in
        `configs/data/data_proc.py`). If provided, keys from proc_config are set
        as attributes on the core after the defaults are applied.

        Args:
            bp: branch predictor selector string
            proc_config: optional dict with processor parameters to apply
        """
        super().__init__()
        
        # Apply any processor configuration values from proc_config
        if proc_config:
            # Only set attributes for non-callable simple values
            for k, v in proc_config.items():
                setattr(self, k, v)
                #try:
                    # avoid clobbering existing complex attributes like objects
                #except Exception:
                    # If a particular attribute can't be set, skip it
                    # (keeps behavior robust for unexpected keys)
                    #continue

# Wrapper of the core because gem5 says it so
class RiscvO3StdCore(BaseCPUCore):
    def __init__(self, proc_config=None):
        core = RiscvO3Core(proc_config=proc_config)
        super().__init__(core, ISA.RISCV)

# Processor that allows for multiple cores and also serves as a wrapper for the processor
class RiscvO3Processor(BaseCPUProcessor):
    def __init__(self, proc_config=None, num_cores=1):
        cores = [RiscvO3StdCore(proc_config=proc_config) for _ in range(num_cores)]
        super().__init__(cores)
