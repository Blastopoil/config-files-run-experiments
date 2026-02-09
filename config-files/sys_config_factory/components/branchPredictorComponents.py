from m5.objects import (
    NULL, 
    SimpleBTB, ReturnAddrStack, BranchPredictor, 
    TAGEBase, TAGE_SC_L_64KB
    )

class customBranchPredictor(BranchPredictor):
    def __init__(self, btb=None, ras=None, conditional_predictor=None):
        super(customBranchPredictor, self).__init__()
        if btb: self.btb = btb
        if ras: self.ras = ras
        if conditional_predictor: self.conditionalBranchPred = conditional_predictor

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
        self.instShiftAmt = 2
        self.speculativeHistUpdate = True
        self.statistical_corrector.speculativeHistUpdate = True

class TAGE_L_64K(TAGE_SC_L_64KB):
    def __init__(self):
        super(TAGE_L_64K, self).__init__()
        self.instShiftAmt = 2
        self.speculativeHistUpdate = True

        self.statistical_corrector.disable = True

class TAGE_SC_64K(TAGE_SC_L_64KB):
    def __init__(self):
        super(TAGE_SC_64K, self).__init__()
        self.instShiftAmt = 2
        self.speculativeHistUpdate = True

        self.loop_predictor.disable = True

