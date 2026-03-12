

MINISCULE_O3_PROCESSOR_CONFIG = {

    "fetchWidth" : 1,
    "decodeWidth" : 1,
    "renameWidth" : 1,

    "dispatchWidth" : 3,
    "issueWidth" : 3,
    "commitWidth" : 2,
    "wbWidth" : 3,

    "numROBEntries" : 192,
    
    "LQEntries" : 36,
    "SQEntries" : 18,

    "numPhysIntRegs" : 128,
    "numPhysFloatRegs" : 119
}

MINISCULE_O3_IQ_ENTRIES = 72

MINISCULE_O3_BTB_CONFIG = {
    "numEntries": 1024,
    "tagBits": 13
}

MINISCULE_O3_RAS_CONFIG = {
    "numEntries": 16
}