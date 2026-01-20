from m5.objects import SimpleBTB, ReturnAddrStack, TAGEBase, TAGE_SC_L_64KB

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

class TAGE_simple(TAGEBase):
    def __init__(self, btb, ras):
        super(TAGE_simple, self).__init__()
        self.btb = btb
        self.ras = ras

class TAGE_SC_L_64K(TAGE_SC_L_64KB):
    def __init__(self, btb, ras):
        super(TAGE_SC_L_64K, self).__init__()
        self.btb = btb
        self.ras = ras

