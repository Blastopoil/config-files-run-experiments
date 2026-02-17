import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))

from gem5.components.cachehierarchies.classic.private_l1_shared_l2_cache_hierarchy import PrivateL1SharedL2CacheHierarchy

from components.processorComponents import RiscvO3Processor

def medium_sonicboom_factory(memory_size, bp_factory, extra=None):
    """
    Generates a system that uses the medium SONICBOOM processor configuration,
    4 GiB memory, L1I/L1D = 32KB, L2 = 256KiB and L3 = 2MB
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
    processor_config = MEDIUM_SONICBOOM_PROCESSOR_CONFIG.copy()
    if extra:
        processor_config.update(extra.get("processor", {}))
    processor = RiscvO3Processor(proc_config=processor_config, num_cores=1)

    processor.cores[0].core.branchPred = bp_factory()
    from components.branchPredictorComponents import BTB, RAS
    from data.medium_sonicboom_data import MEDIUM_SONICBOOM_BTB_CONFIG, MEDIUM_SONICBOOM_RAS_CONFIG
    processor.cores[0].core.branchPred.btb = BTB(MEDIUM_SONICBOOM_BTB_CONFIG)
    processor.cores[0].core.branchPred.ras = RAS(MEDIUM_SONICBOOM_RAS_CONFIG)

    return {
        "processor": processor,
        "memory_hierarchy": memory_hierarchy,
        "cache_hierarchy": cache_hierarchy,
        "frequency": "3GHz"
    }

def small_O3_factory(memory_size, bp_factory, extra=None):
    """
    Generates a system that uses a small O3 processor configuration,
    L1I/L1D = 32KB, L2 = 256KB and L3 = 2MB
    """
    if (memory_size == None):
        raise ValueError("memory_size must be specified for smallO3 factory")

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

    from data.small_O3_data import SMALL_O3_PROCESSOR_CONFIG
    processor_config = SMALL_O3_PROCESSOR_CONFIG.copy()
    if extra:
        processor_config.update(extra.get("processor", {}))
    processor = RiscvO3Processor(proc_config=processor_config, num_cores=1)

    processor.cores[0].core.branchPred = bp_factory()
    from components.branchPredictorComponents import BTB, RAS
    from data.small_O3_data import SMALL_O3_BTB_CONFIG, SMALL_O3_RAS_CONFIG
    processor.cores[0].core.branchPred.btb = BTB(SMALL_O3_BTB_CONFIG)
    processor.cores[0].core.branchPred.ras = RAS(SMALL_O3_RAS_CONFIG)

    from components.queueComponents import smallO3_IQ
    from data.small_O3_data import SMALL_O3_IQ_ENTRIES
    processor.cores[0].core.instQueues = [smallO3_IQ(SMALL_O3_IQ_ENTRIES)]

    return {
        "processor": processor,
        "memory_hierarchy": memory_hierarchy,
        "cache_hierarchy": cache_hierarchy,
        "frequency": "3GHz"
    }

def big_O3_factory(memory_size, bp_factory, extra=None):
    """
    Generates a system that uses a big O3 processor configuration,
    L1I/L1D = 64KB, L2 = 1MB and L3 = 16MB
    """
    if (memory_size == None):
        raise ValueError("memory_size must be specified for bigO3 factory")

    from components.memoryComponents import ThreeLevelCacheHierarchy
    cache_hierarchy_data = {
        "l1i_assoc": 4,
        "l1i_size": "64KiB",
        "l1i_tag_latency": 1,
        "l1i_data_latency": 1,
        "l1i_response_latency": 1,
        "l1d_assoc": 8,
        "l1d_size": "64KiB",
        "l1d_tag_latency": 1,
        "l1d_data_latency": 2,
        "l1d_response_latency": 1,
        "l1d_writeback_clean": True,
        "l2_assoc": 8,
        "l2_size": "1MiB",
        "l2_tag_latency": 3,
        "l2_data_latency": 6,
        "l2_response_latency": 3,
        "l3_assoc": 16,
        "l3_size": "16MiB",
        "l3_tag_latency": 10,
        "l3_data_latency": 20,
        "l3_response_latency": 10,
    }
    cache_hierarchy = ThreeLevelCacheHierarchy(**cache_hierarchy_data)

    from gem5.components.memory.multi_channel import DualChannelDDR4_2400
    memory_hierarchy = DualChannelDDR4_2400(size=memory_size)

    from data.big_O3_data import BIG_O3_PROCESSOR_CONFIG
    processor_config = BIG_O3_PROCESSOR_CONFIG.copy()
    if extra:
        processor_config.update(extra.get("processor", {}))
    processor = RiscvO3Processor(proc_config=processor_config, num_cores=1)

    processor.cores[0].core.branchPred = bp_factory()
    from components.branchPredictorComponents import BTB, RAS
    from data.big_O3_data import BIG_O3_BTB_CONFIG, BIG_O3_RAS_CONFIG
    processor.cores[0].core.branchPred.btb = BTB(BIG_O3_BTB_CONFIG)
    processor.cores[0].core.branchPred.ras = RAS(BIG_O3_RAS_CONFIG)

    from components.queueComponents import bigO3_IQ
    from data.big_O3_data import BIG_O3_IQ_ENTRIES
    processor.cores[0].core.instQueues = [bigO3_IQ(BIG_O3_IQ_ENTRIES)]

    return {
        "processor": processor,
        "memory_hierarchy": memory_hierarchy,
        "cache_hierarchy": cache_hierarchy,
        "frequency": "3GHz"
    }

def cva6_factory(memory_size, bp_factory, extra=None):
    """
    Generates a system that uses the CVA6 processor configuration,
    L1I/L1D = 64, L2 = 128KB and no L3
    """
    if (memory_size == None):
        raise ValueError("memory_size must be specified for cva6 factory")

    cache_config = { 
        "l1i_assoc": 2,
        "l1i_size": "64KiB",
        "l1d_assoc": 2,
        "l1d_size": "64KiB",
        "l2_assoc": 8,
        "l2_size": "128KiB",
    }
    cache_hierarchy = PrivateL1SharedL2CacheHierarchy(**cache_config)

    from gem5.components.memory.multi_channel import DualChannelDDR4_2400
    memory_hierarchy = DualChannelDDR4_2400(size=memory_size)

    from data.cva6_data import CVA6_PROCESSOR_CONFIG
    from components.inorderProcessorComponents import RiscvMinorProcessor

    processor_config = CVA6_PROCESSOR_CONFIG.copy()
    if extra:
        processor_config.update(extra.get("processor", {}))
    processor = RiscvMinorProcessor(**processor_config, numCores=1)

    processor.cores[0].core.branchPred = bp_factory()
    from components.branchPredictorComponents import BTB, RAS
    from data.cva6_data import CVA6_BTB_CONFIG, CVA6_RAS_CONFIG
    processor.cores[0].core.branchPred.btb = BTB(CVA6_BTB_CONFIG)
    processor.cores[0].core.branchPred.ras = RAS(CVA6_RAS_CONFIG)

    return {
        "processor": processor,
        "memory_hierarchy": memory_hierarchy,
        "cache_hierarchy": cache_hierarchy,
        "frequency": "3GHz"
    }

def tage_sc_l_factory():
    from components.branchPredictorComponents import customBranchPredictor, TAGE_SC_L_64K
    branchPred = customBranchPredictor(
        conditional_predictor=TAGE_SC_L_64K()
    )
    branchPred.requiresBTBHit = True
    branchPred.takenOnlyHistory = True
    return branchPred

def tage_sc_factory():
    from components.branchPredictorComponents import customBranchPredictor, TAGE_SC_64K
    branchPred = customBranchPredictor(
        conditional_predictor=TAGE_SC_64K()
    )
    branchPred.requiresBTBHit = True
    branchPred.takenOnlyHistory = True
    return branchPred

def tage_l_factory():
    from components.branchPredictorComponents import customBranchPredictor, TAGE_L_64K
    branchPred = customBranchPredictor(
        conditional_predictor=TAGE_L_64K()
    )
    branchPred.requiresBTBHit = True
    branchPred.takenOnlyHistory = True
    return branchPred

def localbp_factory():
    from components.branchPredictorComponents import customBranchPredictor
    from m5.objects import LocalBP
    branchPred = customBranchPredictor(
        conditional_predictor=LocalBP()
    )
    branchPred.requiresBTBHit = True
    branchPred.takenOnlyHistory = True
    return branchPred

def bimodebp_factory():
    from components.branchPredictorComponents import customBranchPredictor
    from m5.objects import BiModeBP
    branchPred = customBranchPredictor(
        conditional_predictor=BiModeBP()
    )
    branchPred.requiresBTBHit = True
    branchPred.takenOnlyHistory = True
    return branchPred

def truebp_factory():
    from components.branchPredictorComponents import customBranchPredictor
    from m5.objects import AlwaysBooleanBP
    branchPred = customBranchPredictor(
        conditional_predictor=AlwaysBooleanBP() # The param alwaysTruePreds defaults to True
    )
    branchPred.requiresBTBHit = True
    branchPred.takenOnlyHistory = True
    return branchPred

def falsebp_factory():
    from components.branchPredictorComponents import customBranchPredictor
    from m5.objects import AlwaysBooleanBP
    branchPred = customBranchPredictor(
        conditional_predictor=AlwaysBooleanBP()
    )
    branchPred.conditionalBranchPred.alwaysTruePreds = False
    branchPred.requiresBTBHit = True
    branchPred.takenOnlyHistory = True
    return branchPred

def randombp_factory():
    from components.branchPredictorComponents import customBranchPredictor
    from m5.objects import RandomBP
    branchPred = customBranchPredictor(
        conditional_predictor=RandomBP()
    )
    branchPred.requiresBTBHit = True
    branchPred.takenOnlyHistory = True
    return branchPred