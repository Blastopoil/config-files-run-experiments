

BIG_O3_PROCESSOR_CONFIG = {

    "fetchWidth" : 6,
    "decodeWidth" : 6,
    "renameWidth" : 6,

    "dispatchWidth" : 11,
    "issueWidth" : 11,
    "commitWidth" : 8,
    "wbWidth" : 11,

    "numROBEntries" : 720,
    
    "LQEntries" : 48,
    "SQEntries" : 48,

    "numPhysIntRegs" : 228,
    "numPhysFloatRegs" : 240
}

BIG_O3_IQ_ENTRIES = 180

BIG_O3_BTB_CONFIG = {
    "numEntries": 2048,
    "tagBits": 13
}

BIG_O3_RAS_CONFIG = {
    "numEntries": 32
}