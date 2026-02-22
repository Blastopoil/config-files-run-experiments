

BIG_O3_PROCESSOR_CONFIG = {

    "fetchWidth" : 6,
    "decodeWidth" : 6,
    "renameWidth" : 6,

    "dispatchWidth" : 12,
    "issueWidth" : 12,
    "commitWidth" : 8,
    "wbWidth" : 12,

    "numROBEntries" : 720,
    
    "LQEntries" : 196,
    "SQEntries" : 64,

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