from m5.objects import (
    NULL, 
    SimpleBTB, ReturnAddrStack, BranchPredictor,
    TAGE_SC_L_TAGE_64KB, TAGE_SC_L_TAGE_8KB, 
    TAGE_SC_L_64KB, TAGE_SC_L_8KB
    )

class customBranchPredictor(BranchPredictor):
    def __init__(self, btb=None, ras=None, conditional_predictor=None, instShiftAmt=None):
        super(customBranchPredictor, self).__init__()
        if btb: self.btb = btb
        if ras: self.ras = ras
        if conditional_predictor: self.conditionalBranchPred = conditional_predictor
        if instShiftAmt: self.instShiftAmt = instShiftAmt

class BTB(SimpleBTB):
    def __init__(self, btb_config):
        super(BTB, self).__init__()
        for k, v in btb_config.items():
            setattr(self, k, v)

class RAS(ReturnAddrStack):
    def __init__(self, ras_config):
        super(RAS, self).__init__()
        for k, v in ras_config.items():
            setattr(self, k, v)

class TAGE_SC_L_64K(TAGE_SC_L_64KB):
    def __init__(self):
        super(TAGE_SC_L_64K, self).__init__()
        self.instShiftAmt = 0 # After experimenting with gshare, having this to 1 actually hurts performance even though using RISCV # After experimenting with gshare, having this to 1 actually hurts performance even though using RISCV
        self.speculativeHistUpdate = True
        self.statistical_corrector.speculativeHistUpdate = True

class TAGE_L_64K(TAGE_SC_L_64KB):
    def __init__(self):
        super(TAGE_L_64K, self).__init__()
        self.instShiftAmt = 0 # After experimenting with gshare, having this to 1 actually hurts performance even though using RISCV
        self.speculativeHistUpdate = True

        self.statistical_corrector.disable = True

class TAGE_SC_64K(TAGE_SC_L_64KB):
    def __init__(self):
        super(TAGE_SC_64K, self).__init__()
        self.instShiftAmt = 0 # After experimenting with gshare, having this to 1 actually hurts performance even though using RISCV
        self.speculativeHistUpdate = True

        self.loop_predictor.disable = True

class TAGE_SC_L_8K(TAGE_SC_L_8KB):
    def __init__(self):
        super(TAGE_SC_L_8K, self).__init__()
        self.instShiftAmt = 0 # After experimenting with gshare, having this to 1 actually hurts performance even though using RISCV
        self.speculativeHistUpdate = True
        self.statistical_corrector.speculativeHistUpdate = True

class TAGE_L_8K(TAGE_SC_L_8KB):
    def __init__(self):
        super(TAGE_L_8K, self).__init__()
        self.instShiftAmt = 0 # After experimenting with gshare, having this to 1 actually hurts performance even though using RISCV
        self.speculativeHistUpdate = True

        self.statistical_corrector.disable = True

class TAGE_SC_8K(TAGE_SC_L_8KB):
    def __init__(self):
        super(TAGE_SC_8K, self).__init__()
        self.instShiftAmt = 0 # After experimenting with gshare, having this to 1 actually hurts performance even though using RISCV
        self.speculativeHistUpdate = True

        self.loop_predictor.disable = True

class TAGE_SC_L_64K_no_speculation(TAGE_SC_L_64KB):
    def __init__(self):
        super(TAGE_SC_L_64K_no_speculation, self).__init__()
        self.instShiftAmt = 0 # After experimenting with gshare, having this to 1 actually hurts performance even though using RISCV
        self.speculativeHistUpdate = False
        self.statistical_corrector.speculativeHistUpdate = False


class TAGE_SC_L_TAGE_16KB(TAGE_SC_L_TAGE_8KB):
    def __init__(self):
        super(TAGE_SC_L_TAGE_16KB, self).__init__()
        # 2 more tables that the 8KB TAGE
        self.nHistoryTables = 32
        self.noSkip = [
            0,
            0,
            1,
            0,
            1,
            0,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            0,
            1,
            0,
            1,
            0,
            1,
            0,
            1,
            0,
            1,
            0,
            1,
        ]

        self.minHist = 5
        self.maxHist = 1500

        self.logTagTableSize = 8


class TAGE_SC_L_TAGE_32KB(TAGE_SC_L_TAGE_64KB):
    def __init__(self):
        super(TAGE_SC_L_TAGE_32KB, self).__init__()
        # 2 less tables that the 64KB TAGE
        self.nHistoryTables = 34
        self.noSkip = [
            0,
            0,
            1,
            0,
            0,
            0,
            1,
            0,
            0,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            0,
            1,
            0,
            1,
            0,
            1,
            0,
            0,
            0,
            1,
            0,
            1, # The last table had this associativity, because of that I also change this one since it is also odd
        ]

        self.minHist = 6
        self.maxHist = 3000

        self.logTagTableSize = 12

class TAGE_SC_L_16KB(TAGE_SC_L_8KB):
    def __init__(self):
        super(TAGE_SC_L_16KB, self).__init__()
        self.instShiftAmt = 0 # After experimenting with gshare, having this to 1 actually hurts performance even though using RISCV
        self.speculativeHistUpdate = True
        self.statistical_corrector.speculativeHistUpdate = True
        self.tage = TAGE_SC_L_TAGE_16KB()


class TAGE_SC_L_32KB(TAGE_SC_L_64KB):
    def __init__(self):
        super(TAGE_SC_L_32KB, self).__init__()
        self.instShiftAmt = 0 # After experimenting with gshare, having this to 1 actually hurts performance even though using RISCV # After experimenting with gshare, having this to 1 actually hurts performance even though using RISCV
        self.speculativeHistUpdate = True
        self.statistical_corrector.speculativeHistUpdate = True
        self.tage = TAGE_SC_L_TAGE_32KB()