.global _start
.text

.option norvc # To stop the nops from being 16 bits sized

# This program tests if using only one GHR correctly produces a 1010... alternating pattern

_start:
	li t0, 0
	li t1, 1

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

.align 4

	beqz t0, salto1
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto1:
	beqz t0, salto2
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto2:
	beqz t0, salto3
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto3:
	beqz t0, salto4
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto4:
	beqz t0, salto5
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto5:
	beqz t0, salto6
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto6:
	beqz t0, salto7
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto7:
	beqz t0, salto8
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto8:
	beqz t0, salto9
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto9:
	beqz t0, salto10
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto10:
	beqz t0, salto11
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto11:
	beqz t0, salto12 # From this branch onwards predictions are correct
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto12:
	beqz t0, salto13
	nop
	nop
	nop
	nop
	nop
	nop
	nop
salto13:

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	li a7, 93          # RISC-V Linux exit code
    li a0, 0           # Return code set to 0
    ecall
