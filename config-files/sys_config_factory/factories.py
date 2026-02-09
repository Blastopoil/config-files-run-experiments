import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))

from components.processorComponents import RiscvO3Processor

def medium_sonicboom_tage_sc_l_factory(memory_size):
    """
    Generates a system that uses the medium SONICBOOM processor configuration,
    4 GiB memory, L1I/L1D = 32KB, L2 = 1MB, L3 = 4MB, and a TAGE-SC-L branch predictor.
    """
    if (memory_size == None):
        raise ValueError("memory_size must be specified for medium_sonicboom_board_factory")

    from components.memoryComponents import ThreeLevelCacheHierarchy
    cache_hierarchy = ThreeLevelCacheHierarchy(
        l1i_size = "32kB",
        l1d_size = "32kB",
        l2_size = "1MB",
        l3_size = "4MB",)

    from gem5.components.memory.multi_channel import DualChannelDDR4_2400
    memory_hierarchy = DualChannelDDR4_2400(size=memory_size)

    from data.medium_sonicboom_data import MEDIUM_SONICBOOM_PROCESSOR_CONFIG
    processor = RiscvO3Processor(proc_config=MEDIUM_SONICBOOM_PROCESSOR_CONFIG, num_cores=1)

    from components.branchPredictorComponents import customBranchPredictor, BTB, RAS, TAGE_SC_L_64K
    from data.medium_sonicboom_data import MEDIUM_SONICBOOM_BTB_CONFIG, MEDIUM_SONICBOOM_RAS_CONFIG
    processor.cores[0].core.branchPred = customBranchPredictor(
        btb=BTB(MEDIUM_SONICBOOM_BTB_CONFIG),
        ras=RAS(MEDIUM_SONICBOOM_RAS_CONFIG),
        conditional_predictor=TAGE_SC_L_64K()
    )
    processor.cores[0].core.branchPred.requiresBTBHit = True
    processor.cores[0].core.branchPred.takenOnlyHistory = True

    return {
        "processor": processor,
        "memory_hierarchy": memory_hierarchy,
        "cache_hierarchy": cache_hierarchy,
        "frequency": "3GHz"
    }

def medium_sonicboom_tage_l_factory(memory_size):
    """
    Generates a system that uses the medium SONICBOOM processor configuration,
    4 GiB memory, L1I/L1D = 32KB, L2 = 1MB, L3 = 4MB, and a TAGE-L branch predictor (TAGE_SC_L_64K
    without the SC).
    """
    if (memory_size == None):
        raise ValueError("memory_size must be specified for medium_sonicboom_board_factory")

    from components.memoryComponents import ThreeLevelCacheHierarchy
    cache_hierarchy = ThreeLevelCacheHierarchy(
        l1i_size = "32kB",
        l1d_size = "32kB",
        l2_size = "1MB",
        l3_size = "4MB",)

    from gem5.components.memory.multi_channel import DualChannelDDR4_2400
    memory_hierarchy = DualChannelDDR4_2400(size=memory_size)

    from data.medium_sonicboom_data import MEDIUM_SONICBOOM_PROCESSOR_CONFIG
    processor = RiscvO3Processor(proc_config=MEDIUM_SONICBOOM_PROCESSOR_CONFIG, num_cores=1)

    from components.branchPredictorComponents import customBranchPredictor, BTB, RAS, TAGE_L_64K
    from data.medium_sonicboom_data import MEDIUM_SONICBOOM_BTB_CONFIG, MEDIUM_SONICBOOM_RAS_CONFIG
    processor.cores[0].core.branchPred = customBranchPredictor(
        btb=BTB(MEDIUM_SONICBOOM_BTB_CONFIG),
        ras=RAS(MEDIUM_SONICBOOM_RAS_CONFIG),
        conditional_predictor=TAGE_L_64K()
    )
    processor.cores[0].core.branchPred.requiresBTBHit = True
    processor.cores[0].core.branchPred.takenOnlyHistory = True

    return {
        "processor": processor,
        "memory_hierarchy": memory_hierarchy,
        "cache_hierarchy": cache_hierarchy,
        "frequency": "3GHz"
    }

def medium_sonicboom_tage_sc_factory(memory_size):
    """
    Generates a system that uses the medium SONICBOOM processor configuration,
    4 GiB memory, L1I/L1D = 32KB, L2 = 1MB, L3 = 4MB, and a TAGE-SC branch predictor (TAGE_SC_L_64K
    without the L).
    """
    if (memory_size == None):
        raise ValueError("memory_size must be specified for medium_sonicboom_board_factory")

    from components.memoryComponents import ThreeLevelCacheHierarchy
    cache_hierarchy = ThreeLevelCacheHierarchy(
        l1i_size = "32kB",
        l1d_size = "32kB",
        l2_size = "1MB",
        l3_size = "4MB",)

    from gem5.components.memory.multi_channel import DualChannelDDR4_2400
    memory_hierarchy = DualChannelDDR4_2400(size=memory_size)

    from data.medium_sonicboom_data import MEDIUM_SONICBOOM_PROCESSOR_CONFIG
    processor = RiscvO3Processor(proc_config=MEDIUM_SONICBOOM_PROCESSOR_CONFIG, num_cores=1)

    from components.branchPredictorComponents import customBranchPredictor, BTB, RAS, TAGE_SC_64K
    from data.medium_sonicboom_data import MEDIUM_SONICBOOM_BTB_CONFIG, MEDIUM_SONICBOOM_RAS_CONFIG
    processor.cores[0].core.branchPred = customBranchPredictor(
        btb=BTB(MEDIUM_SONICBOOM_BTB_CONFIG),
        ras=RAS(MEDIUM_SONICBOOM_RAS_CONFIG),
        conditional_predictor=TAGE_SC_64K()
    )
    processor.cores[0].core.branchPred.requiresBTBHit = True
    processor.cores[0].core.branchPred.takenOnlyHistory = True

    return {
        "processor": processor,
        "memory_hierarchy": memory_hierarchy,
        "cache_hierarchy": cache_hierarchy,
        "frequency": "3GHz"
    }


