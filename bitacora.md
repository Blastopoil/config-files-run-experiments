
24/01/2026 - 17:25

He estado preparando scripts para poder tomar los checkpoints de las SPECs. He encontrado un cambio en la versión de gem5 que me ha hecho cambiar el gem5-config-fs.py. Ahora estoy intentando tomar un checkpoint del ubuntu booteado para desde ese checkpoint tomar el del resto de las SPECs.

24/01/2026 - 18:20

He hecho una copia de gem5-config-fs.py y la he llamado gem5-config-first-ckpt.py para tomar este primer checkpoint del que hablaba antes. Lo que hace es prestar atencion a que la imagen de disco que me dió Pablo Prieto suelte la operacion m5 de checkpoint para guardarlo en /nfs/home/ce/felixfdec/ckpts_SPEC_intento_mio/RISCV/felix_SPEC_base.

25/01/2026 - 13:01

Estoy revisando el resultado de la simulación en aras de obtener el primer ckpt y a primera vista hay dos ckpts generados en el m5out y no en /nfs/home/ce/felixfdec/ckpts_SPEC_intento_mio/RISCV/felix_SPEC_base. Me dispongo a averiguar si alguno es válido. 

En m5out/ tengo las carpetas cpt.10183495775964/ y cpt.14298416945274, y en la slaida de la terminal de la simulación se encuentra la siguiente región:

src/arch/riscv/isa.cc:1052: warn: 9116525061462: context 0: 460000 consecutive SC failures.
src/arch/riscv/isa.cc:1052: warn: 9345732443964: context 0: 470000 consecutive SC failures.
src/arch/riscv/isa.cc:1052: warn: 9923353204632: context 0: 480000 consecutive SC failures.
src/arch/riscv/isa.cc:1052: warn: 10177138891878: context 0: 490000 consecutive SC failures.
warn: No behavior was set by the user for checkpoint. Default behavior is creating a checkpoint and continuing.
Writing checkpoint
src/arch/riscv/isa.cc:1052: warn: 10381378363398: context 0: 500000 consecutive SC failures.
src/arch/riscv/isa.cc:1052: warn: 10643205127926: context 0: 510000 consecutive SC failures.
src/arch/riscv/isa.cc:1052: warn: 10963610427378: context 0: 520000 consecutive SC failures.
src/arch/riscv/isa.cc:1052: warn: 11216406329982: context 0: 530000 consecutive SC failures.
src/arch/riscv/isa.cc:1052: warn: 11385113650764: context 0: 540000 consecutive SC failures.
src/arch/riscv/isa.cc:1052: warn: 11526165680946: context 0: 550000 consecutive SC failures.
src/arch/riscv/isa.cc:1052: warn: 13124793142650: context 0: 560000 consecutive SC failures.
src/arch/riscv/isa.cc:1052: warn: 14069982725526: context 0: 570000 consecutive SC failures.
Writing checkpoint
src/arch/riscv/isa.cc:1052: warn: 15461588960286: context 0: 580000 consecutive SC failures.
src/arch/riscv/isa.cc:1052: warn: 16781502128748: context 0: 590000 consecutive SC failures.

Voy a probar a hacer un script (gem5-config-restore-first-ckpt.py) con el que retomar los ckpts y con ello ver si el sistema se encuentra booteado.

25/01/2026 - 15:01

A la hora de restaurar el checkpoint (cualquiera de los dos), vuelven a aparecer los pmp access fault. Voy a probar a usar un kernel compatible con gem5 25.1.

26/01/2026 - 12:30

No ha servido de nada. Restaurar el checkpoint con la versión 25.1 da el pmp access fault.

26/01/2026 - 14:03

Me parece que he encontrado una causa. Con la v25.1, los ejemplos de toma de checkpoints en el repo ofical pasan de usar simulator.save_checkpoint() en el ExitEvent.WORKBEGIN, a hacer lo siguiente:
https://github.com/gem5/gem5/blob/stable/configs/example/gem5_library/checkpoints/riscv-hello-save-checkpoint.py#L107

27/01/2026 - 18:03

Nada ha funcionado, dejamos full system para versión 25.1 aparacado. Paso a hacer que los SPEC se puedan lanzar en System Call Emulation.

29/01/2026 - 18:47

Estoy a punto de acabar de conseguir que los 22 benchmarks de SPEC17 funcionen con syscall emulation. De momento tengo casi todos los checkpoints tomados. Ahora tengo que ver si restaurar cada checkpoint tomado funciona correctamente.

06/02/2026 - 10:35

Funcionan la mayoría de SPECs con ckpts y en SE. Ahora toca sacar datos. He probado con TAGE-SC-L, TAGE-SC y TAGE-L. Hay mucha distorsión y además sale que el Loop Predictor afecta más que el Statistical Corrector en lo que ha la correctitud de prediccciones se refiere. Esto se contradice con lo que afirma André Seznec.

Voy por un lado a tomar datos del predictor de dos estados y el g-share, modififcar más parámetros del TAGE por otro, y revisar la forma en la que deshabilito el SC por otro. Además usar los parámertros del BigO3 de Esther.