from m5.objects import (
    RiscvO3CPU,
    BiModeBP, TAGE_SC_L_8KB,
)
from gem5.isas import ISA
from gem5.components.processors.base_cpu_core import BaseCPUCore
from gem5.components.processors.base_cpu_processor import BaseCPUProcessor

#PROCESADOR
#El core con las funcionalidades que nos interesan
class RiscvO3Core(RiscvO3CPU):
    def __init__(self, bp, proc_config=None):
        """
        RiscvO3Core that accepts an optional proc_config dict (like those in
        `configs/data/data_proc.py`). If provided, keys from proc_config are set
        as attributes on the core after the defaults are applied.

        Args:
            bp: branch predictor selector string
            proc_config: optional dict with processor parameters to apply
        """
        super().__init__()
        # Set branch predictor
        #TODO: Por alguna razón no me deja asignar self.bp a un predictor de saltos creado desde otro modulo de Python,
        #      solo me deja asignarle uno creado desde este modulo. Intentar hacer que se pueda crear desde fuera
        if bp == "TAGE":
            from branchPredictorComponents import BTB, RAS, TAGE_simple
            from ..data.medium_sonicboom_data import MEDIUM_SONICBOOM_BTB_CONFIG, MEDIUM_SONICBOOM_RAS_CONFIG
            self.bp = TAGE_simple(BTB(MEDIUM_SONICBOOM_BTB_CONFIG),
                                  RAS(MEDIUM_SONICBOOM_RAS_CONFIG))
        
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

#Wrapper del core porque gem5 lo demanda
class RiscvO3StdCore(BaseCPUCore):
    def __init__(self, bp, proc_config=None):
        core = RiscvO3Core(bp, proc_config=proc_config)
        super().__init__(core, ISA.RISCV)

#Procesador que permite tener varios cores y además se necesita como wrapper de procesador
class RiscvO3Processor(BaseCPUProcessor):
    def __init__(self, bp, proc_config=None, num_cores=1):
        cores = [RiscvO3StdCore(bp, proc_config=proc_config) for _ in range(num_cores)]
        super().__init__(cores)
