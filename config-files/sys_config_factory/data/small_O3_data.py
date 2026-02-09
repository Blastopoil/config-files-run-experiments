

SMALL_O3_PROCESSOR_CONFIG = {

    "fetchWidth" : 3,
    "decodeWidth" : 3,
    "renameWidth" : 3,

    "dispatchWidth" : 6,
    "issueWidth" : 6,
    "commitWidth" : 4,
    "wbWidth" : 6,

    "numROBEntries" : 192,
    
    "LQEntries" : 20,
    "SQEntries" : 15,

    "numPhysIntRegs" : 128,
    "numPhysFloatRegs" : 119
}

SMALL_O3_IQ_ENTRIES = 72

SMALL_O3_BTB_CONFIG = {
    "numEntries": 1024,
    "tagBits": 13
}

SMALL_O3_RAS_CONFIG = {
    "numEntries": 16
}