"""
The parametre values of the SONICBOOM's giga configuration
sources: 
https://github.com/riscv-boom/riscv-boom/blob/master/src/main/scala/v4/common/parameters.scala (general parametres)
https://github.com/riscv-boom/riscv-boom/blob/master/src/main/scala/v4/common/config-mixins.scala (concrete parametres)

"inflo" means that since this param doesn't appear in the SONICBOOM source code, 
I make it so big it won't be a bottleneck for other params
"""

GIGA_SONICBOOM_PROCESSOR_CONFIG = {
    # Initial count
    "activity": 0,#por si acaso no inflo

    # Cache Ports. Constrains stores only.
    "cacheStorePorts": 400,#inflo

    # Cache Ports. Constrains loads only.
    "cacheLoadPorts": 400,#inflo

    # Fetch width
    "fetchWidth": 8,#config-mixins.scala

    # Fetch buffer size in bytes
    "fetchBufferSize": 64,#TODO: ¿debería ser 35 (de config-mixins.cala) * tamanho Instruccion en gem5?

    # Fetch queue size in micro-ops per-thread
    "fetchQueueSize": 32,

    # Decode width
    "decodeWidth": 5, #config-mixins.scala

    # Rename width
    "renameWidth": 12,#inflo

    # Dispatch width
    "dispatchWidth": 12,#inflo

    # Issue width
    "issueWidth": 12,#inflo

    # Writeback width
    "wbWidth": 12,#inflo

    # Functional Unit pool
    #"fuPool": DefaultFUPool(),

    # Commit width
    "commitWidth": 12,#inflo

    # Squash width
    "squashWidth": 12,#inflo

    # Time buffer size for backwards communication
    "backComSize": 10,#inflo

    # Time buffer size for forward communication
    "forwardComSize": 10,#inflo

    # Number of load queue entries
    "LQEntries": 32,#config-mixins.scala

    # Number of store queue entries
    "SQEntries": 32,#config-mixins.scala

    # Number of places to shift addr before check
    "LSQDepCheckShift": 8,#inflo

    # Should dependency violations be checked for 
    "LSQCheckLoads": True,

    # Last fetched store table size
    "LFSTSize": 2048,#inflo

    # Store set ID table size
    "SSITSize": "2048",#inflo

    # SSIT table associativity
    "SSITAssoc": 4,#inflo

    # SSIT replacement policy
    #"SSITReplPolicy": LRURP(),

    # Number of physical integer registers
    "numPhysIntRegs": 128,#config-mixins.scala

    # Number of physical floating point registers
    "numPhysFloatRegs": 128,#config-mixins.scala

    # Number of physical vector registers
    "numPhysVecRegs": 512,#inflo

    # Number of physical predicate registers
    "numPhysVecPredRegs": 64,#inflo

    # Number of physical matrix registers
    "numPhysMatRegs": 8,#inflo

    # Number of physical cc registers
    "numPhysCCRegs": 2,#inflo

    # Number of instruction queue entries
    "numIQEntries": 64,

    # Number of reorder buffer entries
    "numROBEntries": 130,#config-mixins.scala

    # Branch Predictor
    #"branchPred": TournamentBP(numThreads=Parent.numThreads), #Este lo selecciono manualmente

    # Enable TSO Memory model
    "needsTSO": False,

    # Enable load receive response throttling in the LSQ
    "recvRespThrottling": False,

    # Maximum number of different receive response cachelines per cycle
    "recvRespMaxCachelines": 2,#inflo

    # Maximum number of receive response bytes per cycle
    "recvRespBufferSize": 128,#inflo
}
