from m5.objects import IQUnit, FUPool, FUDesc, OpDesc

def _simd_misc_ops():
    """Common SIMD/misc operations added to many ports."""
    return [OpDesc(opClass="SimdAdd"),OpDesc(opClass="SimdAddAcc"),OpDesc(opClass="SimdAlu"),OpDesc(opClass="SimdCmp"),OpDesc(opClass="SimdCvt"),
            OpDesc(opClass="SimdMult"),OpDesc(opClass="SimdMultAcc"),OpDesc(opClass="SimdShift"),OpDesc(opClass="SimdShiftAcc"),
            OpDesc(opClass="SimdFloatAdd"),OpDesc(opClass="SimdFloatAlu"),OpDesc(opClass="SimdFloatCmp"),OpDesc(opClass="SimdFloatCvt"),
            OpDesc(opClass="SimdFloatMult"),OpDesc(opClass="SimdFloatMultAcc"),OpDesc(opClass="SimdDiv"),OpDesc(opClass="SimdFloatDiv"),
            OpDesc(opClass="SimdSqrt"),OpDesc(opClass="SimdFloatSqrt"),OpDesc(opClass="SimdMisc"),OpDesc(opClass="SimdFloatMisc"),
            OpDesc(opClass="SimdFloatMatMultAcc"),OpDesc(opClass="SimdReduceAdd"),OpDesc(opClass="SimdReduceAlu"),OpDesc(opClass="SimdReduceCmp"),
            OpDesc(opClass="SimdFloatReduceAdd"),OpDesc(opClass="SimdFloatReduceCmp"),OpDesc(opClass="SimdAes"),OpDesc(opClass="SimdAesMix"),
            OpDesc(opClass="SimdSha1Hash"),OpDesc(opClass="SimdSha1Hash2"),OpDesc(opClass="SimdSha256Hash"),OpDesc(opClass="SimdSha256Hash2"),
            OpDesc(opClass="SimdShaSigma2"),OpDesc(opClass="SimdShaSigma3"),OpDesc(opClass="SimdSha3"),OpDesc(opClass="SimdSm4e"),
            OpDesc(opClass="SimdCrc"),OpDesc(opClass="SimdPredAlu"),OpDesc(opClass="SimdDotProd"),OpDesc(opClass="Matrix"),
            OpDesc(opClass="MatrixMov"),OpDesc(opClass="MatrixOP"),OpDesc(opClass="InstPrefetch"),OpDesc(opClass="SimdUnitStrideLoad"),
            OpDesc(opClass="SimdUnitStrideStore"),OpDesc(opClass="SimdUnitStrideMaskLoad"),OpDesc(opClass="SimdUnitStrideMaskStore"),
            OpDesc(opClass="SimdStridedLoad"),OpDesc(opClass="SimdStridedStore"),OpDesc(opClass="SimdIndexedLoad"),
            OpDesc(opClass="SimdIndexedStore"),OpDesc(opClass="SimdWholeRegisterLoad"),OpDesc(opClass="SimdWholeRegisterStore"),
            OpDesc(opClass="SimdUnitStrideFaultOnlyFirstLoad"),OpDesc(opClass="SimdUnitStrideSegmentedLoad"),
            OpDesc(opClass="SimdUnitStrideSegmentedStore"),OpDesc(opClass="SimdUnitStrideSegmentedFaultOnlyFirstLoad"),
            OpDesc(opClass="SimdStrideSegmentedLoad"),OpDesc(opClass="SimdStrideSegmentedStore"),OpDesc(opClass="SimdExt"),
            OpDesc(opClass="SimdFloatExt"),OpDesc(opClass="SimdConfig"),OpDesc(opClass="SimdBf16Add"),OpDesc(opClass="SimdBf16Cmp"),
            OpDesc(opClass="SimdBf16Cvt"),OpDesc(opClass="SimdBf16DotProd"),OpDesc(opClass="SimdBf16MatMultAcc"),OpDesc(opClass="SimdBf16Mult"),
            OpDesc(opClass="SimdBf16MultAcc"),OpDesc(opClass="Bf16Cvt"),OpDesc(opClass="System")]

class _P1_SmallO3(FUDesc):
    opList = [
        OpDesc(opClass="IntAlu"),
        OpDesc(opClass="IntDiv", opLat=3, pipelined=False),
    ]
    count = 1

# Alu, Mult
class _P2_SmallO3(FUDesc):
    opList = [
        OpDesc(opClass="IntAlu"),
        OpDesc(opClass="IntMult"),
    ]
    count = 1

# ALU
class _P3_SmallO3(FUDesc):
    opList = [
        OpDesc(opClass="IntAlu"),
    ]
    count = 1

# FP
#Alu, Mult, MAC, Div, Sqrt
class _P4_SmallO3(FUDesc):
    opList = [
        OpDesc(opClass="FloatAdd", opLat=3),
        OpDesc(opClass="FloatCmp", opLat=3),
        OpDesc(opClass="FloatCvt", opLat=3),
        OpDesc(opClass="FloatMult", opLat=3),
        OpDesc(opClass="FloatMultAcc", opLat=5),
        OpDesc(opClass="FloatMisc", opLat=3),
        OpDesc(opClass="FloatDiv", opLat=5, pipelined=False),
        OpDesc(opClass="FloatSqrt", opLat=5, pipelined=False),
    ]
    count = 1

# Memory
# Load
class _P5_SmallO3(FUDesc):
    opList = [
        OpDesc(opClass="MemRead"),
        OpDesc(opClass="FloatMemRead"),
    ]
    count = 1

# Load, store
class _P6_SmallO3(FUDesc):
    opList = [
        OpDesc(opClass="MemWrite"),
        OpDesc(opClass="FloatMemWrite"),
        OpDesc(opClass="MemRead"),
        OpDesc(opClass="FloatMemRead"),
    ]
    count = 1

# Dedicated port for SIMD/misc in unified configuration
class _P_Misc_SmallO3(FUDesc):
    opList = _simd_misc_ops()
    count = 1

class _FUP_SmallO3(FUPool):
    FUList = [
        _P1_SmallO3(count=1),
        _P2_SmallO3(count=1),
        _P3_SmallO3(count=1),
        _P4_SmallO3(count=1),
        _P5_SmallO3(count=1),
        _P6_SmallO3(count=1),
        _P_Misc_SmallO3(count=1),
    ]

#----------------------------------------------------------------------------
# Small IQ for all Functional Unit Pools
class smallO3_IQ(IQUnit):
    def __init__(self, numEntries):
        super(smallO3_IQ, self).__init__()
        self.numEntries = numEntries
    fuPool = _FUP_SmallO3()

#----------------------------------------------------------------------------

#ALU, Div
class _P1_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="IntAlu"),
        OpDesc(opClass="IntDiv", opLat=3, pipelined=False),
    ]
    count = 1

# Alu, Mult
class _P2_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="IntAlu"),
        OpDesc(opClass="IntMult"),
    ]
    count = 1

# Alu, Mult
class _P3_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="IntAlu"),
        OpDesc(opClass="IntMult"),
    ]
    count = 1

# ALU
class _P4_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="IntAlu"),
    ]
    count = 1

# ALU, Branch
class _P5_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="IntAlu"),
    ]
    count = 1

# ALU, Branch
class _P6_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="IntAlu"),
    ]
    count = 1

# FP - Alu, Mult, MAC, Div, Sqrt
class _P7_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="FloatAdd", opLat=3),
        OpDesc(opClass="FloatCmp", opLat=3),
        OpDesc(opClass="FloatCvt", opLat=3),
        OpDesc(opClass="FloatMult", opLat=3),
        OpDesc(opClass="FloatMultAcc", opLat=5),
        OpDesc(opClass="FloatMisc", opLat=3),
        OpDesc(opClass="FloatDiv", opLat=5, pipelined=False),
        OpDesc(opClass="FloatSqrt", opLat=5, pipelined=False),
    ]
    count = 1

# Alu, Mult, MAC
class _P8_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="FloatAdd", opLat=3),
        OpDesc(opClass="FloatCmp", opLat=3),
        OpDesc(opClass="FloatCvt", opLat=3),
        OpDesc(opClass="FloatMult", opLat=3),
        OpDesc(opClass="FloatMultAcc", opLat=5),
    ]
    count = 1

# Alu, Mult, MAC
class _P9_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="FloatAdd", opLat=3),
        OpDesc(opClass="FloatCmp", opLat=3),
        OpDesc(opClass="FloatCvt", opLat=3),
        OpDesc(opClass="FloatMult", opLat=3),
        OpDesc(opClass="FloatMultAcc", opLat=5),
    ]
    count = 1

# Memory - Load
class _P10_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="MemRead"),
        OpDesc(opClass="FloatMemRead"),
    ]
    count = 1

# Store
class _P11_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="MemWrite"),
        OpDesc(opClass="FloatMemWrite"),
        OpDesc(opClass="MemRead"),
        OpDesc(opClass="FloatMemRead"),
    ]
    count = 1

# Store
class _P12_BigO3(FUDesc):
    opList = [
        OpDesc(opClass="MemWrite"),
        OpDesc(opClass="FloatMemWrite"),
        OpDesc(opClass="MemRead"),
        OpDesc(opClass="FloatMemRead"),
    ]
    count = 1

# Dedicated port for SIMD/misc in unified configuration
class _P_Misc_BigO3(FUDesc):
    opList = _simd_misc_ops()
    count = 1

class _FUP_BigO3(FUPool):
    FUList = [
        _P1_BigO3(count=1),
        _P2_BigO3(count=1),
        _P3_BigO3(count=1),
        _P4_BigO3(count=1),
        _P5_BigO3(count=1),
        _P6_BigO3(count=1),
        _P7_BigO3(count=1),
        _P8_BigO3(count=1),
        _P9_BigO3(count=1),
        _P10_BigO3(count=1),
        _P11_BigO3(count=1),
        _P12_BigO3(count=1),
        _P_Misc_BigO3(count=1),
    ]

#----------------------------------------------------------------------------
# Big IQ for all Functional Unit Pools
class bigO3_IQ(IQUnit):
    def __init__(self, numEntries):
        super(bigO3_IQ, self).__init__()
        self.numEntries = numEntries
    fuPool = _FUP_BigO3()
#----------------------------------------------------------------------------