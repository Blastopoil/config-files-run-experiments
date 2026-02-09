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
    cache_hierarchy_data = {
        "l1i_assoc": 4,
        "l1i_size": "32KiB",
        "l1i_tag_latency": 1,
        "l1i_data_latency": 1,
        "l1i_response_latency": 1,
        "l1d_assoc": 4,
        "l1d_size": "32KiB",
        "l1d_tag_latency": 1,
        "l1d_data_latency": 2,
        "l1d_response_latency": 1,
        "l1d_writeback_clean": True,
        "l2_assoc": 8,
        "l2_size": "256KiB",
        "l2_tag_latency": 3,
        "l2_data_latency": 6,
        "l2_response_latency": 3,
        "l3_assoc": 16,
        "l3_size": "2MiB",
        "l3_tag_latency": 10,
        "l3_data_latency": 20,
        "l3_response_latency": 10,
    }
    cache_hierarchy = ThreeLevelCacheHierarchy(**cache_hierarchy_data)

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
    cache_hierarchy_data = {
        "l1i_assoc": 4,
        "l1i_size": "32KiB",
        "l1i_tag_latency": 1,
        "l1i_data_latency": 1,
        "l1i_response_latency": 1,
        "l1d_assoc": 4,
        "l1d_size": "32KiB",
        "l1d_tag_latency": 1,
        "l1d_data_latency": 2,
        "l1d_response_latency": 1,
        "l1d_writeback_clean": True,
        "l2_assoc": 8,
        "l2_size": "256KiB",
        "l2_tag_latency": 3,
        "l2_data_latency": 6,
        "l2_response_latency": 3,
        "l3_assoc": 16,
        "l3_size": "2MiB",
        "l3_tag_latency": 10,
        "l3_data_latency": 20,
        "l3_response_latency": 10,
    }
    cache_hierarchy = ThreeLevelCacheHierarchy(**cache_hierarchy_data)

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
    cache_hierarchy_data = {
        "l1i_assoc": 4,
        "l1i_size": "32KiB",
        "l1i_tag_latency": 1,
        "l1i_data_latency": 1,
        "l1i_response_latency": 1,
        "l1d_assoc": 4,
        "l1d_size": "32KiB",
        "l1d_tag_latency": 1,
        "l1d_data_latency": 2,
        "l1d_response_latency": 1,
        "l1d_writeback_clean": True,
        "l2_assoc": 8,
        "l2_size": "256KiB",
        "l2_tag_latency": 3,
        "l2_data_latency": 6,
        "l2_response_latency": 3,
        "l3_assoc": 16,
        "l3_size": "2MiB",
        "l3_tag_latency": 10,
        "l3_data_latency": 20,
        "l3_response_latency": 10,
    }
    cache_hierarchy = ThreeLevelCacheHierarchy(**cache_hierarchy_data)

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


